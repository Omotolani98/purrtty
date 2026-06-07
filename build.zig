const std = @import("std");

// purrtty — build for Zig 0.15.2 (must match libghostty's pinned Zig).
//
// purrtty links a *prebuilt* `vendor/libghostty.a` (+ its pinned `vendor/ghostty.h`).
// Produce that archive once with `scripts/build-libghostty.sh`, then `zig build run`.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "purrtty",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.addIncludePath(b.path("vendor"));
    exe.linkLibC();
    exe.linkLibCpp(); // libghostty pulls in C++ deps (spirv-cross, dcimgui)

    // The terminal core. Built separately (see scripts/build-libghostty.sh).
    const lib = "vendor/libghostty.a";
    if (fileExists(b, lib)) {
        exe.addObjectFile(b.path(lib));
    } else {
        std.log.warn(
            "{s} not found — run scripts/build-libghostty.sh first. " ++
                "Configuring anyway so `zig build test` works.",
            .{lib},
        );
    }

    // Obj-C runtime + the frameworks libghostty and our AppKit glue need.
    exe.linkSystemLibrary("objc");
    const frameworks = [_][]const u8{
        "AppKit",     "Foundation", "CoreText",  "CoreGraphics",
        "CoreVideo",  "QuartzCore", "Metal",     "MetalKit",
        "IOSurface",  "IOKit",      "Carbon",    "Security",
        "Cocoa",      "AudioToolbox",
    };
    for (frameworks) |f| exe.linkFramework(f);

    b.installArtifact(exe);

    // `zig build run`
    const run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    if (b.args) |args| run.addArgs(args);
    b.step("run", "Run purrtty").dependOn(&run.step);

    // `zig build test` — version-agnostic core logic (no libghostty needed).
    const test_step = b.step("test", "Run unit tests (tokens + theme + config)");
    for ([_][]const u8{ "src/tokens.zig", "src/config.zig" }) |src| {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(src),
                .target = target,
                .optimize = optimize,
            }),
        });
        t.linkLibC();
        test_step.dependOn(&b.addRunArtifact(t).step);
    }
}

fn fileExists(b: *std.Build, rel: []const u8) bool {
    const abs = b.pathFromRoot(rel);
    std.fs.accessAbsolute(abs, .{}) catch return false;
    return true;
}
