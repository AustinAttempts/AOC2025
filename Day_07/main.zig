const std = @import("std");

const Solution = struct {
    part1: usize,
    part2: usize,
};
const Coord = struct { x: usize, y: usize };
const Node = struct { char: u8, futures: usize };
const CoordMap = std.ArrayHashMap(Coord, Node, std.array_hash_map.AutoContext(Coord), true);

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("inputs/day07.txt");
    const solution = try laboratories(allocator, input);
    std.debug.print("Part 1 Answer: {d}\n", .{solution.part1});
    std.debug.print("Part 2 Answer: {d}\n", .{solution.part2});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

fn laboratories(allocator: std.mem.Allocator, input: []const u8) !Solution {
    var map = CoordMap.init(allocator);
    defer map.deinit();

    const max_size = try mapBuilder(&map, input);

    try tachyonPath(&map, max_size);

    var part1: usize = 0;
    for (0..max_size.y) |y| {
        for (0..max_size.x) |x| {
            const val = map.get(.{ .x = x, .y = y }).?.char;
            if (val == '^') {
                const val_above = map.get(.{ .x = x, .y = y - 1 }).?.char;
                if (val_above == '|') {
                    part1 += 1;
                }
            }
        }
    }

    var part2: usize = 0;
    for (0..max_size.x) |x| {
        const node = map.get(.{ .x = x, .y = max_size.y - 1 }).?;
        if (node.char == '|') {
            part2 += node.futures;
        }
    }

    return Solution{ .part1 = part1, .part2 = part2 };
}

fn mapBuilder(map: *CoordMap, input: []const u8) !Coord {
    var max_size: Coord = .{ .x = 0, .y = 0 };
    var current_pos: Coord = .{ .x = 0, .y = 0 };
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        current_pos.x = 0;
        while (current_pos.x < line.len) {
            const node: Node = if (line[current_pos.x] == 'S')
                .{ .char = 'S', .futures = 1 }
            else
                .{ .char = line[current_pos.x], .futures = 0 };
            try map.put(current_pos, node);
            current_pos.x += 1;
        }
        current_pos.y += 1;
    }
    max_size = .{ .x = current_pos.x, .y = current_pos.y };
    return max_size;
}

fn updateCell(map: *CoordMap, coord: Coord, current_futures: usize) !void {
    const existing = map.get(coord).?;

    const new_node: Node = if (existing.char == '|')
        .{ .char = '|', .futures = existing.futures + current_futures }
    else
        .{ .char = '|', .futures = current_futures };

    try map.put(coord, new_node);
}

fn tachyonPath(map: *CoordMap, max_size: Coord) !void {
    for (0..max_size.y) |y| {
        for (0..max_size.x) |x| {
            const current_node = map.get(.{ .x = x, .y = y }).?;
            const val = current_node.char;
            if (val == 'S' or val == '|') {
                if (y + 1 >= max_size.y) break;
                const down_coord: Coord = .{ .x = x, .y = y + 1 };
                const down_node = map.get(down_coord).?;
                switch (down_node.char) {
                    '.' => {
                        const new_node: Node = .{ .char = '|', .futures = current_node.futures };
                        try map.put(.{ .x = x, .y = y + 1 }, new_node);
                    },
                    '^' => {
                        const left_coord: Coord = .{ .x = x - 1, .y = y + 1 };
                        try updateCell(map, left_coord, current_node.futures);

                        const right_coord: Coord = .{ .x = x + 1, .y = y + 1 };
                        try updateCell(map, right_coord, current_node.futures);
                    },
                    '|' => {
                        try updateCell(map, down_coord, current_node.futures);
                    },
                    else => {
                        std.debug.print("Unkown case when checking {d},{d}: {c}\n", .{ x, y + 1, down_node.char });
                        break;
                    },
                }
            }
        }
    }
}

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(21, (try laboratories(allocator, input)).part1);
}

test "part 2" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(40, (try laboratories(allocator, input)).part2);
}
