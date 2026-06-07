//! Design tokens for purrtty — copied verbatim from the handoff prototype
//! (`rekord/project/purrtty.css` + `purrtty-canvas.jsx`). This is the single
//! source of truth for color/type; every later slice (mascot, scanlines,
//! settings) reads from here. Slice 1 uses only the terminal colors + fonts.

const std = @import("std");

/// 24-bit RGB color. Parsed from the prototype's `#RRGGBB` hex strings so the
/// values stay glanceably identical to the CSS.
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,

    /// Parse `#RRGGBB` or `RRGGBB`. Comptime-friendly so tokens below are
    /// validated at build time — a malformed hex literal is a compile error.
    pub fn hex(comptime s: []const u8) Color {
        const h = if (s.len > 0 and s[0] == '#') s[1..] else s;
        if (h.len != 6) @compileError("color hex must be 6 digits: " ++ s);
        return .{
            .r = parseByte(h[0..2]),
            .g = parseByte(h[2..4]),
            .b = parseByte(h[4..6]),
        };
    }

    fn parseByte(comptime pair: []const u8) u8 {
        return std.fmt.parseInt(u8, pair, 16) catch @compileError("bad hex byte: " ++ pair);
    }

    /// Render as `#RRGGBB` (ghostty config + most consumers want this form).
    pub fn format(self: Color, buf: *[7]u8) []const u8 {
        return std.fmt.bufPrint(buf, "#{X:0>2}{X:0>2}{X:0>2}", .{ self.r, self.g, self.b }) catch unreachable;
    }

    /// Runtime parse of `#RRGGBB` / `RRGGBB` (for config values). null if invalid.
    pub fn parse(s: []const u8) ?Color {
        const h = if (s.len > 0 and s[0] == '#') s[1..] else s;
        if (h.len != 6) return null;
        return .{
            .r = std.fmt.parseInt(u8, h[0..2], 16) catch return null,
            .g = std.fmt.parseInt(u8, h[2..4], 16) catch return null,
            .b = std.fmt.parseInt(u8, h[4..6], 16) catch return null,
        };
    }
};

// ── canvas ────────────────────────────────────────────────────────────────
pub const bg = Color.hex("#0E0E0F"); // near-black, slightly warm
pub const bg_2 = Color.hex("#0A0A0B");
pub const surface = Color.hex("#161619");
pub const surface_2 = Color.hex("#1C1C21");
pub const surface_3 = Color.hex("#26262C");

// ── text ──────────────────────────────────────────────────────────────────
pub const text = Color.hex("#E9E9E6"); // off-white primary
pub const dim = Color.hex("#8C8C94"); // muted secondary
pub const faint = Color.hex("#5A5A62");

// ── accents (default phosphor green; rest are the picker options) ───────────
pub const accent_green = Color.hex("#3DDC97"); // default — CRT phosphor
pub const accent_amber = Color.hex("#FFB454");
pub const accent_blue = Color.hex("#7AA2F7");
pub const accent_red = Color.hex("#F2787B");

/// The four accent swatches from the settings panel, in order.
pub const accents = [_]Color{ accent_green, accent_amber, accent_blue, accent_red };

// ── terminal semantics (CSS .term .ok/.err/.info/.amber/.mag) ───────────────
pub const term_out = Color.hex("#3DDC97"); // success / stdout
pub const term_err = Color.hex("#F2787B"); // soft red
pub const term_info = Color.hex("#7AA2F7"); // muted blue
pub const term_amber = Color.hex("#FFB454");
pub const term_mag = Color.hex("#C3A6FF");
pub const term_cyan = Color.hex("#5BC8C0"); // not in prototype; chosen to complete ANSI

/// Terminal-font options from the prototype's FONTS list. Index 0 is default.
pub const Font = struct { label: []const u8, family: []const u8 };
pub const fonts = [_]Font{
    .{ .label = "JetBrains", .family = "JetBrains Mono" },
    .{ .label = "Plex", .family = "IBM Plex Mono" },
    .{ .label = "Space", .family = "Space Mono" },
};

/// CRT scanline overlay opacity. Prototype default + range.
pub const scanline_default: f32 = 0.05;
pub const scanline_max: f32 = 0.16;

/// Look up a terminal font by its short label ("JetBrains"/"Plex"/"Space") or by
/// exact family name; returns the family string. Falls back to the default.
pub fn fontFamily(name: []const u8) []const u8 {
    for (fonts) |f| {
        if (std.mem.eql(u8, f.label, name) or std.mem.eql(u8, f.family, name)) return f.family;
    }
    return name; // allow any installed monospace
}

// ── cat sprite palettes (mascot slice — kept here as the single source) ──────
pub const CatPalette = struct {
    id: []const u8,
    name: []const u8,
    /// k outline · g body · l belly/light · s stripe · e eye · p nose/pad · b blush
    k: Color,
    g: Color,
    l: Color,
    s: Color,
    e: Color,
    p: Color,
    b: Color,
};
pub const cats = blk: {
    @setEvalBranchQuota(100000); // comptime hex parsing of the whole palette table
    break :blk [_]CatPalette{
        .{ .id = "gray", .name = "mochi", .k = Color.hex("#23252b"), .g = Color.hex("#aab1b8"), .l = Color.hex("#c8cdd3"), .s = Color.hex("#7c838b"), .e = Color.hex("#1b1d22"), .p = Color.hex("#f0a6bf"), .b = Color.hex("#f3b9cd") },
        .{ .id = "tabby", .name = "biscuit", .k = Color.hex("#3a2a1c"), .g = Color.hex("#e7a85a"), .l = Color.hex("#fbf2e2"), .s = Color.hex("#c8842f"), .e = Color.hex("#2a1d12"), .p = Color.hex("#e58aa6"), .b = Color.hex("#f0a8c0") },
        .{ .id = "green", .name = "phosphor", .k = Color.hex("#0c3b27"), .g = Color.hex("#3DDC97"), .l = Color.hex("#aef5d2"), .s = Color.hex("#1f9c66"), .e = Color.hex("#06231a"), .p = Color.hex("#0c3b27"), .b = Color.hex("#27c486") },
    };
};

/// Cat palette by id ("gray"/"tabby"/"green"); defaults to gray.
pub fn catById(id: []const u8) CatPalette {
    for (cats) |c| {
        if (std.mem.eql(u8, c.id, id)) return c;
    }
    return cats[0];
}

test "color parse + format roundtrip" {
    var buf: [7]u8 = undefined;
    try std.testing.expectEqualStrings("#3DDC97", accent_green.format(&buf));
    try std.testing.expectEqual(@as(u8, 0x0E), bg.r);
}
