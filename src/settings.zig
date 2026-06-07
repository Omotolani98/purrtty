//! Parse `purrtty.toml` into a Settings (Theme + mascot config).
//!
//! Minimal subset parser for the small, flat config purrtty emits: `[section]`
//! headers + `key = value` (quoted strings, numbers, bools, `#` comments). Not a
//! full TOML implementation — just what the schema in purrtty.toml uses.

const std = @import("std");
const tokens = @import("tokens.zig");
const Theme = @import("theme.zig").Theme;

pub const Mascot = struct {
    enabled: bool = true,
    cat: tokens.CatPalette = tokens.cats[0],
    speed: f64 = 1.0, // pace multiplier, clamped 0.3–2.5
};

pub const Settings = struct {
    theme: Theme = Theme.phosphor,
    mascot: Mascot = .{},
};

/// Load + parse `purrtty.toml` from `path`; returns defaults if missing/unreadable.
/// Reads via libc so it's stable across Zig 0.15/0.16.
pub fn loadOrDefault(path: [*:0]const u8) Settings {
    var buf: [1 << 16]u8 = undefined;
    const f = std.c.fopen(path, "rb") orelse return .{};
    defer _ = std.c.fclose(f);
    const n = std.c.fread(&buf, 1, buf.len, f);
    return parse(buf[0..n]);
}

pub fn parse(text: []const u8) Settings {
    var s: Settings = .{};
    var section: []const u8 = "";

    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        const line = trim(raw);
        if (line.len == 0 or line[0] == '#') continue;

        if (line[0] == '[') {
            const end = std.mem.indexOfScalar(u8, line, ']') orelse continue;
            section = line[1..end];
            continue;
        }

        const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = trim(line[0..eq]);
        const val = value(trim(line[eq + 1 ..]));
        apply(&s, section, key, val);
    }
    return s;
}

fn apply(s: *Settings, section: []const u8, key: []const u8, val: []const u8) void {
    if (eql(section, "appearance")) {
        if (eql(key, "mode")) {
            s.theme.mode = if (eql(val, "light")) .light else .dark;
        } else if (eql(key, "accent")) {
            if (tokens.Color.parse(val)) |c| s.theme.accent = c;
        }
    } else if (eql(section, "font")) {
        if (eql(key, "family")) {
            s.theme.font_family = tokens.fontFamily(val);
        } else if (eql(key, "size")) {
            if (parseF32(val)) |v| s.theme.font_size = v;
        }
    } else if (eql(section, "crt")) {
        if (eql(key, "scanline")) {
            if (parseF32(val)) |v| s.theme.scanline = clampF32(v, 0, tokens.scanline_max);
        }
    } else if (eql(section, "mascot")) {
        if (eql(key, "enabled")) {
            s.mascot.enabled = eql(val, "true");
        } else if (eql(key, "cat")) {
            s.mascot.cat = tokens.catById(val);
        } else if (eql(key, "speed")) {
            if (parseF64(val)) |v| s.mascot.speed = clampF64(v, 0.3, 2.5);
        }
    }
}

// ── tiny helpers ─────────────────────────────────────────────────────────────
fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}
fn trim(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t\r");
}
/// Strip an inline `# comment` (outside quotes) and surrounding double quotes.
fn value(v: []const u8) []const u8 {
    if (v.len > 0 and v[0] == '"') {
        if (std.mem.indexOfScalarPos(u8, v, 1, '"')) |end| return v[1..end];
        return v[1..];
    }
    const cut = std.mem.indexOfScalar(u8, v, '#') orelse v.len;
    return trim(v[0..cut]);
}
fn parseF64(s: []const u8) ?f64 {
    return std.fmt.parseFloat(f64, s) catch null;
}
fn parseF32(s: []const u8) ?f32 {
    return std.fmt.parseFloat(f32, s) catch null;
}
fn clampF64(v: f64, lo: f64, hi: f64) f64 {
    return @min(@max(v, lo), hi);
}
fn clampF32(v: f32, lo: f32, hi: f32) f32 {
    return @min(@max(v, lo), hi);
}

test "parse drives theme + mascot" {
    const s = parse(
        \\[appearance]
        \\mode = "light"
        \\accent = "#FFB454"
        \\[font]
        \\family = "Space"
        \\size = 16
        \\[crt]
        \\scanline = 0.10
        \\[mascot]
        \\enabled = false
        \\cat = "tabby"
        \\speed = 1.8
    );
    try std.testing.expectEqual(@as(u8, 0xFF), s.theme.accent.r);
    try std.testing.expectEqualStrings("Space Mono", s.theme.font_family);
    try std.testing.expectEqual(@as(f32, 16), s.theme.font_size);
    try std.testing.expect(s.theme.scanline > 0.09 and s.theme.scanline < 0.11);
    try std.testing.expect(!s.mascot.enabled);
    try std.testing.expectEqualStrings("tabby", s.mascot.cat.id);
    try std.testing.expect(s.mascot.speed > 1.79 and s.mascot.speed < 1.81);
}

test "missing keys keep phosphor defaults" {
    const s = parse("[appearance]\n");
    try std.testing.expectEqual(@as(u8, 0x3D), s.theme.accent.r); // #3DDC97
    try std.testing.expect(s.mascot.enabled);
}
