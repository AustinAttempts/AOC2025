const std = @import("std");
const aoc = @import("../root.zig");

const EMPTY = '.';
const PATH = '|';
const SPLIT = '^';
const START = 'S';

const Solution = aoc.Solution;

/// Represents a position in the 2D grid
const Coord = struct { x: usize, y: usize };

/// A cell in the laboratory map tracking its character and number of possible futures
const Node = struct {
    char: u8, // The character at this position
    path_count: usize, // Number of timeline branches reaching this cell
};

const CoordMap = std.ArrayHashMap(Coord, Node, std.array_hash_map.AutoContext(Coord), true);

pub fn solve() !void {
    const input = @embedFile("../inputs/day07.txt");
    try aoc.runSolution("Day 07", input, laboratories, .{});
}

/// Solves the laboratory tachyon path puzzle
/// Returns solutions for both parts of the challenge
fn laboratories(allocator: std.mem.Allocator, input: []const u8) !Solution {
    var map = CoordMap.init(allocator);
    defer map.deinit();

    const dimensions = try buildMap(&map, input);

    try propagatePaths(&map, dimensions);

    const part1 = countSplitPoints(&map, dimensions);
    const part2 = countBottomRowPaths(&map, dimensions);

    return Solution{ .part1 = part1, .part2 = part2 };
}

/// Builds the initial map from input text
/// Returns the dimensions of the grid
fn buildMap(map: *CoordMap, input: []const u8) !Coord {
    var dimensions: Coord = .{ .x = 0, .y = 0 };
    var current_pos: Coord = .{ .x = 0, .y = 0 };
    var lines = std.mem.splitScalar(u8, input, '\n');

    while (lines.next()) |line| {
        current_pos.x = 0;
        while (current_pos.x < line.len) {
            const cell_char = line[current_pos.x];
            const node = Node{
                .char = cell_char,
                .path_count = if (cell_char == START) 1 else 0,
            };
            try map.put(current_pos, node);
            current_pos.x += 1;
        }
        current_pos.y += 1;
    }

    dimensions = .{ .x = current_pos.x, .y = current_pos.y };
    return dimensions;
}

/// Updates a cell with additional path counts
fn updateCell(map: *CoordMap, coord: Coord, additional_paths: usize) !void {
    const existing = map.get(coord).?;

    const new_node: Node = if (existing.char == PATH)
        .{ .char = PATH, .path_count = existing.path_count + additional_paths }
    else
        .{ .char = PATH, .path_count = additional_paths };

    try map.put(coord, new_node);
}

/// Handles updating cells when a path splits
fn handleSplit(map: *CoordMap, x: usize, y: usize, current_paths: usize) !void {
    const left_coord: Coord = .{ .x = x - 1, .y = y };
    try updateCell(map, left_coord, current_paths);

    const right_coord: Coord = .{ .x = x + 1, .y = y };
    try updateCell(map, right_coord, current_paths);
}

/// Propagates tachyon paths through the grid
/// Modifies the map in-place by marking paths and counting timeline branches
fn propagatePaths(map: *CoordMap, dimensions: Coord) !void {
    for (0..dimensions.y) |y| {
        for (0..dimensions.x) |x| {
            const current_node = map.get(.{ .x = x, .y = y }).?;
            const current_char = current_node.char;

            // Only process cells that have paths
            if (current_char != START and current_char != PATH) continue;

            // Check if we're at the bottom edge
            if (y + 1 >= dimensions.y) continue;

            const down_coord: Coord = .{ .x = x, .y = y + 1 };
            const down_node = map.get(down_coord).?;

            switch (down_node.char) {
                EMPTY => {
                    // Mark empty cell as part of path
                    const new_node: Node = .{ .char = PATH, .path_count = current_node.path_count };
                    try map.put(down_coord, new_node);
                },
                SPLIT => {
                    // Split path goes left and right
                    try handleSplit(map, x, y + 1, current_node.path_count);
                },
                PATH => {
                    // Merge with existing path
                    try updateCell(map, down_coord, current_node.path_count);
                },
                else => {
                    // Unknown cell type - this shouldn't happen with valid input
                    std.debug.print("Unknown cell type at {d},{d}: {c}\n", .{ x, y + 1, down_node.char });
                    return error.UnknownCellType;
                },
            }
        }
    }
}

/// Counts the number of split points ('^' with '|' above)
fn countSplitPoints(map: *const CoordMap, dimensions: Coord) usize {
    var count: usize = 0;

    for (0..dimensions.y) |y| {
        for (0..dimensions.x) |x| {
            const cell_char = map.get(.{ .x = x, .y = y }).?.char;

            if (cell_char == SPLIT and y > 0) {
                const cell_above = map.get(.{ .x = x, .y = y - 1 }).?.char;
                if (cell_above == PATH) {
                    count += 1;
                }
            }
        }
    }

    return count;
}

/// Counts the total number of paths reaching the bottom row
fn countBottomRowPaths(map: *const CoordMap, dimensions: Coord) usize {
    var total: usize = 0;

    for (0..dimensions.x) |x| {
        const node = map.get(.{ .x = x, .y = dimensions.y - 1 }).?;
        if (node.char == PATH) {
            total += node.path_count;
        }
    }

    return total;
}

test "part 1" {
    const input = @embedFile("../inputs/tests/day07_test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(21, (try laboratories(allocator, input)).part1);
}

test "part 2" {
    const input = @embedFile("../inputs/tests/day07_test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(40, (try laboratories(allocator, input)).part2);
}
