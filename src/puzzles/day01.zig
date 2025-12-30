const std = @import("std");
const aoc = @import("../root.zig");

const Solution = aoc.Solution;

pub fn solve() !void {
    const input = @embedFile("../inputs/day01.txt");
    try aoc.runSolution("Day 01", input, secretEntrance, .{});
}

fn secretEntrance(allocator: std.mem.Allocator, input: []const u8) !Solution {
    _ = allocator;
    const LOCK_MODULO: isize = 100;
    var lock_value: isize = 50;
    var part1: usize = 0;
    var part2: usize = 0;

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        const direction = line[0];
        if (direction != 'R' and direction != 'L') {
            return error.InvalidDirection;
        }

        const ticks = try std.fmt.parseInt(usize, line[1..], 10);
        const delta: isize = if (direction == 'R') 1 else -1;

        for (0..ticks) |_| {
            if (lock_value == 0) part2 += 1;
            lock_value = @mod(lock_value + delta, LOCK_MODULO);
        }
        if (lock_value == 0) part1 += 1;
    }

    return .{ .part1 = part1, .part2 = part2 };
}

test "part 1" {
    const input = @embedFile("../inputs/tests/day01_test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const part1 = (try secretEntrance(allocator, input)).part1;
    try std.testing.expectEqual(3, part1);
}

test "part 2" {
    const input = @embedFile("../inputs/tests/day01_test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const part2 = (try secretEntrance(allocator, input)).part2;
    try std.testing.expectEqual(6, part2);
}
