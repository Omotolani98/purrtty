//! macOS window + content view for a single purrtty surface.
//!
//! We define a tiny NSView subclass at runtime that (a) makes a CAMetalLayer as
//! its backing layer so libghostty can render into it, (b) accepts first
//! responder, and (c) forwards key events to the surface. An app delegate
//! quits when the window closes. This is the AppKit half of the embed; the
//! terminal half lives in libghostty.

const std = @import("std");
const objc = @import("objc.zig");
const gh = @import("ghostty.zig").c;
const App = @import("app.zig").App;
const Surface = @import("surface.zig").Surface;
const Theme = @import("theme.zig").Theme;

const CGPoint = extern struct { x: f64, y: f64 };
const CGSize = extern struct { width: f64, height: f64 };
const CGRect = extern struct { origin: CGPoint, size: CGSize };

const NSWindowStyleMaskTitled: u64 = 1 << 0;
const NSWindowStyleMaskClosable: u64 = 1 << 1;
const NSWindowStyleMaskMiniaturizable: u64 = 1 << 2;
const NSWindowStyleMaskResizable: u64 = 1 << 3;
const NSBackingStoreBuffered: u64 = 2;
const NSApplicationActivationPolicyRegular: i64 = 0;

// Stashed so the view's keyDown IMP can reach the surface (single window).
var g_surface: ?*Surface = null;

fn nsString(s: [*:0]const u8) objc.id {
    return objc.msgSend(objc.id, objc.class("NSString"), objc.sel("stringWithUTF8String:"), .{s});
}

/// Boot AppKit, open the window, create the surface, and run the event loop.
/// Blocks until the app terminates.
pub fn run(app: *App, theme: Theme, title: [*:0]const u8, cwd: [*:0]const u8) !void {
    const NSApp = objc.msgSend(objc.id, objc.class("NSApplication"), objc.sel("sharedApplication"), .{});
    _ = objc.msgSend(bool, NSApp, objc.sel("setActivationPolicy:"), .{NSApplicationActivationPolicyRegular});

    // App delegate: quit after the last window closes.
    const Delegate = makeDelegateClass();
    const delegate = objc.init(objc.alloc(Delegate));
    _ = objc.msgSend(void, NSApp, objc.sel("setDelegate:"), .{delegate});

    // Window.
    const rect = CGRect{ .origin = .{ .x = 0, .y = 0 }, .size = .{ .width = 940, .height = 600 } };
    const style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
        NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
    const window = objc.msgSend(
        objc.id,
        objc.alloc(objc.class("NSWindow")),
        objc.sel("initWithContentRect:styleMask:backing:defer:"),
        .{ rect, style, NSBackingStoreBuffered, false },
    );
    _ = objc.msgSend(void, window, objc.sel("setTitle:"), .{nsString(title)});

    // Content view (our subclass), layer-backed for Metal.
    const ViewClass = makeViewClass();
    const view = objc.init(objc.alloc(ViewClass));
    _ = objc.msgSend(void, view, objc.sel("setWantsLayer:"), .{true});
    _ = objc.msgSend(void, window, objc.sel("setContentView:"), .{view});
    _ = objc.msgSend(void, window, objc.sel("makeFirstResponder:"), .{view});

    // Surface bound to the view.
    const scale = objc.msgSend(f64, window, objc.sel("backingScaleFactor"), .{});
    var surface = try Surface.init(app, @ptrCast(view.?), scale, theme.font_size, cwd);
    g_surface = &surface;
    surface.setContentScale(scale, scale);
    surface.setSize(
        @intFromFloat(rect.size.width * scale),
        @intFromFloat(rect.size.height * scale),
    );
    surface.setFocus(true);

    // Show + run.
    _ = objc.msgSend(void, window, objc.sel("center"), .{});
    _ = objc.msgSend(void, window, objc.sel("makeKeyAndOrderFront:"), .{@as(objc.id, null)});
    _ = objc.msgSend(void, NSApp, objc.sel("activateIgnoringOtherApps:"), .{true});
    _ = objc.msgSend(void, NSApp, objc.sel("run"), .{});

    surface.deinit();
}

// ── NSView subclass ─────────────────────────────────────────────────────────

fn makeViewClass() objc.Class {
    const cls = objc.objc_allocateClassPair(objc.class("NSView"), "PurrttyView", 0);
    _ = objc.class_addMethod(cls, objc.sel("makeBackingLayer"), @ptrCast(&viewMakeBackingLayer), "@@:");
    _ = objc.class_addMethod(cls, objc.sel("acceptsFirstResponder"), @ptrCast(&viewAcceptsFirstResponder), "c@:");
    _ = objc.class_addMethod(cls, objc.sel("wantsUpdateLayer"), @ptrCast(&viewWantsUpdateLayer), "c@:");
    _ = objc.class_addMethod(cls, objc.sel("keyDown:"), @ptrCast(&viewKeyDown), "v@:@");
    objc.objc_registerClassPair(cls);
    return cls;
}

fn viewMakeBackingLayer(_: objc.id, _: objc.SEL) callconv(.c) objc.id {
    // libghostty renders with Metal → its layer must be a CAMetalLayer.
    return objc.msgSend(objc.id, objc.class("CAMetalLayer"), objc.sel("layer"), .{});
}
fn viewAcceptsFirstResponder(_: objc.id, _: objc.SEL) callconv(.c) bool {
    return true;
}
fn viewWantsUpdateLayer(_: objc.id, _: objc.SEL) callconv(.c) bool {
    return true;
}

fn viewKeyDown(_: objc.id, _: objc.SEL, event: objc.id) callconv(.c) void {
    const surface = g_surface orelse return;

    const flags = objc.msgSend(u64, event, objc.sel("modifierFlags"), .{});
    const keycode = objc.msgSend(u16, event, objc.sel("keyCode"), .{});
    const chars = objc.msgSend(objc.id, event, objc.sel("characters"), .{});
    const text: [*c]const u8 = if (chars != null)
        objc.msgSend([*c]const u8, chars, objc.sel("UTF8String"), .{})
    else
        null;

    var ev = std.mem.zeroes(gh.ghostty_input_key_s);
    ev.action = gh.GHOSTTY_ACTION_PRESS;
    ev.mods = translateMods(flags);
    ev.keycode = keycode;
    ev.text = text;
    _ = surface.key(ev);
}

/// NSEventModifierFlags → ghostty mods. Device-independent flag bits are in the
/// high half of the mask (shift 1<<17, control 1<<18, option 1<<19, cmd 1<<20).
fn translateMods(flags: u64) gh.ghostty_input_mods_e {
    var mods: c_int = gh.GHOSTTY_MODS_NONE;
    if (flags & (1 << 17) != 0) mods |= gh.GHOSTTY_MODS_SHIFT;
    if (flags & (1 << 18) != 0) mods |= gh.GHOSTTY_MODS_CTRL;
    if (flags & (1 << 19) != 0) mods |= gh.GHOSTTY_MODS_ALT;
    if (flags & (1 << 20) != 0) mods |= gh.GHOSTTY_MODS_SUPER;
    return @intCast(mods);
}

// ── App delegate ────────────────────────────────────────────────────────────

fn makeDelegateClass() objc.Class {
    const cls = objc.objc_allocateClassPair(objc.class("NSObject"), "PurrttyDelegate", 0);
    _ = objc.class_addMethod(
        cls,
        objc.sel("applicationShouldTerminateAfterLastWindowClosed:"),
        @ptrCast(&shouldTerminate),
        "c@:@",
    );
    objc.objc_registerClassPair(cls);
    return cls;
}
fn shouldTerminate(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) bool {
    return true;
}
