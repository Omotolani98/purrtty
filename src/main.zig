//! purrtty — a pixel-native terminal (Slice 1: themed terminal on libghostty).
//!
//! Boots libghostty with the phosphor-green theme and opens a single macOS
//! window running the user's shell. Mascot, CRT scanlines, and the settings
//! GUI are later slices (see the plan / README).

const std = @import("std");
const appmod = @import("app.zig");
const App = appmod.App;
const Theme = @import("theme.zig").Theme;
const window = @import("window.zig");

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const theme = Theme.phosphor;

    var app = try App.init(allocator, theme);
    defer app.deinit();
    appmod.setCurrent(&app);

    // Working directory for the spawned shell + window title (purrtty — <cwd>).
    var cwd_buf: [std.fs.max_path_bytes]u8 = undefined;
    const cwd = std.process.getCwd(&cwd_buf) catch "/";
    const cwd_z = try allocator.dupeZ(u8, cwd);
    defer allocator.free(cwd_z);
    const title = try std.fmt.allocPrintSentinel(allocator, "purrtty — {s}", .{cwd}, 0);
    defer allocator.free(title);

    try window.run(&app, theme, title, cwd_z);
}
