const std = @import("std");

const Solution = struct {
    part1: usize,
    part2: usize,
};

pub fn main() !void {
    var timer = try std.time.Timer.start();

    const input = @embedFile("inputs/day01.txt");
    const solution = try secretEntrance(input);
    std.debug.print("Part 1 Answer: {d}\n", .{solution.part1});
    std.debug.print("Part 2 Answer: {d}\n", .{solution.part2});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

fn secretEntrance(input: []const u8) !Solution {
    const LOCK_MODULO: isize = 100;
    var lock_value = 50;
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
    const input = @embedFile("inputs/test_case.txt");
    const part1 = (try secretEntrance(input)).part1;
    try std.testing.expectEqual(3, part1);
}

test "part 2" {
    const input = @embedFile("inputs/test_case.txt");
    const part2 = (try secretEntrance(input)).part2;
    try std.testing.expectEqual(6, part2);
}
