//! Renders a Theme into a ghostty config document.
//!
//! libghostty has no "set key from string" call — config is applied with
//! `ghostty_config_load_file`. So purrtty generates a ghostty-format config
//! from the Theme, writes it to a temp file, and hands the path to libghostty.
//! (ghostty's own format is `key = value`, one per line — NOT toml. The user's
//! `purrtty.toml` is parsed into a Theme first, in the Settings slice.)

const std = @import("std");
const Theme = @import("theme.zig").Theme;

/// Build the ghostty config text for `theme`. Caller owns the returned slice.
pub fn generate(allocator: std.mem.Allocator, theme: Theme) ![]u8 {
    var aw = std.Io.Writer.Allocating.init(allocator);
    errdefer aw.deinit();
    const w = &aw.writer;

    var c: [7]u8 = undefined;

    try w.writeAll("# purrtty — generated from theme tokens; do not edit by hand\n");
    try w.print("background = {s}\n", .{theme.background.format(&c)});
    try w.print("foreground = {s}\n", .{theme.foreground.format(&c)});
    try w.print("cursor-color = {s}\n", .{theme.accent.format(&c)});
    try w.print("selection-background = {s}\n", .{theme.selection_bg.format(&c)});
    try w.print("selection-foreground = {s}\n", .{theme.selection_fg.format(&c)});
    try w.print("font-family = {s}\n", .{theme.font_family});
    try w.print("font-size = {d}\n", .{theme.font_size});

    // CRT motif from the prototype: a faint phosphor cursor that breathes.
    try w.writeAll("cursor-style = block\n");
    try w.writeAll("cursor-style-blink = true\n");

    const pal = theme.palette();
    for (pal, 0..) |color, i| {
        try w.print("palette = {d}={s}\n", .{ i, color.format(&c) });
    }

    return aw.toOwnedSlice();
}

test "generate emits phosphor palette" {
    const a = std.testing.allocator;
    const out = try generate(a, Theme.phosphor);
    defer a.free(out);

    try std.testing.expect(std.mem.indexOf(u8, out, "background = #0E0E0F") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "cursor-color = #3DDC97") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "palette = 2=#3DDC97") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "font-family = JetBrains Mono") != null);
}
