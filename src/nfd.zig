const std = @import("std");
const Allocator = std.mem.Allocator;
const Arraylist = std.ArrayList;

const kf = @import("known-folders");

const nfd = @cImport(@cInclude("nfd.h"));

const Self = @This();

pub const NFDError = error{ Error, OutOfMemory };

pub const NFDResult = enum {
    okay,
    cancel,

    fn from_nfdresult(nfdresult: nfd.nfdresult_t) NFDError!NFDResult {
        return switch (nfdresult) {
            nfd.NFD_OKAY => .okay,
            nfd.NFD_CANCEL => .cancel,
            else => error.Error,
        };
    }
};

pub const Filter = struct {
    name: [:0]const u8,
    filter: [:0]const u8,
};

pub const OpenOptions = struct {
    default_path: ?[:0]const u8 = null,
    filters: []Filter = &.{},
};

pub const SaveOptions = struct {
    default_name: ?[:0]const u8 = null,
    default_path: ?[:0]const u8 = null,
    filters: []Filter = &.{},
};

pub const PickFolderOptions = struct {
    default_path: ?[:0]const u8 = null,
};

pub fn Result(comptime T: type) type {
    return union(NFDResult) {
        okay: T,
        cancel: void,
        pub fn deinit(self: *const @This()) void {
            switch (self.*) {
                .okay => |ok| T.deinit(&ok),
                else => {},
            }
        }
    };
}

pub fn init() NFDError!void {
    _ = try NFDResult.from_nfdresult(nfd.NFD_Init());
}

const Path = struct {
    path: [:0]const u8,
    pub fn deinit(self: *const Path) void {
        nfd.NFD_FreePathU8(@ptrCast(@constCast(self.path.ptr)));
    }
};
const PathSet = struct {
    ptr: *anyopaque,
    pub const PathEnum = struct {
        dat: nfd.nfdpathsetenum_t,
        pub fn next(self: *PathEnum) NFDError!?[:0]u8 {
            var output_slice: [*c]u8 = null;
            _ = try NFDResult.from_nfdresult(
                nfd.NFD_PathSet_EnumNextU8(&self.dat, @ptrCast(&output_slice)),
            );
            if (output_slice == null) return null;
            return @ptrCast(output_slice[0..std.mem.indexOfSentinel(u8, 0, output_slice)]);
        }
        pub fn deinit(self: *PathEnum) void {
            nfd.NFD_PathSet_FreeEnum(&self.dat);
        }
    };
    pub fn count(self: *const PathSet) NFDError!usize {
        var result: c_uint = 0;
        _ = try NFDResult.from_nfdresult(
            nfd.NFD_PathSet_GetCount(self.ptr, @ptrCast(&result)),
        );
        return @intCast(result);
    }
    pub fn get(self: *const PathSet, idx: usize) NFDError![:0]u8 {
        var output_slice: [*c]u8 = null;
        _ = try NFDResult.from_nfdresult(
            nfd.NFD_PathSet_GetPathU8(self.ptr, @intCast(idx), @ptrCast(&output_slice)),
        );
        return @ptrCast(output_slice[0..std.mem.indexOfSentinel(u8, 0, output_slice)]);
    }
    pub fn enumerator(self: *const PathSet) NFDError!PathEnum {
        var result: nfd.nfdpathsetenum_t = undefined;
        _ = try NFDResult.from_nfdresult(
            nfd.NFD_PathSet_GetEnum(self.ptr, @ptrCast(&result)),
        );
        return .{ .dat = result };
    }
    pub fn deinit(self: *const PathSet) void {
        nfd.NFD_PathSet_Free(self.ptr);
    }
};

pub fn openFile(allocator: Allocator, options: OpenOptions) NFDError!Result(Path) {
    var filters = try allocator.alloc(nfd.nfdfilteritem_t, options.filters.len);
    defer allocator.free(filters);
    for (filters[0..], options.filters) |*filter, f| {
        filter.* = .{
            .name = f.name.ptr,
            .spec = f.filter.ptr,
        };
    }

    const default_path = options.default_path orelse "";

    var output_slice: [*c]u8 = null;
    const result = try NFDResult.from_nfdresult(
        nfd.NFD_OpenDialogU8(@ptrCast(&output_slice), filters.ptr, @intCast(filters.len), default_path.ptr),
    );
    if (result == .okay)
        return .{ .okay = .{ .path = @ptrCast(output_slice[0..std.mem.indexOfSentinel(u8, 0, output_slice)]) } };
    return .cancel;
}
pub fn saveFile(allocator: Allocator, options: SaveOptions) NFDError!Result(Path) {
    var filters = try allocator.alloc(nfd.nfdfilteritem_t, options.filters.len);
    defer allocator.free(filters);
    for (filters[0..], options.filters) |*filter, f| {
        filter.* = .{
            .name = f.name.ptr,
            .spec = f.filter.ptr,
        };
    }

    const default_path = options.default_path orelse "";
    const default_name = options.default_name orelse "";

    var output_slice: [*c]u8 = null;
    const result = nfd.NFD_SaveDialogU8(@ptrCast(&output_slice), filters.ptr, @intCast(filters.len), default_path.ptr, default_name.ptr);
    const kind = try NFDResult.from_nfdresult(result);
    if (kind == .okay)
        return .{ .okay = .{ .path = @ptrCast(output_slice[0..std.mem.indexOfSentinel(u8, 0, output_slice)]) } };
    return .cancel;
}

pub fn openFiles(allocator: Allocator, options: OpenOptions) NFDError!Result(PathSet) {
    var filters = try allocator.alloc(nfd.nfdfilteritem_t, options.filters.len);
    defer allocator.free(filters);
    for (filters[0..], options.filters) |*filter, f| {
        filter.* = .{
            .name = f.name.ptr,
            .spec = f.filter.ptr,
        };
    }

    const default_path = options.default_path orelse "";

    var output_pathset: ?*anyopaque = null;
    const result = nfd.NFD_OpenDialogMultipleU8(@ptrCast(&output_pathset), filters.ptr, @intCast(filters.len), default_path.ptr);
    const kind = try NFDResult.from_nfdresult(result);
    if (kind == .okay)
        return .{ .okay = .{ .ptr = output_pathset.? } };
    return .cancel;
}

pub fn pickFolder(options: PickFolderOptions) NFDError!Result(Path) {
    const default_path = options.default_path orelse "";

    var output_slice: [*c]u8 = null;
    const result = try NFDResult.from_nfdresult(
        nfd.NFD_PickFolderU8(@ptrCast(&output_slice), default_path.ptr),
    );
    if (result == .okay)
        return .{ .okay = .{ .path = @ptrCast(output_slice[0..std.mem.indexOfSentinel(u8, 0, output_slice)]) } };
    return .cancel;
}

pub fn pickFolders(options: PickFolderOptions) NFDError!Result(PathSet) {
    const default_path = options.default_path orelse "";

    var output_pathset: ?*anyopaque = null;
    const result = try NFDResult.from_nfdresult(
        nfd.NFD_PickFolderMultipleU8(@ptrCast(&output_pathset), default_path.ptr),
    );
    if (result == .okay)
        return .{ .okay = .{ .ptr = output_pathset.? } };
    return .cancel;
}

pub fn getError() [*:0]const u8 {
    return nfd.NFD_GetError();
}

pub fn deinit() void {
    nfd.NFD_Quit();
    nfd.NFD_ClearError();
}
