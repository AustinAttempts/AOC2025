const std = @import("std");

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("inputs/day11.txt");
    std.debug.print("Part 1 Answer: {d}\n", .{try part1(allocator, input)});
    std.debug.print("Part 2 Answer: {d}\n", .{try part2(allocator, input)});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

fn dfs(
    allocator: std.mem.Allocator,
    device_map: *std.StringHashMap(std.ArrayList([]const u8)),
    current: []const u8,
    target: []const u8,
    path: *std.ArrayList([]const u8),
    visited: *std.StringHashMap(void),
    all_paths: *std.ArrayList(std.ArrayList([]const u8)),
) !void {
    // Add current node to path
    try path.append(allocator, current);
    defer _ = path.pop();

    // Mark as visited
    try visited.put(current, {});
    defer _ = visited.remove(current);

    // If we reached the target, save this path
    if (std.mem.eql(u8, current, target)) {
        var path_copy: std.ArrayList([]const u8) = .empty;
        try path_copy.appendSlice(allocator, path.items);
        try all_paths.append(allocator, path_copy);
        return;
    }

    // Get neighbors of current node
    if (device_map.get(current)) |neighbors| {
        for (neighbors.items) |neighbor| {
            // Only visit if not already in current path (avoid cycles)
            if (!visited.contains(neighbor)) {
                try dfs(allocator, device_map, neighbor, target, path, visited, all_paths);
            }
        }
    }
}

fn part1(allocator: std.mem.Allocator, input: []const u8) !usize {
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
        std.debug.print("Device: {s} --> ", .{device});
        while (chunks.next()) |chunk| {
            if (chunk.len == 0) continue;
            std.debug.print("{s} ", .{chunk});
            try outputs.append(allocator, chunk);
        }
        std.debug.print("\n", .{});
        try device_map.put(device, outputs);
    }

    // DFS to find all paths from "you" to "out"
    var all_paths: std.ArrayList(std.ArrayList([]const u8)) = .empty;
    defer {
        for (all_paths.items) |*path| {
            path.deinit(allocator);
        }
        all_paths.deinit(allocator);
    }

    var current_path: std.ArrayList([]const u8) = .empty;
    defer current_path.deinit(allocator);

    var visited = std.StringHashMap(void).init(allocator);
    defer visited.deinit();

    try dfs(allocator, &device_map, "you", "out", &current_path, &visited, &all_paths);

    // Print all paths found
    std.debug.print("\nFound {d} paths:\n", .{all_paths.items.len});
    for (all_paths.items, 0..) |path, i| {
        std.debug.print("Path {d}: ", .{i + 1});
        for (path.items, 0..) |node, j| {
            std.debug.print("{s}", .{node});
            if (j < path.items.len - 1) std.debug.print(" -> ", .{});
        }
        std.debug.print("\n", .{});
    }

    return all_paths.items.len;
}

fn countPaths(
    allocator: std.mem.Allocator,
    device_map: *std.StringHashMap(std.ArrayList([]const u8)),
    current: []const u8,
    target: []const u8,
    // Cache maps "current_node_name" -> "count_of_paths_to_target"
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
            // NOTE: This assumes a DAG (Directed Acyclic Graph).
            // If your graph has cycles, simple memoization requires more complex state
            // (e.g. tracking visited bits in the key), but AOC problems like this
            // usually imply a flow/DAG structure for Part 2.
            total_paths += try countPaths(allocator, device_map, neighbor, target, memo);
        }
    }

    // 4. Save to Cache
    try memo.put(current, total_paths);
    return total_paths;
}

fn part2(allocator: std.mem.Allocator, input: []const u8) !usize {
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
        std.debug.print("Device: {s} --> ", .{device});
        while (chunks.next()) |chunk| {
            if (chunk.len == 0) continue;
            std.debug.print("{s} ", .{chunk});
            try outputs.append(allocator, chunk);
        }
        std.debug.print("\n", .{});
        try device_map.put(device, outputs);
    }

    var memo = std.StringHashMap(usize).init(allocator);
    defer memo.deinit();

    // Calculate segment 1: svr -> fft
    const paths_1 = try countPaths(allocator, &device_map, "svr", "fft", &memo);
    memo.clearRetainingCapacity(); // Clear cache between distinct searches

    // Calculate segment 2: fft -> dac
    const paths_2 = try countPaths(allocator, &device_map, "fft", "dac", &memo);
    memo.clearRetainingCapacity();

    // Calculate segment 3: dac -> out
    const paths_3 = try countPaths(allocator, &device_map, "dac", "out", &memo);

    // Final result
    return paths_1 * paths_2 * paths_3;
}

test "part 1" {
    const input = @embedFile("inputs/test_case1.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\nRunning part 1 test...\n", .{});
    try std.testing.expectEqual(5, try part1(allocator, input));
}

test "part 2" {
    const input = @embedFile("inputs/test_case2.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\nRunning part 2 test...\n", .{});
    try std.testing.expectEqual(2, try part2(allocator, input));
}
