//! libghostty C API, imported from the real pinned header (`vendor/ghostty.h`).
//! Everything purrtty calls into the terminal core goes through `c` here.
//!
//! NOTE: libghostty's API is explicitly "in flux" upstream. `vendor/ghostty.h`
//! is pinned alongside the `libghostty.a` we link (see scripts/build-libghostty.sh);
//! keep the two in lockstep when bumping ghostty.
pub const c = @cImport({
    @cInclude("ghostty.h");
});
