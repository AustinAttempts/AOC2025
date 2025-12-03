const std = @import("std");

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("inputs/day03.txt");
    std.debug.print("Part 1 Answer: {d}\n", .{try part1(allocator, input)});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

pub fn part1(allocator: std.mem.Allocator, input: []const u8) !usize {
    var joltage_sum: usize = 0;
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |bank| {
        var joltage_str = try allocator.alloc(u8, 2);
        defer allocator.free(joltage_str);
        const upper = std.mem.indexOfMax(u8, bank[0 .. bank.len - 1]);
        const lower = std.mem.indexOfMax(u8, bank[upper + 1 .. bank.len]);
        joltage_str[0] = bank[upper];
        joltage_str[1] = bank[lower + upper + 1];
        const joltage = try std.fmt.parseInt(usize, joltage_str, 10);
        joltage_sum += joltage;
    }
    return joltage_sum;
}

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(357, try part1(allocator, input));
}
