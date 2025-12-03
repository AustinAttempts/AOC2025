const std = @import("std");

const STARTING_LOCK_VALUE: i32 = 50;

pub fn main() !void {
    var timer = try std.time.Timer.start();

    const input = @embedFile("inputs/day01.txt");
    std.debug.print("Part 1 Answer: {d}\n", .{try part1(input)});
    std.debug.print("Part 2 Answer: {d}\n", .{try part2(input)});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

pub fn part1(input: []const u8) !i32 {
    var code: i32 = 0;
    var lock_value: i32 = STARTING_LOCK_VALUE;
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        const ticks = @mod(try std.fmt.parseInt(i32, line[1..], 10), 100);
        switch (line[0]) {
            'R' => lock_value += ticks,
            'L' => lock_value -= ticks,
            else => return error.InvalidDirection,
        }

        // Handle wrap-around
        if (lock_value < 0) {
            lock_value += 100;
        } else if (lock_value >= 100) {
            lock_value -= 100;
        }

        // Check for code match
        if (lock_value == 0) {
            code += 1;
        }
    }
    return code;
}

pub fn part2(input: []const u8) !usize {
    var code: usize = 0;
    var lock_value: i32 = STARTING_LOCK_VALUE;
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        const ticks = try std.fmt.parseInt(usize, line[1..], 10);

        for (0..ticks) |_| {
            if (lock_value == 0) {
                code += 1;
            }
            switch (line[0]) {
                'R' => lock_value += 1,
                'L' => lock_value -= 1,
                else => return error.InvalidDirection,
            }

            if (lock_value < 0) {
                lock_value += 100;
            } else if (lock_value >= 100) {
                lock_value -= 100;
            }
        }
    }
    return code;
}

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");
    try std.testing.expectEqual(3, try part1(input));
}

test "part 2" {
    const input = @embedFile("inputs/test_case.txt");
    try std.testing.expectEqual(6, try part2(input));
}
