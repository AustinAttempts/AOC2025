const std = @import("std");

const Solution = struct {
    part1: usize,
    part2: usize,
};

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const input = @embedFile("inputs/day03.txt");
    const solution = try lobby(allocator, input);

    std.debug.print("Part 1 Answer: {d}\n", .{solution.part1});
    std.debug.print("Part 2 Answer: {d}\n", .{solution.part2});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

fn lobby(allocator: std.mem.Allocator, input: []const u8) !Solution {
    var part1: usize = 0;
    var part2: usize = 0;
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |bank| {
        if (bank.len == 0) continue;
        part1 += try joltagePart1(allocator, bank);
        part2 += try joltagePart2(allocator, bank);
    }

    return .{ .part1 = part1, .part2 = part2 };
}

fn joltagePart1(allocator: std.mem.Allocator, bank: []const u8) !usize {
    var joltage_str = try allocator.alloc(u8, 2);
    defer allocator.free(joltage_str);
    const upper = std.mem.indexOfMax(u8, bank[0 .. bank.len - 1]);
    const lower = std.mem.indexOfMax(u8, bank[upper + 1 .. bank.len]);
    joltage_str[0] = bank[upper];
    joltage_str[1] = bank[lower + upper + 1];
    return try std.fmt.parseInt(usize, joltage_str, 10);
}

fn joltagePart2(allocator: std.mem.Allocator, bank: []const u8) !usize {
    const JOLTAGE_LENGTH = 12;
    var joltage_str = try allocator.alloc(u8, JOLTAGE_LENGTH);
    defer allocator.free(joltage_str);

    var prev_index: usize = 0;
    for (0..JOLTAGE_LENGTH) |i| {
        const value = std.mem.indexOfMax(u8, bank[prev_index .. bank.len - (JOLTAGE_LENGTH - i - 1)]);
        joltage_str[i] = bank[value + prev_index];
        prev_index += value + 1;
    }
    return try std.fmt.parseInt(usize, joltage_str, 10);
}

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(357, (try lobby(allocator, input)).part1);
}

test "part 2" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(3121910778619, (try lobby(allocator, input)).part2);
}
