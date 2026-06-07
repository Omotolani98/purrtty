//! purrtty — a pixel-native terminal on libghostty.
//!
//! Loads purrtty.toml → theme + mascot config, boots libghostty, and opens a
//! macOS window: phosphor-themed terminal, walking pixel cat, CRT scanlines.

const std = @import("std");
const appmod = @import("app.zig");
const App = appmod.App;
const window = @import("window.zig");
const mascot = @import("mascot.zig");
const settings = @import("settings.zig");

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Config from purrtty.toml in the cwd (defaults to phosphor if absent).
    const set = settings.loadOrDefault("purrtty.toml");
    const theme = set.theme;
    const mcfg: mascot.Config = .{
        .cat = set.mascot.cat,
        .scanline = theme.scanline,
        .speed = set.mascot.speed,
        .enabled = set.mascot.enabled,
    };

    var app = try App.init(allocator, theme);
    defer app.deinit();
    appmod.setCurrent(&app);

    // Working directory for the spawned shell + window title (purrtty — <cwd>).
    // libc getcwd → stable across Zig 0.15/0.16.
    var cwd_buf: [4096]u8 = undefined;
    const cwd: [:0]const u8 = if (std.c.getcwd(&cwd_buf, cwd_buf.len) != null)
        std.mem.sliceTo(@as([*:0]u8, @ptrCast(&cwd_buf)), 0)
    else
        "/";
    const title = try std.fmt.allocPrintSentinel(allocator, "purrtty — {s}", .{cwd}, 0);
    defer allocator.free(title);

    try window.run(&app, theme, mcfg, title, cwd.ptr);
}
