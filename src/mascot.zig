//! Walking pixel-cat mascot — an app overlay composited over the terminal.
//!
//! A transparent, click-through NSView sits on top of the libghostty surface and
//! draws the chonky sit-loaf sprite (ported from the design's purrtty-sprites.js
//! GRID_SIT) with Core Graphics. A timer paces it left↔right along the bottom
//! with a gentle waddle/bob, flipping to face its travel direction.
//!
//! Slice scope: gray "mochi" cat, walk + bob + flip. Variants / speed / toggle
//! come with the settings slice (palettes already live in tokens.zig).

const std = @import("std");
const objc = @import("objc.zig");
const tokens = @import("tokens.zig");

// ── sprite (GRID_SIT, 14 rows) — '.' transparent, letters → palette ──────────
const GRID = [_][]const u8{
    "...kk........kk...",
    "..kggk......kggk..",
    "..kgsgkkkkkkgsgk..",
    ".kggggggggggggggk.",
    ".kgggggggggggggggk",
    "kggeggggggggggeggk",
    "kgggggggkkgggggggk",
    "kggggggkppkggggggk",
    "kgblgggggggggglbgk",
    "kgllllllllllllllgk",
    "kgllllllllllllllgk",
    "kggkkgggggggkkggk.",
    ".kkk.kkkkkkkk.kkk.",
    ".................",
};
const ROWS: f64 = GRID.len;
const COLS: f64 = 18;

const PIXEL: f64 = 4; // sprite pixel size in points
const SPEED: f64 = 26; // base points/sec (× speed multiplier)
const BOTTOM_PAD: f64 = 6; // gap above the window's bottom edge
const FPS: f64 = 60;

/// Runtime config (from purrtty.toml). Set in `mount`.
pub const Config = struct {
    cat: tokens.CatPalette = tokens.cats[0],
    scanline: f64 = tokens.scanline_default,
    speed: f64 = 1.0,
    enabled: bool = true, // show the walking cat (scanlines draw regardless)
};
var cfg: Config = .{};

fn colorFor(ch: u8) ?tokens.Color {
    const cat = cfg.cat;
    return switch (ch) {
        'k' => cat.k,
        'g' => cat.g,
        'l' => cat.l,
        's' => cat.s,
        'e' => cat.e,
        'p' => cat.p,
        'b' => cat.b,
        else => null,
    };
}

// ── Core Graphics (CoreGraphics framework, already linked) ───────────────────
const CGFloat = f64;
const CGPoint = extern struct { x: CGFloat = 0, y: CGFloat = 0 };
const CGSize = extern struct { width: CGFloat = 0, height: CGFloat = 0 };
const CGRect = extern struct { origin: CGPoint = .{}, size: CGSize = .{} };

extern "c" fn CGContextSetRGBFillColor(c: ?*anyopaque, r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) void;
extern "c" fn CGContextFillRect(c: ?*anyopaque, rect: CGRect) void;

// ── animation state (single mascot) ──────────────────────────────────────────
const State = struct {
    x: f64 = 12,
    dir: f64 = 1, // +1 right, -1 left
    phase: u32 = 0, // waddle phase counter
    host_w: f64 = 940,
    host_h: f64 = 600,
};
var state: State = .{};

const spriteW = COLS * PIXEL;
const spriteH = ROWS * PIXEL;

/// Create the overlay, add it over `host`, and start the walk timer.
pub fn mount(host: objc.id, config: Config) void {
    cfg = config;
    const cls = makeViewClass();
    const view = objc.init(objc.alloc(cls));
    _ = objc.msgSend(void, view, objc.sel("setWantsLayer:"), .{true});

    // Fill the host and track its resizing (NSViewWidthSizable|HeightSizable).
    const bounds = objc.msgSend(CGRect, host, objc.sel("bounds"), .{});
    state.host_w = bounds.size.width;
    state.host_h = bounds.size.height;
    _ = objc.msgSend(void, view, objc.sel("setFrame:"), .{bounds});
    _ = objc.msgSend(void, view, objc.sel("setAutoresizingMask:"), .{@as(u64, 2 | 16)});
    _ = objc.msgSend(void, host, objc.sel("addSubview:"), .{view});

    // Drive the walk cycle.
    const NSTimer = objc.class("NSTimer");
    _ = objc.msgSend(
        objc.id,
        NSTimer,
        objc.sel("scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:"),
        .{ @as(f64, 1.0 / FPS), view, objc.sel("tick:"), @as(objc.id, null), true },
    );
}

fn makeViewClass() objc.Class {
    const cls = objc.objc_allocateClassPair(objc.class("NSView"), "PurrttyMascot", 0);
    _ = objc.class_addMethod(cls, objc.sel("drawRect:"), @ptrCast(&drawRect), "v@:{CGRect={CGPoint=dd}{CGSize=dd}}");
    _ = objc.class_addMethod(cls, objc.sel("tick:"), @ptrCast(&tick), "v@:@");
    _ = objc.class_addMethod(cls, objc.sel("hitTest:"), @ptrCast(&hitTest), "@@:{CGPoint=dd}");
    _ = objc.class_addMethod(cls, objc.sel("isFlipped"), @ptrCast(&isFlipped), "c@:");
    objc.objc_registerClassPair(cls);
    return cls;
}

// Non-flipped coords: origin bottom-left, so the cat sits near y=0 and sprite
// row 0 (its head/top) maps to the highest y.
fn isFlipped(_: objc.id, _: objc.SEL) callconv(.c) bool {
    return false;
}

// Click-through: never claim a hit, so all input falls to the terminal below.
fn hitTest(_: objc.id, _: objc.SEL, _: CGPoint) callconv(.c) objc.id {
    return null;
}

fn tick(view: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    const dt = 1.0 / FPS;
    state.phase +%= 1;
    // Track the live width so the cat bounces off the real edges after resize.
    const vb = objc.msgSend(CGRect, view, objc.sel("bounds"), .{});
    state.host_w = vb.size.width;
    if (!cfg.enabled) {
        _ = objc.msgSend(void, view, objc.sel("setNeedsDisplay:"), .{true});
        return;
    }
    state.x += state.dir * SPEED * cfg.speed * dt;

    const pad: f64 = 8;
    if (state.x < pad) {
        state.x = pad;
        state.dir = 1;
    } else if (state.x > state.host_w - spriteW - pad) {
        state.x = state.host_w - spriteW - pad;
        state.dir = -1;
    }
    _ = objc.msgSend(void, view, objc.sel("setNeedsDisplay:"), .{true});
}

fn drawRect(view: objc.id, _: objc.SEL, _: CGRect) callconv(.c) void {
    const nsctx = objc.msgSend(objc.id, objc.class("NSGraphicsContext"), objc.sel("currentContext"), .{});
    if (nsctx == null) return;
    const ctx = objc.msgSend(?*anyopaque, nsctx, objc.sel("CGContext"), .{});
    if (ctx == null) return;

    // keep host height current (cheap; covers resize between mounts)
    const b = objc.msgSend(CGRect, view, objc.sel("bounds"), .{});
    state.host_h = b.size.height;

    // CRT scanline overlay — faint 1px phosphor lines every 3px over the whole
    // surface (design's --scanline; mirrors the CSS repeating-linear-gradient).
    if (cfg.scanline > 0) {
        CGContextSetRGBFillColor(ctx, 1, 1, 1, cfg.scanline);
        var y: f64 = 0;
        while (y < b.size.height) : (y += 3) {
            CGContextFillRect(ctx, .{ .origin = .{ .x = 0, .y = y }, .size = .{ .width = b.size.width, .height = 1 } });
        }
    }

    if (!cfg.enabled) return; // scanlines only; no cat

    // 4-phase waddle: tiny vertical bob.
    const lift: f64 = switch (state.phase / 9 % 4) {
        1, 3 => 3,
        else => 0,
    };
    const ox = state.x;
    const oy = BOTTOM_PAD + lift;
    const flip = state.dir < 0;

    // soft contact shadow
    CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.28);
    CGContextFillRect(ctx, .{
        .origin = .{ .x = ox + spriteW * 0.12, .y = BOTTOM_PAD - 3 },
        .size = .{ .width = spriteW * 0.76, .height = 4 },
    });

    var r: usize = 0;
    while (r < GRID.len) : (r += 1) {
        const line = GRID[r];
        var c: usize = 0;
        while (c < line.len) : (c += 1) {
            const color = colorFor(line[c]) orelse continue;
            const col: f64 = if (flip) (COLS - 1 - @as(f64, @floatFromInt(c))) else @floatFromInt(c);
            const yrow: f64 = @floatFromInt(GRID.len - 1 - r); // row 0 → top
            CGContextSetRGBFillColor(
                ctx,
                @as(f64, @floatFromInt(color.r)) / 255.0,
                @as(f64, @floatFromInt(color.g)) / 255.0,
                @as(f64, @floatFromInt(color.b)) / 255.0,
                1.0,
            );
            CGContextFillRect(ctx, .{
                .origin = .{ .x = ox + col * PIXEL, .y = oy + yrow * PIXEL },
                .size = .{ .width = PIXEL, .height = PIXEL },
            });
        }
    }
}
