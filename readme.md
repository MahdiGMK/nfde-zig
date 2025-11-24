# nfde-zig

A full wrapper around the [nativefiledialog-extended](https://github.com/btzy/nativefiledialog-extended) library.

## Current Build Status

### Windows

Fails when using the MSVC ABI.

The error message is in a Pastebin because it's so large
https://pastebin.com/raw/EGgDNKnf

### MacOS

Builds successfully, but `open` doesn't give back a string when called and it doesn't allocate for it.

### Linux

Builds successfully.

## Installation

Install the library with `zig fetch --save git+https://github.com/MahdiGMK/nfde-zig.git`.

Then add these lines to your build.zig :

```zig
const nfde = b.dependency("nfde_zig", .{});
root_module.addImport("nfde", nfde.module("nfde"));
```

## Example

```zig
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
}
```
