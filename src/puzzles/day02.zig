const std = @import("std");
const aoc = @import("../root.zig");

const Solution = aoc.Solution;

pub fn solve() !void {
    const input = @embedFile("../inputs/day02.txt");
    try aoc.runSolution("Day 02", input, giftShop, .{});
}

fn giftShop(allocator: std.mem.Allocator, input: []const u8) !Solution {
    _ = allocator;
    var part1: usize = 0;
    var part2: usize = 0;
    var buf: [32]u8 = undefined;

    var id_ranges = std.mem.splitScalar(u8, input, ',');
    while (id_ranges.next()) |id_range| {
        if (id_range.len == 0) continue;
        var bounds = std.mem.splitScalar(u8, id_range, '-');
        const start_id = try std.fmt.parseInt(usize, bounds.next().?, 10);
        const end_id = try std.fmt.parseInt(usize, bounds.next().?, 10);

        for (start_id..end_id + 1) |id| {
            const id_str = try std.fmt.bufPrint(&buf, "{d}", .{id});
            if (isBadIdPart1(id_str)) {
                part1 += id;
            }
            if (isBadIdPart2(id_str)) {
                part2 += id;
            }
        }
    }

    return .{ .part1 = part1, .part2 = part2 };
}

/// Checks if an ID is "bad" for Part 1: the first half equals the second half
fn isBadIdPart1(id: []const u8) bool {
    const len = id.len;
    if (len % 2 != 0) return false; // Odd length can't have equal halves

    const mid = len / 2;
    const first_half = id[0..mid];
    const second_half = id[mid..len];

    if (std.mem.eql(u8, first_half, second_half)) {
        return true;
    }

    return false;
}

/// Checks if an ID is "bad" for Part 2: the ID consists of a repeated pattern
fn isBadIdPart2(id: []const u8) bool {
    const len = id.len;
    if (len == 1) return false; // Single digit can't be a repeated pattern

    // Try all possible pattern lengths (divisors of len)
    var pattern_len: usize = 1;
    while (pattern_len <= len / 2) : (pattern_len += 1) {
        if (len % pattern_len != 0) continue;

        const pattern = id[0..pattern_len];
        var pos: usize = pattern_len;
        var is_repeated = true;

        while (pos < len) : (pos += pattern_len) {
            if (!std.mem.eql(u8, pattern, id[pos .. pos + pattern_len])) {
                is_repeated = false;
                break;
            }
        }

        if (is_repeated) return true;
    }
    return false;
}

test "Part 1 bad ID detection" {
    try std.testing.expect(isBadIdPart1("55"));
    try std.testing.expect(isBadIdPart1("6464"));
    try std.testing.expect(isBadIdPart1("123123"));
    try std.testing.expect(!isBadIdPart1("101"));
    try std.testing.expect(!isBadIdPart1("5"));
    try std.testing.expect(!isBadIdPart1("12345"));
}

test "part 1" {
    const input = @embedFile("../inputs/tests/day02_test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    try std.testing.expectEqual(1227775554, (try giftShop(allocator, input)).part1);
}

test "Part 2 bad ID detection" {
    try std.testing.expect(isBadIdPart2("12341234"));
    try std.testing.expect(isBadIdPart2("123123123"));
    try std.testing.expect(isBadIdPart2("1212121212"));
    try std.testing.expect(isBadIdPart2("1111111"));
    try std.testing.expect(isBadIdPart2("55"));
    try std.testing.expect(isBadIdPart2("6464"));
    try std.testing.expect(isBadIdPart2("123123"));
    try std.testing.expect(!isBadIdPart2("101"));
    try std.testing.expect(!isBadIdPart2("5"));
    try std.testing.expect(!isBadIdPart2("12345"));
}

test "part 2" {
    const input = @embedFile("../inputs/tests/day02_test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    try std.testing.expectEqual(4174379265, (try giftShop(allocator, input)).part2);
}
