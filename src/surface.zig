//! A libghostty surface bound to a macOS NSView. libghostty's Metal renderer
//! draws the terminal into the view's layer on its own render thread; purrtty
//! just forwards size / content-scale / focus / key events.

const std = @import("std");
const gh = @import("ghostty.zig").c;
const App = @import("app.zig").App;

pub const Surface = struct {
    inner: gh.ghostty_surface_t,

    /// Create a surface that renders into `nsview`. `scale` is the backing
    /// scale factor (NSWindow.backingScaleFactor), `font_size` in points,
    /// `cwd` the working directory for the spawned shell.
    pub fn init(
        app: *App,
        nsview: *anyopaque,
        scale: f64,
        font_size: f32,
        cwd: [*:0]const u8,
    ) !Surface {
        var cfg = gh.ghostty_surface_config_new();
        cfg.platform_tag = gh.GHOSTTY_PLATFORM_MACOS;
        cfg.platform.macos = .{ .nsview = nsview };
        cfg.scale_factor = scale;
        cfg.font_size = font_size;
        cfg.working_directory = cwd;

        const inner = gh.ghostty_surface_new(app.inner, &cfg) orelse return error.GhosttySurface;
        return .{ .inner = inner };
    }

    pub fn deinit(self: *Surface) void {
        gh.ghostty_surface_free(self.inner);
    }

    pub fn setContentScale(self: *Surface, x: f64, y: f64) void {
        gh.ghostty_surface_set_content_scale(self.inner, x, y);
    }

    /// Pixel dimensions (already multiplied by the backing scale).
    pub fn setSize(self: *Surface, w: u32, h: u32) void {
        gh.ghostty_surface_set_size(self.inner, w, h);
    }

    pub fn setFocus(self: *Surface, focused: bool) void {
        gh.ghostty_surface_set_focus(self.inner, focused);
    }

    pub fn setOcclusion(self: *Surface, visible: bool) void {
        gh.ghostty_surface_set_occlusion(self.inner, visible);
    }

    pub fn draw(self: *Surface) void {
        gh.ghostty_surface_draw(self.inner);
    }

    /// Forward a translated key event. Returns true if ghostty consumed it.
    pub fn key(self: *Surface, ev: gh.ghostty_input_key_s) bool {
        return gh.ghostty_surface_key(self.inner, ev);
    }
};
