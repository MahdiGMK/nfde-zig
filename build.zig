const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target =
        if (builtin.os.tag == .windows)
            b.resolveTargetQuery(.{
                .abi = .msvc,
            })
        else
            b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("nfde", .{
        .root_source_file = b.path("src/nfd.zig"),
        .target = target,
        .optimize = optimize,
    });
    const lib = b.addLibrary(.{
        .name = "nfde-zig",
        .root_module = mod,
    });

    const csrc = b.dependency("nfde", .{});

    lib.addIncludePath(csrc.path("src/include/"));

    const build_os = lib.root_module.resolved_target.?.result.os.tag;

    if (build_os == .windows) {
        mod.link_libc = true;
        mod.link_libcpp = true;
        mod.linkSystemLibrary("shell32", .{});
        mod.linkSystemLibrary("ole32", .{});
        mod.linkSystemLibrary("uuid", .{}); // needed by MinGW

        mod.addCSourceFile(.{
            .file = csrc.path("src/nfd_win.cpp"),
            .language = .cpp,
            .flags = &.{
                "-fno-exceptions",
            },
        });
    } else if (build_os == .macos) {
        mod.linkSystemLibrary("objc", .{});
        mod.linkFramework("Foundation", .{});
        mod.linkFramework("Cocoa", .{});
        mod.linkFramework("AppKit", .{});
        mod.linkFramework("UniformTypeIdentifiers", .{});

        mod.addCSourceFile(.{
            .file = csrc.path("src/nfd_cocoa.m"),
            .language = .objective_c,
        });
    } else {
        const use_portal = b.option(bool, "use-portal", "Use portal for the window backend on Linux instead of GTK.") orelse false;

        lib.linkLibCpp();

        if (use_portal) {
            lib.linkSystemLibrary2("xdg-desktop-portal", .{ .use_pkg_config = .force });
            lib.linkSystemLibrary2("dbus-1", .{ .use_pkg_config = .force });
        } else {
            lib.linkSystemLibrary2("gtk+-3.0", .{ .use_pkg_config = .force });
            lib.linkSystemLibrary2("gdk-3.0", .{ .use_pkg_config = .force });
        }

        lib.addCSourceFile(.{
            .file = csrc.path(if (use_portal) "src/nfd_portal.cpp" else "src/nfd_gtk.cpp"),
            .language = .cpp,
        });
    }

    b.installArtifact(lib);

    var tests = b.addTest(.{
        .root_module = lib.root_module,
    });

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&tests.step);

    const demo_exe = b.addExecutable(.{
        .name = "demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("demo/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    demo_exe.root_module.addImport("nfdzig", lib.root_module);

    const demo_install = b.addInstallArtifact(demo_exe, .{});

    const run_demo = b.addRunArtifact(demo_exe);
    run_demo.step.dependOn(&demo_install.step);

    const demo_step = b.step("demo", "Run the demo");
    demo_step.dependOn(&run_demo.step);
}
