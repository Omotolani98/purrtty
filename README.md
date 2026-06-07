# purrtty

> A pixel-native terminal — phosphor-green, CRT-flavored, with a chonky pixel
> cat that paces the bottom of the screen. Written in **Zig**, backed by
> **libghostty** (Ghostty's terminal core: VT parsing, PTY, GPU rendering,
> Kitty graphics protocol).

purrtty is a real terminal emulator, not a mockup. libghostty does the terminal;
purrtty adds the look (phosphor theme, CRT scanlines), the mascot, and the
settings — recreating the design in `design/` (a handoff from claude.ai/design).

## Status — Slice 1: themed terminal

| Area | State |
|------|-------|
| libghostty C bindings (`src/ghostty.zig`) | ✅ against pinned `vendor/ghostty.h` |
| AppKit/Obj-C glue — window, Metal view, key input (`src/objc.zig`, `src/window.zig`) | ✅ compiles |
| Theme → ghostty config pipeline (`src/tokens.zig`, `src/theme.zig`, `src/config.zig`) | ✅ unit-tested |
| Phosphor-green palette, JetBrains Mono, green cursor | ✅ wired |
| **Walking cat mascot** | ⏳ designed, deferred (overlay slice) |
| **CRT scanlines** | ⏳ deferred |
| **`purrtty.toml` parse + settings GUI** | ⏳ deferred (config defaults live in `theme.zig`) |

The whole source compiles cleanly against the real libghostty header with Zig
0.15.2 (`zig build-obj`), and the theme/config logic passes unit tests. What's
left for a runnable binary is producing & linking `libghostty.a` (below).

## Architecture

```
libghostty (terminal core + Metal renderer)  ──┐
                                               │ C ABI (vendor/ghostty.h)
purrtty (this repo, Zig):                      │
  main.zig    boot, theme, wire it together  ◄─┘
  app.zig     ghostty_app_t + runtime callbacks (wakeup → main-thread tick)
  surface.zig ghostty_surface_t bound to an NSView
  window.zig  NSWindow + CAMetalLayer-backed view + key forwarding
  objc.zig    minimal Obj-C runtime shim (no third-party binding)
  theme.zig   Theme struct + phosphor default
  config.zig  Theme → ghostty `key = value` config (loaded via load_file)
  tokens.zig  design tokens (colors, fonts, cat palettes) — single source
```

The mascot will be an **app overlay** composited over the surface (decided in
planning), not Kitty-protocol drawing. Inline pixel images / charts from the
design become real via libghostty's Kitty graphics support.

## Build

**Requirements**
- **Zig 0.15.2** — must match libghostty's pinned compiler (`build.zig.zon`).
- **Xcode / full Command Line Tools** — Metal shader compilation (`xcrun metal`).
- macOS on Apple Silicon (aarch64). Metal renderer; Linux/OpenGL is future work.

```sh
# 1. Build the terminal core (clones ghostty, ~30 deps, large first build).
#    Pin a ref for reproducibility, e.g. a tag or commit:
scripts/build-libghostty.sh main      # → vendor/libghostty.a + vendor/ghostty.h

# 2. Build & run purrtty.
zig build run
```

Run the version-agnostic core tests any time (no libghostty needed):

```sh
zig build test
```

### Toolchain note — macOS 26 (Tahoe) gotcha

There is a real three-way bind on **macOS 26**:

- ghostty requires **Zig 0.15.x** and **rejects 0.16** (`build.zig` does
  `requireZig("0.15.2")` → `@compileError` on 0.16, plus 0.16 std breakage).
- Zig **0.15.2 is the newest 0.15** and predates macOS 26, so its build runner /
  host tools fail to link against the macOS 26 SDK
  (`undefined symbol: __availability_version_check`, `_sigaction`, …). This means
  `zig build` (and therefore ghostty's own build) won't run with 0.15.2 here.
- Homebrew Zig **0.16** links fine on macOS 26 but can't build ghostty.

So on macOS 26 you currently **cannot build `libghostty.a` locally**. Workarounds:

1. **Build `libghostty.a` on macOS ≤ 15** (or a CI/VM image with it), then copy
   `libghostty.a` + `ghostty.h` into `vendor/` here. purrtty links + runs fine on
   macOS 26 when you pin an older deployment target:
   ```sh
   zig build run -Dtarget=aarch64-macos.15.0   # 0.15.2 links cleanly this way
   ```
2. Wait for ghostty to migrate to Zig 0.16 — then everything builds natively on
   macOS 26 with Homebrew zig.

**purrtty's own code is link-ready today:** building the exe against the SDK
leaves *only* the 16 `ghostty_*` symbols (from libghostty) and the objc runtime
unresolved — zero undefined symbols from our code. Drop in `libghostty.a` and it
runs.

## Design provenance

`design/` is the original HTML/CSS/JS prototype from claude.ai/design (the
`rekord`/purrtty handoff bundle). It's a scripted React mock — the visual target,
not shipping code. Color and type tokens are ported verbatim into
`src/tokens.zig`; sprite grids/palettes live there too for the mascot slice.

## Roadmap

1. **Slice 1 (this)** — themed terminal on libghostty. ✅ code; ⏳ link.
2. Mascot overlay — port `GRID_SIT` + gray/tabby/green palettes + waddle walker.
3. CRT scanline pass (Metal post-pass or low-opacity layer).
4. `purrtty.toml` parse + hot-reload, then the settings GUI from the design.
5. Pixel/glyph demos via Kitty graphics.
