//! The libghostty application object + its runtime callbacks.
//!
//! `ghostty_app_t` owns the read/write/render threads. libghostty calls back
//! into us for things it can't do itself (wake the main loop, clipboard, close
//! a surface). The one that matters for a live terminal is `wakeup`: ghostty's
//! threads call it to ask the main thread to run `ghostty_app_tick`, so we
//! bounce that onto the main GCD queue.

const std = @import("std");
const gh = @import("ghostty.zig").c;
const Theme = @import("theme.zig").Theme;
const config = @import("config.zig");

// Grand Central Dispatch: hop a tick onto the main thread from wakeup_cb.
extern "c" var _dispatch_main_q: anyopaque;
extern "c" fn dispatch_async_f(queue: *anyopaque, context: ?*anyopaque, work: *const fn (?*anyopaque) callconv(.c) void) void;

pub const App = struct {
    inner: gh.ghostty_app_t,
    cfg: gh.ghostty_config_t,

    /// Initialize libghostty once, build the config from `theme`, and create
    /// the app. Call `deinit` on shutdown.
    pub fn init(allocator: std.mem.Allocator, theme: Theme) !App {
        if (gh.ghostty_init(0, null) != 0) return error.GhosttyInit;

        // Theme → ghostty config file → loaded config.
        const text = try config.generate(allocator, theme);
        defer allocator.free(text);
        const path = try writeTempConfig(allocator, text);
        defer allocator.free(path);

        const cfg = gh.ghostty_config_new();
        gh.ghostty_config_load_file(cfg, path.ptr);
        gh.ghostty_config_finalize(cfg);

        var rt = std.mem.zeroes(gh.ghostty_runtime_config_s);
        rt.userdata = null;
        rt.supports_selection_clipboard = false;
        rt.wakeup_cb = wakeup;
        rt.action_cb = action;
        rt.read_clipboard_cb = readClipboard;
        rt.confirm_read_clipboard_cb = confirmReadClipboard;
        rt.write_clipboard_cb = writeClipboard;
        rt.close_surface_cb = closeSurface;

        const inner = gh.ghostty_app_new(&rt, cfg) orelse return error.GhosttyApp;
        return .{ .inner = inner, .cfg = cfg };
    }

    pub fn deinit(self: *App) void {
        gh.ghostty_app_free(self.inner);
        gh.ghostty_config_free(self.cfg);
    }

    pub fn tick(self: *App) void {
        gh.ghostty_app_tick(self.inner);
    }
};

/// Pinned to the App instance so the C callback can reach `tick`. Single-window
/// app (Slice 1), so a module global is adequate.
var current: ?*App = null;
pub fn setCurrent(app: *App) void {
    current = app;
}

fn tickOnMain(_: ?*anyopaque) callconv(.c) void {
    if (current) |a| a.tick();
}

fn wakeup(_: ?*anyopaque) callconv(.c) void {
    // Called from ghostty's threads — bounce a tick to the main thread.
    dispatch_async_f(&_dispatch_main_q, null, tickOnMain);
}

fn action(_: gh.ghostty_app_t, _: gh.ghostty_target_s, _: gh.ghostty_action_s) callconv(.c) bool {
    // Slice 1: no window actions handled (new tab/split/etc. come later).
    return false;
}

fn readClipboard(_: ?*anyopaque, _: gh.ghostty_clipboard_e, _: ?*anyopaque) callconv(.c) bool {
    return false;
}
fn confirmReadClipboard(_: ?*anyopaque, _: [*c]const u8, _: ?*anyopaque, _: gh.ghostty_clipboard_request_e) callconv(.c) void {}
fn writeClipboard(_: ?*anyopaque, _: gh.ghostty_clipboard_e, _: [*c]const gh.ghostty_clipboard_content_s, _: usize, _: bool) callconv(.c) void {}
fn closeSurface(_: ?*anyopaque, _: bool) callconv(.c) void {}

fn writeTempConfig(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    const dir = if (std.c.getenv("TMPDIR")) |d| std.mem.span(d) else "/tmp";
    const path = try std.fmt.allocPrintSentinel(allocator, "{s}/purrtty-config", .{dir}, 0);
    errdefer allocator.free(path);
    const file = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(text);
    return path;
}
