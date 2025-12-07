const std = @import("std");

const Coord = struct { x: usize, y: usize };
const Node = struct { char: u8, futures: usize };
const CoordMap = std.ArrayHashMap(Coord, Node, std.array_hash_map.AutoContext(Coord), true);

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("inputs/day07.txt");
    std.debug.print("Part 1 Answer: {d}\n", .{try part1(allocator, input)});
    std.debug.print("Part 2 Answer: {d}\n", .{try part2(allocator, input)});

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

pub fn printMap(map: CoordMap, max_size: Coord) void {
    for (0..max_size.y) |y| {
        for (0..max_size.x) |x| {
            std.debug.print("{c}", .{(map.get(.{ .x = x, .y = y }).?).char});
        }
        std.debug.print("\n", .{});
    }
}

pub fn tachyonPath(map: *CoordMap, max_size: Coord) !void {
    for (0..max_size.y) |y| {
        for (0..max_size.x) |x| {
            const current_node = map.get(.{ .x = x, .y = y }).?;
            const val = current_node.char;
            if (val == 'S' or val == '|') {
                if (y + 1 >= max_size.y) break;
                const down: Coord = .{ .x = x, .y = y + 1 };
                const val_down = map.get(down).?.char;
                switch (val_down) {
                    '.' => {
                        const new_node: Node = .{ .char = '|', .futures = current_node.futures };
                        try map.put(.{ .x = x, .y = y + 1 }, new_node);
                    },
                    '^' => {
                        const left: Coord = .{ .x = x - 1, .y = y + 1 };
                        const left_node = map.get(left).?;
                        if (left_node.char == '|') {
                            const new_node: Node = .{ .char = '|', .futures = left_node.futures + current_node.futures };
                            try map.put(left, new_node);
                        } else {
                            const new_node: Node = .{ .char = '|', .futures = current_node.futures };
                            try map.put(left, new_node);
                        }

                        const right: Coord = .{ .x = x + 1, .y = y + 1 };
                        const right_node = map.get(right).?;
                        if (right_node.char == '|') {
                            const new_node: Node = .{ .char = '|', .futures = right_node.futures + current_node.futures };
                            try map.put(right, new_node);
                        } else {
                            const new_node: Node = .{ .char = '|', .futures = current_node.futures };
                            try map.put(right, new_node);
                        }
                    },
                    '|' => {
                        const old_node = map.get(down).?;
                        const new_node: Node = .{ .char = '|', .futures = old_node.futures + current_node.futures };
                        try map.put(.{ .x = x, .y = y + 1 }, new_node);
                    },
                    else => {
                        std.debug.print("Unkown case when checking {d},{d}: {c}\n", .{ x, y + 1, val_down });
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

    try tachyonPath(&map, max_size);

    for (0..max_size.y) |y| {
        for (0..max_size.x) |x| {
            const val = map.get(.{ .x = x, .y = y }).?.char;
            if (val == '^') {
                const val_above = map.get(.{ .x = x, .y = y - 1 }).?.char;
                if (val_above == '|') {
                    sum += 1;
                }
            }
        }
    }
    return sum;
}

pub fn part2(allocator: std.mem.Allocator, input: []const u8) !usize {
    var sum: usize = 0;
    var map = CoordMap.init(allocator);
    defer map.deinit();

    const max_size = try mapBuilder(&map, input);
    printMap(map, max_size);

    try tachyonPath(&map, max_size);

    for (0..max_size.x) |x| {
        const node = map.get(.{ .x = x, .y = max_size.y - 1 }).?;
        if (node.char == '|') {
            sum += node.futures;
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

test "part 2" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\nRunning part 2 test...\n", .{});
    try std.testing.expectEqual(40, try part2(allocator, input));
}
