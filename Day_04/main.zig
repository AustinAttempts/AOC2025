const std = @import("std");

const Solution = struct {
    part1: usize,
    part2: usize,
};

const Coord = struct {
    x: usize,
    y: usize,

    fn isValid(self: Coord, max: Coord) bool {
        return self.x < max.x and self.y < max.y;
    }
};

const CoordMap = std.ArrayHashMap(Coord, u8, std.array_hash_map.AutoContext(Coord), true);

const ROLL = '@';
const EMPTY = '.';
const REMOVED = 'X';
const NEIGHBOR_THRESHOLD = 4;

const DIRECTIONS = [8][2]i32{
    .{ -1, 0 }, // left
    .{ 1, 0 }, // right
    .{ 0, -1 }, // up
    .{ 0, 1 }, // down
    .{ -1, -1 }, // top-left
    .{ 1, -1 }, // top-right
    .{ -1, 1 }, // bottom-left
    .{ 1, 1 }, // bottom-right
};

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("inputs/day04.txt");
    const solution = try printingDepartment(allocator, input);
    std.debug.print("Part 1 Answer: {d}\n", .{solution.part1});
    std.debug.print("Part 2 Answer: {d}\n", .{solution.part2});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

fn printingDepartment(allocator: std.mem.Allocator, input: []const u8) !Solution {
    var map = CoordMap.init(allocator);
    defer map.deinit();

    const max_size = try buildMap(&map, input);
    const part1 = try removeRolls(allocator, &map, max_size);

    var part2: usize = 0;
    var rolls_removed = part1;
    while (rolls_removed > 0) {
        part2 += rolls_removed;
        rolls_removed = try removeRolls(allocator, &map, max_size);
    }
    return .{ .part1 = part1, .part2 = part2 };
}

fn buildMap(map: *CoordMap, input: []const u8) !Coord {
    var y: usize = 0;
    var max_x: usize = 0;

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        for (line, 0..) |char, x| {
            try map.put(.{ .x = x, .y = y }, char);
        }

        max_x = @max(max_x, line.len);
        y += 1;
    }

    return .{ .x = max_x, .y = y };
}

fn removeRolls(allocator: std.mem.Allocator, map: *CoordMap, max_size: Coord) !usize {
    // First pass: convert previously removed rolls to empty spaces
    replaceInMap(map, REMOVED, EMPTY);

    // Second pass: identify and mark rolls to remove
    var to_remove: std.ArrayList(Coord) = .empty;
    defer to_remove.deinit(allocator);

    for (0..max_size.y) |y| {
        for (0..max_size.x) |x| {
            const pos = Coord{ .x = x, .y = y };
            if (map.get(pos) == ROLL and countNeighbors(map, pos, max_size) < NEIGHBOR_THRESHOLD) {
                try to_remove.append(allocator, pos);
            }
        }
    }

    // Third pass: mark all identified rolls as removed
    for (to_remove.items) |pos| {
        try map.put(pos, REMOVED);
    }

    return to_remove.items.len;
}

fn countNeighbors(map: *const CoordMap, pos: Coord, max_size: Coord) usize {
    var count: usize = 0;

    for (DIRECTIONS) |dir| {
        const nx = @as(i32, @intCast(pos.x)) + dir[0];
        const ny = @as(i32, @intCast(pos.y)) + dir[1];

        if (nx < 0 or ny < 0) continue;

        const neighbor = Coord{ .x = @intCast(nx), .y = @intCast(ny) };
        if (!neighbor.isValid(max_size)) continue;

        if (map.get(neighbor)) |cell| {
            if (cell != EMPTY) count += 1;
        }
    }

    return count;
}

fn replaceInMap(map: *CoordMap, old: u8, new: u8) void {
    var it = map.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.* == old) {
            entry.value_ptr.* = new;
        }
    }
}

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(13, (try printingDepartment(allocator, input)).part1);
}

test "map builder" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = CoordMap.init(allocator);
    defer map.deinit();

    const max_size = try buildMap(&map, input);
    try std.testing.expectEqual(10, max_size.x);
    try std.testing.expectEqual(10, max_size.y);
}

test "part 2" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(43, (try printingDepartment(allocator, input)).part2);
}

test "Coord.isValid" {
    const max_size = Coord{ .x = 10, .y = 10 };

    // Valid coordinates
    try std.testing.expect((Coord{ .x = 0, .y = 0 }).isValid(max_size));
    try std.testing.expect((Coord{ .x = 5, .y = 5 }).isValid(max_size));
    try std.testing.expect((Coord{ .x = 9, .y = 9 }).isValid(max_size));

    // Invalid coordinates (at or beyond boundaries)
    try std.testing.expect(!(Coord{ .x = 10, .y = 0 }).isValid(max_size));
    try std.testing.expect(!(Coord{ .x = 0, .y = 10 }).isValid(max_size));
    try std.testing.expect(!(Coord{ .x = 10, .y = 10 }).isValid(max_size));
    try std.testing.expect(!(Coord{ .x = 15, .y = 15 }).isValid(max_size));
}

test "countNeighbors" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = CoordMap.init(allocator);
    defer map.deinit();

    // Create a simple 3x3 grid with a roll in the center
    // @ @ @
    // @ @ @
    // @ @ @
    for (0..3) |y| {
        for (0..3) |x| {
            try map.put(.{ .x = x, .y = y }, ROLL);
        }
    }

    const max_size = Coord{ .x = 3, .y = 3 };

    // Center position has 8 neighbors
    try std.testing.expectEqual(8, countNeighbors(&map, .{ .x = 1, .y = 1 }, max_size));

    // Corner positions have 3 neighbors
    try std.testing.expectEqual(3, countNeighbors(&map, .{ .x = 0, .y = 0 }, max_size));
    try std.testing.expectEqual(3, countNeighbors(&map, .{ .x = 2, .y = 2 }, max_size));

    // Edge positions have 5 neighbors
    try std.testing.expectEqual(5, countNeighbors(&map, .{ .x = 1, .y = 0 }, max_size));
    try std.testing.expectEqual(5, countNeighbors(&map, .{ .x = 0, .y = 1 }, max_size));
}

test "countNeighbors with empty spaces" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = CoordMap.init(allocator);
    defer map.deinit();

    // Create a grid with some empty spaces
    // @ . @
    // . @ .
    // @ . @
    try map.put(.{ .x = 0, .y = 0 }, ROLL);
    try map.put(.{ .x = 1, .y = 0 }, EMPTY);
    try map.put(.{ .x = 2, .y = 0 }, ROLL);

    try map.put(.{ .x = 0, .y = 1 }, EMPTY);
    try map.put(.{ .x = 1, .y = 1 }, ROLL);
    try map.put(.{ .x = 2, .y = 1 }, EMPTY);

    try map.put(.{ .x = 0, .y = 2 }, ROLL);
    try map.put(.{ .x = 1, .y = 2 }, EMPTY);
    try map.put(.{ .x = 2, .y = 2 }, ROLL);

    const max_size = Coord{ .x = 3, .y = 3 };

    // Center roll should have 4 neighbors (corners only)
    try std.testing.expectEqual(4, countNeighbors(&map, .{ .x = 1, .y = 1 }, max_size));

    // Corner rolls should have 1 neighbor each
    try std.testing.expectEqual(1, countNeighbors(&map, .{ .x = 0, .y = 0 }, max_size));
}

test "replaceInMap" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = CoordMap.init(allocator);
    defer map.deinit();

    // Create a map with various cell types
    try map.put(.{ .x = 0, .y = 0 }, ROLL);
    try map.put(.{ .x = 1, .y = 0 }, REMOVED);
    try map.put(.{ .x = 2, .y = 0 }, EMPTY);
    try map.put(.{ .x = 3, .y = 0 }, REMOVED);

    // Replace all REMOVED with EMPTY
    replaceInMap(&map, REMOVED, EMPTY);

    try std.testing.expectEqual(ROLL, map.get(.{ .x = 0, .y = 0 }).?);
    try std.testing.expectEqual(EMPTY, map.get(.{ .x = 1, .y = 0 }).?);
    try std.testing.expectEqual(EMPTY, map.get(.{ .x = 2, .y = 0 }).?);
    try std.testing.expectEqual(EMPTY, map.get(.{ .x = 3, .y = 0 }).?);
}

test "removeRolls single iteration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = CoordMap.init(allocator);
    defer map.deinit();

    // Create a pattern where isolated rolls have < 4 neighbors
    // @ @ @ @ @
    // @ @ @ @ @
    // . . . . .
    // @ . . . @
    for (0..2) |y| {
        for (0..5) |x| {
            try map.put(.{ .x = x, .y = y }, ROLL);
        }
    }
    for (0..5) |x| {
        try map.put(.{ .x = x, .y = 2 }, EMPTY);
    }
    // Add isolated corners that will have < 4 neighbors
    try map.put(.{ .x = 0, .y = 3 }, ROLL);
    try map.put(.{ .x = 4, .y = 3 }, ROLL);

    const max_size = Coord{ .x = 5, .y = 4 };
    const removed = try removeRolls(allocator, &map, max_size);

    // Bottom row of rolls (y=1) should be removed (< 4 neighbors after considering empty row below)
    // Plus the two isolated corners
    try std.testing.expect(removed > 0);

    // Verify at least some specific cells are marked as removed
    // The isolated corners definitely should be removed (only 1-2 neighbors)
    try std.testing.expectEqual(REMOVED, map.get(.{ .x = 0, .y = 3 }).?);
    try std.testing.expectEqual(REMOVED, map.get(.{ .x = 4, .y = 3 }).?);
}

test "buildMap with empty lines" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = CoordMap.init(allocator);
    defer map.deinit();

    const input = "@@\n\n..\n";
    const max_size = try buildMap(&map, input);

    // Should skip empty line and build correctly
    try std.testing.expectEqual(2, max_size.x);
    try std.testing.expectEqual(2, max_size.y);
    try std.testing.expectEqual(ROLL, map.get(.{ .x = 0, .y = 0 }).?);
    try std.testing.expectEqual(EMPTY, map.get(.{ .x = 0, .y = 1 }).?);
}

test "buildMap calculates correct max dimensions" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = CoordMap.init(allocator);
    defer map.deinit();

    // Variable width lines
    const input = "@@\n@@@@\n@@\n";
    const max_size = try buildMap(&map, input);

    try std.testing.expectEqual(4, max_size.x); // Max width is 4
    try std.testing.expectEqual(3, max_size.y); // 3 lines
}
