const std = @import("std");
const Nfd = @import("nfdzig");

pub fn main() !u8 {
    Nfd.init() catch |err| {
        if (err == Nfd.NFDError.Error) {
            std.debug.print("error from NFD: {s}\n", .{Nfd.getError()});
            return 1;
        }

        return err;
    };
    defer Nfd.deinit();

    var filters = [_]Nfd.Filter{
        .{
            .name = "Windows executables",
            .filter = "exe",
        },
        .{
            .name = "C source files",
            .filter = "c",
        },
    };

    const openF = try Nfd.openFile(std.heap.smp_allocator, .{ .filters = &filters });
    defer openF.deinit();
    switch (openF) {
        .okay => |addr| std.debug.print("selected {s}\n", .{addr.path}),
        .cancel => std.debug.print("canceled\n", .{}),
    }

    const saveF = try Nfd.saveFile(std.heap.smp_allocator, .{ .filters = &filters });
    defer saveF.deinit();
    switch (saveF) {
        .okay => |addr| std.debug.print("selected {s}\n", .{addr.path}),
        .cancel => std.debug.print("canceled\n", .{}),
    }

    const openFs = try Nfd.openFiles(std.heap.smp_allocator, .{ .filters = &filters });
    defer openFs.deinit();
    switch (openFs) {
        .okay => |res| {
            std.debug.print("selected #{}\n", .{try res.count()});
            var iter = try res.enumerator();
            defer iter.deinit();

            while (try iter.next()) |path| {
                std.debug.print("selected {s}\n", .{path});
            }
        },
        .cancel => std.debug.print("canceled\n", .{}),
    }

    const pickF = try Nfd.pickFolder(.{});
    defer pickF.deinit();
    switch (pickF) {
        .okay => |addr| std.debug.print("selected {s}\n", .{addr.path}),
        .cancel => std.debug.print("canceled\n", .{}),
    }

    const pickFs = try Nfd.pickFolders(.{});
    defer pickFs.deinit();
    switch (pickFs) {
        .okay => |res| {
            std.debug.print("selected #{}\n", .{try res.count()});
            var iter = try res.enumerator();
            defer iter.deinit();

            while (try iter.next()) |path| {
                std.debug.print("selected {s}\n", .{path});
            }
        },
        .cancel => std.debug.print("canceled\n", .{}),
    }

    return 0;
}
