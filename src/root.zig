//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

// Shared Solution type
pub const Solution = struct {
    part1: ?usize,
    part2: ?usize,
};

pub fn runSolution(
    comptime day_name: []const u8,
    input: []const u8,
    solveFn: anytype,
    extra_args: anytype,
) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var timer = try std.time.Timer.start();

    const args_type = @typeInfo(@TypeOf(extra_args));
    const num_args = if (args_type == .@"struct") args_type.@"struct".fields.len else 0;

    const solution = switch (num_args) {
        0 => try solveFn(allocator, input),
        1 => try solveFn(allocator, input, extra_args[0]),
        2 => try solveFn(allocator, input, extra_args[0], extra_args[1]),
        3 => try solveFn(allocator, input, extra_args[0], extra_args[1], extra_args[2]),
        else => @compileError("Too many extra args (max 3)"),
    };
    const elapsed = timer.read();

    std.debug.print("{s}: (Run Time: {d:.2}ms)\n", .{ day_name, @as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms });
    std.debug.print("\t Part 1: {?}\n", .{solution.part1});
    std.debug.print("\t Part 2: {?}\n", .{solution.part2});
}

pub const day01 = @import("puzzles/day01.zig");
pub const day02 = @import("puzzles/day02.zig");
pub const day03 = @import("puzzles/day03.zig");
pub const day04 = @import("puzzles/day04.zig");
pub const day05 = @import("puzzles/day05.zig");
pub const day06 = @import("puzzles/day06.zig");
pub const day07 = @import("puzzles/day07.zig");
pub const day08 = @import("puzzles/day08.zig");
pub const day09 = @import("puzzles/day09.zig");
pub const day10 = @import("puzzles/day10.zig");
pub const day11 = @import("puzzles/day11.zig");
pub const day12 = @import("puzzles/day12.zig");

test {
    std.testing.refAllDecls(@This());
    _ = @import("puzzles/day01.zig");
    _ = @import("puzzles/day02.zig");
    _ = @import("puzzles/day03.zig");
    _ = @import("puzzles/day04.zig");
    _ = @import("puzzles/day05.zig");
    _ = @import("puzzles/day06.zig");
    _ = @import("puzzles/day07.zig");
    _ = @import("puzzles/day08.zig");
    _ = @import("puzzles/day09.zig");
    _ = @import("puzzles/day10.zig");
    _ = @import("puzzles/day11.zig");
    _ = @import("puzzles/day12.zig");
}
