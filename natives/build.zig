const std = @import("std");

const Platform = struct {
    lib_name: []const u8,
    target_query: std.Target.Query,
    link_z_notext: bool = false,

    pub fn enrichStepName(self: Platform, allocator: std.mem.Allocator, step: *std.Build.Step) void {
        const target_description = self.target_query.allocDescription(allocator) catch @panic("OOM");
        step.name = std.fmt.allocPrint(allocator, "{s} ({s})", .{ step.name, target_description }) catch @panic("OOM");
    }
};

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const minimum_glibc_version: std.SemanticVersion = .{ .major = 2, .minor = 28, .patch = 0 };
    const platforms = [_]Platform{
        // Windows
        Platform{
            .lib_name = "opsu64",
            .target_query = .{
                .cpu_arch = .x86_64,
                .os_tag = .windows,
            },
        },
        // We don't support 32-bit Windows since Zig has some troubles with it.
        // https://github.com/ziglang/zig/issues/17630 (Windows)

        // Linux
        Platform{
            .lib_name = "opsu64",
            .target_query = .{
                .cpu_arch = .x86_64,
                .os_tag = .linux,
                .abi = .gnu,
                .glibc_version = minimum_glibc_version,
            },
        },
        Platform{
            .lib_name = "opsu",
            .target_query = .{
                .cpu_arch = .x86,
                .os_tag = .linux,
                .abi = .gnu,
                .glibc_version = minimum_glibc_version,
            },
            .link_z_notext = true,
        },

        // TODO: Support macOS. This requires obtaining headers for CoreAudio.
    };

    const check = b.step("check", "Check for compilation errors");
    for (platforms) |platform| {
        setupPlatform(b, .{
            .optimize = optimize,
            .platform = platform,
            .check_step = check,
        });
    }
}

const SetupPlatformOptions = struct {
    optimize: std.builtin.OptimizeMode,
    platform: Platform,
    check_step: *std.Build.Step,
};

fn setupPlatform(b: *std.Build, options: SetupPlatformOptions) void {
    const target = b.resolveTargetQuery(options.platform.target_query);

    const jni = b.dependency("JNI", .{
        .target = target,
        .optimize = options.optimize,
    });

    const miniaudio = b.addTranslateC(.{
        .root_source_file = b.path("vendor/miniaudio.h"),
        .target = target,
        .optimize = options.optimize,
    });
    options.platform.enrichStepName(b.allocator, &miniaudio.step);

    // This creates a "module", which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Every executable or library we compile will be based on one or more modules.
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = options.optimize,
        .link_libc = true,
    });
    lib_mod.addCSourceFiles(.{
        .files = &.{
            "vendor/miniaudio.c",
            "vendor/stb_vorbis.c",
        },
    });
    lib_mod.addImport("jni", jni.module("JNI"));
    lib_mod.addImport("miniaudio", miniaudio.createModule());

    const lib_options = SetupLibraryOptions{
        .platform = options.platform,
        .root_module = lib_mod,
    };
    const lib = setupLibrary(b, lib_options);

    const lib_install = b.addInstallArtifact(lib, .{
        // Always put the library in zig-out/lib. By default, Windows DLLs get
        // put in zig-out/bin instead.
        .dest_dir = .{ .override = .lib },
        // JNI doesn't need an import library on Windows, so don't generate one.
        .implib_dir = .disabled,
        // Make sure to only set this on Windows, or else Zig will try to
        // install nonexistent PDB files for Linux.
        .pdb_dir = if (target.result.os.tag == .windows) .{ .override = .{ .custom = "pdb" } } else .disabled,
    });
    options.platform.enrichStepName(b.allocator, &lib_install.step);
    b.getInstallStep().dependOn(&lib_install.step);

    const lib_check = setupLibrary(b, lib_options);
    options.check_step.dependOn(&lib_check.step);
}

const SetupLibraryOptions = struct {
    platform: Platform,
    root_module: *std.Build.Module,
};

fn setupLibrary(b: *std.Build, options: SetupLibraryOptions) *std.Build.Step.Compile {
    // Now, we will create a static library based on the module we created above.
    // This creates a `std.Build.Step.Compile`, which is the build step responsible
    // for actually invoking the compiler.
    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = options.platform.lib_name,
        .root_module = options.root_module,
    });
    options.platform.enrichStepName(b.allocator, &lib.step);
    // Workaround for https://github.com/ziglang/zig/issues/7935
    lib.link_z_notext = options.platform.link_z_notext;

    return lib;
}
