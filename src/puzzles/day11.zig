const std = @import("std");
const aoc = @import("../root.zig");

const Solution = aoc.Solution;

pub fn solve() !void {
    const input = @embedFile("../inputs/day11.txt");
    try aoc.runSolution("Day 03", input, reactor, .{});
}

fn reactor(allocator: std.mem.Allocator, input: []const u8) !Solution {
    var device_map = std.StringHashMap(std.ArrayList([]const u8)).init(allocator);
    defer {
        var iter = device_map.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit(allocator);
        }
        device_map.deinit();
    }

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var outputs: std.ArrayList([]const u8) = .empty;
        var chunks = std.mem.splitAny(u8, line, ": ");
        const device = chunks.next().?;
        while (chunks.next()) |chunk| {
            if (chunk.len == 0) continue;
            try outputs.append(allocator, chunk);
        }
        try device_map.put(device, outputs);
    }

    var memo = std.StringHashMap(usize).init(allocator);
    defer memo.deinit();

    // Calculate all paths from you -> out
    const part1 = try countPaths(allocator, &device_map, "you", "out", &memo);
    memo.clearRetainingCapacity();

    // Calculate segment 1: svr -> fft
    var paths_1 = try countPaths(allocator, &device_map, "svr", "fft", &memo);
    memo.clearRetainingCapacity();

    // Calculate segment 2: fft -> dac
    var paths_2 = try countPaths(allocator, &device_map, "fft", "dac", &memo);
    memo.clearRetainingCapacity();

    // Calculate segment 3: dac -> out
    var paths_3 = try countPaths(allocator, &device_map, "dac", "out", &memo);

    const fft_to_dac_cnt = paths_1 * paths_2 * paths_3;

    // Calculate segment 1: svr -> dac
    paths_1 = try countPaths(allocator, &device_map, "svr", "dac", &memo);
    memo.clearRetainingCapacity();

    // Calculate segment 2: dac -> fft
    paths_2 = try countPaths(allocator, &device_map, "dac", "fft", &memo);
    memo.clearRetainingCapacity();

    // Calculate segment 3: fft -> out
    paths_3 = try countPaths(allocator, &device_map, "fft", "out", &memo);

    const dac_to_fft_cnt = paths_1 * paths_2 * paths_3;

    // Final result
    const part2 = @max(fft_to_dac_cnt, dac_to_fft_cnt);

    return .{ .part1 = part1, .part2 = part2 };
}

fn countPaths(
    allocator: std.mem.Allocator,
    device_map: *std.StringHashMap(std.ArrayList([]const u8)),
    current: []const u8,
    target: []const u8,
    memo: *std.StringHashMap(usize),
) !usize {
    // 1. Check if we reached target
    if (std.mem.eql(u8, current, target)) return 1;

    // 2. Check Cache (Memoization)
    if (memo.get(current)) |cached_count| {
        return cached_count;
    }

    var total_paths: usize = 0;

    // 3. Visit Neighbors
    if (device_map.get(current)) |neighbors| {
        for (neighbors.items) |neighbor| {
            total_paths += try countPaths(allocator, device_map, neighbor, target, memo);
        }
    }

    // 4. Save to Cache
    try memo.put(current, total_paths);
    return total_paths;
}

test "part 1" {
    const input = @embedFile("../inputs/tests/day11_test_case1.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(5, (try reactor(allocator, input)).part1);
}

test "part 2" {
    const input = @embedFile("../inputs/tests/day11_test_case2.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(2, (try reactor(allocator, input)).part2);
}
