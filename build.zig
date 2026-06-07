const std = @import("std");

// purrtty — local build with Zig 0.16 (Homebrew) on macOS.
//
// Split toolchain (see README):
//   • libghostty.a is built in CI with Zig 0.15.2 on a macОS 14 runner
//     (ghostty pins 0.15.x, which can't link on macOS 26). Download the CI
//     artifact into vendor/libghostty.a + vendor/ghostty.h.
//   • purrtty itself builds here with Zig 0.16, linking that C archive. 0.16 is
//     the only toolchain that links Mach-O against the macOS 26 SDK.
//
//   zig build run
const FRAMEWORKS = [_][]const u8{
    "AppKit",     "Foundation",  "Cocoa",       "QuartzCore",
    "Metal",      "MetalKit",    "CoreText",    "CoreGraphics",
    "CoreVideo",  "IOSurface",   "IOKit",       "Carbon",
    "Security",   "AudioToolbox", "CoreFoundation",
    "UniformTypeIdentifiers",    "ApplicationServices",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true, // libghostty pulls in C++ deps (spirv-cross, dcimgui)
    });
    mod.addIncludePath(b.path("vendor"));

    // Requires vendor/libghostty.a (download the CI artifact first — see README).
    mod.addObjectFile(b.path("vendor/libghostty.a"));

    mod.linkSystemLibrary("objc", .{});
    for (FRAMEWORKS) |f| mod.linkFramework(f, .{});

    const exe = b.addExecutable(.{ .name = "purrtty", .root_module = mod });
    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    if (b.args) |args| run.addArgs(args);
    b.step("run", "Run purrtty").dependOn(&run.step);

    // `zig build test` — version-agnostic core logic (no libghostty needed).
    const test_step = b.step("test", "Run unit tests (tokens + config)");
    for ([_][]const u8{ "src/tokens.zig", "src/config.zig", "src/settings.zig" }) |src| {
        const tmod = b.createModule(.{
            .root_source_file = b.path(src),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = tmod })).step);
    }
}
