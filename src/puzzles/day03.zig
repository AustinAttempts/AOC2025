const std = @import("std");
const aoc = @import("../root.zig");

const Solution = aoc.Solution;

pub fn solve() !void {
    var timer = try std.time.Timer.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const input = @embedFile("../inputs/day03.txt");
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
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        part1 += try joltagePart1(line);
        part2 += try joltagePart2(allocator, line);
    }

    return .{ .part1 = part1, .part2 = part2 };
}

/// Finds the two largest digit characters and concatenates them
fn joltagePart1(line: []const u8) !usize {
    if (line.len < 2) return error.InvalidInput;

    // Find first maximum in the line (excluding last char)
    const first_max_idx = std.mem.indexOfMax(u8, line[0 .. line.len - 1]);

    // Find second maximum in remaining portion
    const second_max_idx = std.mem.indexOfMax(u8, line[first_max_idx + 1 ..]);

    // Build 2-digit number
    const result = [2]u8{ line[first_max_idx], line[second_max_idx + first_max_idx + 1] };

    return try std.fmt.parseInt(usize, &result, 10);
}

/// Finds the 12 largest digit characters sequentially and concatenates them
fn joltagePart2(allocator: std.mem.Allocator, line: []const u8) !usize {
    const DIGIT_COUNT = 12;
    if (line.len < DIGIT_COUNT) return error.InvalidInput;

    var result_str = try allocator.alloc(u8, DIGIT_COUNT);
    defer allocator.free(result_str);

    var start_idx: usize = 0;
    for (0..DIGIT_COUNT) |i| {
        // Search space shrinks from the end as we find more digits
        const search_end = line.len - (DIGIT_COUNT - i - 1);
        const max_idx = std.mem.indexOfMax(u8, line[start_idx..search_end]);

        result_str[i] = line[start_idx + max_idx];
        start_idx += max_idx + 1;
    }

    return try std.fmt.parseInt(usize, result_str, 10);
}

test "part 1" {
    const input = @embedFile("../inputs/tests/day03_test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(357, (try lobby(allocator, input)).part1);
}

test "part 2" {
    const input = @embedFile("../inputs/tests/day03_test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(3121910778619, (try lobby(allocator, input)).part2);
}
