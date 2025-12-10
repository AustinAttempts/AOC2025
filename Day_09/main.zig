const std = @import("std");

const Coord = struct { x: usize, y: usize };

const Rect = struct {
    a: Coord,
    b: Coord,
    width: usize,
    height: usize,
    area: usize,

    fn init(a: Coord, b: Coord) Rect {
        const width = @abs(@as(isize, @intCast(a.x)) - @as(isize, @intCast(b.x))) + 1;
        const height = @abs(@as(isize, @intCast(a.y)) - @as(isize, @intCast(b.y))) + 1;
        const area = width * height;
        return .{ .a = a, .b = b, .width = width, .height = height, .area = area };
    }

    fn valid_rect(self: *Rect, coord_set: std.AutoHashMap(Coord, u8), max_x: usize, cache: *std.AutoHashMap(Coord, bool)) !bool {
        const min_x = @min(self.a.x, self.b.x);
        const max_x_rect = @max(self.a.x, self.b.x);
        const min_y = @min(self.a.y, self.b.y);
        const max_y = @max(self.a.y, self.b.y);

        // Check top and bottom edges
        if (min_x + 1 < max_x_rect) {
            for (min_x..max_x_rect + 1) |x| {
                if (!try isInsideOrOnBoundaryCached(.{ .x = x, .y = min_y }, coord_set, max_x, cache)) return false;
                if (!try isInsideOrOnBoundaryCached(.{ .x = x, .y = max_y }, coord_set, max_x, cache)) return false;
            }
        }

        // Check left and right edges
        if (min_y + 1 < max_y) {
            for (min_y + 1..max_y) |y| {
                if (!try isInsideOrOnBoundaryCached(.{ .x = min_x, .y = y }, coord_set, max_x, cache)) return false;
                if (!try isInsideOrOnBoundaryCached(.{ .x = max_x_rect, .y = y }, coord_set, max_x, cache)) return false;
            }
        }
        return true;
    }
};

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("inputs/day09.txt");
    std.debug.print("Part 1 Answer: {d}\n", .{try part1(allocator, input)});
    std.debug.print("Part 2 Answer: {d}\n", .{try part2(allocator, input)});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

fn compareByX(context: void, a: Coord, b: Coord) bool {
    _ = context;
    return a.x < b.x;
}

fn compareByY(context: void, a: Coord, b: Coord) bool {
    _ = context;
    return a.y < b.y;
}

fn isInside(coord: Coord, coord_set: std.AutoHashMap(Coord, u8), max_x: usize) bool {
    var crossings: usize = 0;

    // Cast ray to the right from this point, count perimeter crossings
    var x = coord.x + 1;
    while (x <= max_x) : (x += 1) {
        const val = coord_set.get(.{ .x = x, .y = coord.y }) orelse continue;
        if (val == '#' or val == 'X') {
            crossings += 1;
        }
    }

    // Odd number of crossings = inside, even = outside
    return crossings % 2 == 1;
}

fn isInsideOrOnBoundaryCached(coord: Coord, coord_set: std.AutoHashMap(Coord, u8), max_x: usize, cache: *std.AutoHashMap(Coord, bool)) !bool {
    // If on the perimeter, it's valid
    if (coord_set.get(coord)) |val| {
        if (val == '#' or val == 'X') return true;
    }

    // Check cache first
    if (cache.get(coord)) |result| {
        return result;
    }

    // Calculate and cache result
    const result = isInside(coord, coord_set, max_x);
    try cache.put(coord, result);
    return result;
}

fn printMap(coord_set: *std.AutoHashMap(Coord, u8), min_y: usize, max_y: usize, min_x: usize, max_x: usize) !void {
    for (min_y..max_y + 1) |y| {
        for (min_x..max_x + 1) |x| {
            if (!coord_set.contains(.{ .x = x, .y = y })) {
                try coord_set.put(.{ .x = x, .y = y }, '.');
            }
            std.debug.print("{c}", .{coord_set.get(.{ .x = x, .y = y }).?});
        }
        std.debug.print("\n", .{});
    }
}

fn part1(allocator: std.mem.Allocator, input: []const u8) !usize {
    var coords: std.ArrayList(Coord) = .empty;
    defer _ = coords.deinit(allocator);

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var values = std.mem.splitScalar(u8, line, ',');
        const x = try std.fmt.parseInt(usize, values.next().?, 10);
        const y = try std.fmt.parseInt(usize, values.next().?, 10);

        const coord: Coord = .{ .x = x, .y = y };
        try coords.append(allocator, coord);
    }

    var rectangles: std.ArrayList(Rect) = .empty;
    defer _ = rectangles.deinit(allocator);

    var max_area: usize = 0;
    for (coords.items, 0..) |start, i| {
        for (coords.items[i + 1 ..]) |end| {
            const rect = Rect.init(start, end);
            try rectangles.append(allocator, rect);
            std.debug.print("({d},{d}) - ({d},{d}) --> {d}\n", .{ rect.a.x, rect.a.y, rect.b.x, rect.b.y, rect.area });
            if (rect.area > max_area) {
                max_area = rect.area;
            }
        }
    }

    return max_area;
}

fn part2(allocator: std.mem.Allocator, input: []const u8) !usize {
    var coords: std.ArrayList(Coord) = .empty;
    defer _ = coords.deinit(allocator);

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var values = std.mem.splitScalar(u8, line, ',');
        const x = try std.fmt.parseInt(usize, values.next().?, 10);
        const y = try std.fmt.parseInt(usize, values.next().?, 10);

        const coord: Coord = .{ .x = x, .y = y };
        try coords.append(allocator, coord);
    }

    // Find min values
    var min_x: usize = std.math.maxInt(usize);
    var min_y: usize = std.math.maxInt(usize);
    for (coords.items) |coord| {
        min_x = @min(min_x, coord.x);
        min_y = @min(min_y, coord.y);
    }

    // Normalize all coordinates
    for (coords.items) |*coord| {
        coord.x -= min_x;
        coord.y -= min_y;
    }

    var coord_set = std.AutoHashMap(Coord, u8).init(allocator);
    defer _ = coord_set.deinit();
    for (coords.items) |coord| {
        try coord_set.put(coord, '#');
    }

    // Find Deminsions of Map
    var sorted_x = try coords.clone(allocator);
    defer _ = sorted_x.deinit(allocator);
    std.mem.sort(
        Coord,
        sorted_x.items,
        {},
        compareByX,
    );

    var sorted_y = try coords.clone(allocator);
    defer _ = sorted_y.deinit(allocator);
    std.mem.sort(
        Coord,
        sorted_y.items,
        {},
        compareByY,
    );

    min_x = sorted_x.items[0].x;
    min_y = sorted_y.items[0].y;
    const max_x = sorted_x.items[sorted_x.items.len - 1].x;
    const max_y = sorted_y.items[sorted_y.items.len - 1].y;

    std.debug.print("Printing Map with deminsions {d}x{d}\n", .{ max_x - min_x + 1, max_y - min_y + 1 });
    // try printMap(&coord_set, min_y, max_y, min_x, max_x);

    // Add Perimeter to Map
    std.debug.print("Adding Perimeter...\n", .{});
    var last_coord = sorted_x.items[0];
    for (sorted_x.items[1..]) |coord| {
        if (last_coord.x == coord.x) {
            var y_idx = @min(last_coord.y, coord.y) + 1;
            while (y_idx < @max(last_coord.y, coord.y)) {
                try coord_set.put(.{ .x = coord.x, .y = y_idx }, 'X');
                y_idx += 1;
            }
        }
        last_coord = coord;
    }

    last_coord = sorted_y.items[0];
    for (sorted_y.items[1..]) |coord| {
        if (last_coord.y == coord.y) {
            var x_idx = @min(last_coord.x, coord.x) + 1;
            while (x_idx < @max(last_coord.x, coord.x)) {
                try coord_set.put(.{ .x = x_idx, .y = coord.y }, 'X');
                x_idx += 1;
            }
        }
        last_coord = coord;
    }

    // try printMap(&coord_set, min_y, max_y, min_x, max_x);

    std.debug.print("Finding Valid Rectangles...\n", .{});
    // Find valid rectangles
    var max_area: usize = 0;
    var inside_cache = std.AutoHashMap(Coord, bool).init(allocator);
    defer inside_cache.deinit();
    for (coords.items, 0..) |start, i| {
        for (coords.items[i + 1 ..]) |end| {
            var rect = Rect.init(start, end);
            if (!try rect.valid_rect(coord_set, max_x, &inside_cache)) continue;
            std.debug.print("({d},{d}) - ({d},{d}) --> {d}\n", .{ rect.a.x, rect.a.y, rect.b.x, rect.b.y, rect.area });
            if (rect.area > max_area) {
                max_area = rect.area;
            }
        }
    }

    return max_area;
}

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\nRunning part 1 test...\n", .{});
    try std.testing.expectEqual(50, try part1(allocator, input));
}

test "part 2" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\nRunning part 2 test...\n", .{});
    try std.testing.expectEqual(24, try part2(allocator, input));
}
