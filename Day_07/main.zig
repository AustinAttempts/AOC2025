const std = @import("std");

const Coord = struct { x: usize, y: usize };
const CoordMap = std.ArrayHashMap(Coord, u8, std.array_hash_map.AutoContext(Coord), true);

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("inputs/day07.txt");
    std.debug.print("Part 1 Answer: {d}\n", .{try part1(allocator, input)});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

pub fn mapBuilder(map: *CoordMap, input: []const u8) !Coord {
    var max_size: Coord = .{ .x = 0, .y = 0 };
    var current_pos: Coord = .{ .x = 0, .y = 0 };
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        current_pos.x = 0;
        while (current_pos.x < line.len) {
            try map.put(current_pos, line[current_pos.x]);
            current_pos.x += 1;
        }
        current_pos.y += 1;
    }
    max_size = .{ .x = current_pos.x, .y = current_pos.y };
    return max_size;
}

pub fn printMap(map: CoordMap, max_size: Coord) void {
    for (0..max_size.y) |y| {
        for (0..max_size.x) |x| {
            std.debug.print("{c}", .{map.get(.{ .x = x, .y = y }) orelse '?'});
        }
        std.debug.print("\n", .{});
    }
}

pub fn tachyonPath1(map: *CoordMap, max_size: Coord) !void {
    for (0..max_size.y) |y| {
        for (0..max_size.x) |x| {
            const val = map.get(.{ .x = x, .y = y }) orelse '?';
            if (val == 'S' or val == '|') {
                if (y + 1 >= max_size.y) break;
                const val_drop = map.get(.{ .x = x, .y = y + 1 }) orelse '?';
                switch (val_drop) {
                    '.' => {
                        try map.put(.{ .x = x, .y = y + 1 }, '|');
                    },
                    '^' => {
                        try map.put(.{ .x = x + 1, .y = y + 1 }, '|');
                        try map.put(.{ .x = x - 1, .y = y + 1 }, '|');
                    },
                    '|' => {
                        // Do Nothing
                    },
                    else => {
                        std.debug.print("Unkown case when checking {d},{d}: {c}\n", .{ x, y + 1, val_drop });
                        break;
                    },
                }
            }
        }
        printMap(map.*, max_size);
    }
}

pub fn part1(allocator: std.mem.Allocator, input: []const u8) !usize {
    var sum: usize = 0;
    var map = CoordMap.init(allocator);
    defer map.deinit();

    const max_size = try mapBuilder(&map, input);
    printMap(map, max_size);

    try tachyonPath1(&map, max_size);

    for (0..max_size.y) |y| {
        for (0..max_size.x) |x| {
            const val = map.get(.{ .x = x, .y = y }) orelse '?';
            if (val == '^') {
                const val_above = map.get(.{ .x = x, .y = y - 1 }) orelse '?';
                if (val_above == '|') {
                    sum += 1;
                }
            }
        }
    }
    return sum;
}

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\nRunning part 1 test...\n", .{});
    try std.testing.expectEqual(21, try part1(allocator, input));
}
