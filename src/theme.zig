//! Theme — the resolved appearance for a purrtty surface, assembled from the
//! design tokens. Slice 1 hardcodes the phosphor default; the Settings slice
//! will populate this from `purrtty.toml`. `config.zig` turns a Theme into the
//! ghostty config that libghostty actually consumes.

const tokens = @import("tokens.zig");
const Color = tokens.Color;

pub const Mode = enum { dark, light };

pub const Theme = struct {
    mode: Mode = .dark,
    accent: Color = tokens.accent_green,
    background: Color = tokens.bg,
    foreground: Color = tokens.text,
    selection_bg: Color = tokens.surface_3,
    selection_fg: Color = tokens.text,
    font_family: []const u8 = tokens.fonts[0].family,
    font_size: f32 = 14,
    /// CRT overlay opacity — consumed by the (deferred) scanline pass.
    scanline: f32 = tokens.scanline_default,

    /// The 16-entry ANSI palette, derived from the prototype's terminal
    /// semantics. Index = standard ANSI slot (0-7 normal, 8-15 bright).
    pub fn palette(self: Theme) [16]Color {
        // `out`/cursor follow the accent so a non-green accent recolors the
        // green slots too (matches the prototype: "prompt · cursor · sprites").
        const green = self.accent;
        return .{
            self.background, // 0  black
            tokens.term_err, // 1  red
            green, // 2  green
            tokens.term_amber, // 3  yellow
            tokens.term_info, // 4  blue
            tokens.term_mag, // 5  magenta
            tokens.term_cyan, // 6  cyan
            self.foreground, // 7  white
            tokens.dim, // 8  bright black
            tokens.term_err, // 9  bright red
            green, // 10 bright green
            tokens.term_amber, // 11 bright yellow
            tokens.term_info, // 12 bright blue
            tokens.term_mag, // 13 bright magenta
            tokens.term_cyan, // 14 bright cyan
            self.foreground, // 15 bright white
        };
    }

    /// Phosphor-green dark default — the design's hero look.
    pub const phosphor: Theme = .{};
};
