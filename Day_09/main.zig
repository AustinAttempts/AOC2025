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

    // fn valid_rect(self: *Rect) !bool {
    //     //TODO
    // }
};

fn rectCmp(context: void, a: Rect, b: Rect) bool {
    _ = context;
    return a.area < b.area;
}

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

fn drawPerimeter(allocator: std.mem.Allocator, floor: [][]u8, coords: []Coord, max_x: usize, max_y: usize) !void {
    _ = max_x;
    _ = max_y;

    if (coords.len < 2) return;

    // Find convex hull points
    var hull = try convexHull(allocator, coords);
    defer _ = hull.deinit(allocator);

    // Draw lines between consecutive hull points
    for (0..hull.items.len) |i| {
        const p1 = hull.items[i];
        const p2 = hull.items[(i + 1) % hull.items.len];
        drawLine(floor, p1.x, p1.y, p2.x, p2.y);
    }
}

fn drawLine(floor: [][]u8, x1: usize, y1: usize, x2: usize, y2: usize) void {
    // Draw horizontal line first (if needed)
    if (x1 != x2) {
        const start_x = @min(x1, x2);
        const end_x = @max(x1, x2);
        for (start_x..end_x + 1) |x| {
            // Only mark with X if it's not already a #
            if (floor[y1][x] != '#') {
                floor[y1][x] = 'X';
            }
        }
    }

    // Then draw vertical line (if needed)
    if (y1 != y2) {
        const start_y = @min(y1, y2);
        const end_y = @max(y1, y2);
        for (start_y..end_y + 1) |y| {
            // Only mark with X if it's not already a #
            if (floor[y][x2] != '#') {
                floor[y][x2] = 'X';
            }
        }
    }
}

fn convexHull(allocator: std.mem.Allocator, coords: []Coord) !std.ArrayList(Coord) {
    var hull = std.ArrayList(Coord).empty;

    if (coords.len < 3) {
        try hull.appendSlice(allocator, coords);
        return hull;
    }

    // Find the leftmost point (and lowest if tied)
    var leftmost: usize = 0;
    for (coords, 0..) |coord, i| {
        if (coord.x < coords[leftmost].x or
            (coord.x == coords[leftmost].x and coord.y < coords[leftmost].y))
        {
            leftmost = i;
        }
    }

    var current = leftmost;
    while (true) {
        try hull.append(allocator, coords[current]);
        var next: usize = 0;

        // Find the most counter-clockwise point from current
        for (coords, 0..) |_, i| {
            if (next == current) {
                next = i;
            } else {
                const cross = crossProduct(coords[current], coords[i], coords[next]);
                const dist_i = distance(coords[current], coords[i]);
                const dist_next = distance(coords[current], coords[next]);

                if (cross > 0 or (cross == 0 and dist_i > dist_next)) {
                    next = i;
                }
            }
        }

        current = next;
        if (current == leftmost) break;
    }

    return hull;
}

fn crossProduct(o: Coord, a: Coord, b: Coord) isize {
    const ox = @as(isize, @intCast(o.x));
    const oy = @as(isize, @intCast(o.y));
    const ax = @as(isize, @intCast(a.x));
    const ay = @as(isize, @intCast(a.y));
    const bx = @as(isize, @intCast(b.x));
    const by = @as(isize, @intCast(b.y));

    return (ax - ox) * (by - oy) - (ay - oy) * (bx - ox);
}

fn distance(a: Coord, b: Coord) usize {
    const dx = @abs(@as(isize, @intCast(a.x)) - @as(isize, @intCast(b.x)));
    const dy = @abs(@as(isize, @intCast(a.y)) - @as(isize, @intCast(b.y)));
    return @as(usize, @intCast(dx * dx + dy * dy));
}

fn printFloor(floor: [][]u8, max_x: usize, max_y: usize) void {
    for (0..max_y) |y| {
        for (0..max_x) |x| {
            std.debug.print("{c}", .{floor[y][x]});
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
    var min_x: usize = std.math.maxInt(usize);
    var min_y: usize = std.math.maxInt(usize);

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var values = std.mem.splitScalar(u8, line, ',');
        const x = try std.fmt.parseInt(usize, values.next().?, 10);
        const y = try std.fmt.parseInt(usize, values.next().?, 10);
        min_x = @min(min_x, x);
        min_y = @min(min_y, y);
        const coord: Coord = .{ .x = x, .y = y };
        try coords.append(allocator, coord);
    }

    // Normalize Coordinates
    var coords_normed: std.ArrayList(Coord) = .empty;
    defer _ = coords_normed.deinit(allocator);
    for (coords.items) |coord| {
        try coords_normed.append(allocator, .{ .x = coord.x - min_x, .y = coord.y - min_y });
    }

    for (0..coords.items.len) |i| {
        const coord = coords.items[i];
        const coord_normed = coords_normed.items[i];
        std.debug.print("({d},{d}) --> ({d},{d})\n", .{ coord.x, coord.y, coord_normed.x, coord_normed.y });
    }

    // Find Normalized Bounds
    var max_x: usize = 0;
    var max_y: usize = 0;
    for (coords_normed.items) |coord| {
        max_x = @max(max_x, coord.x + 1);
        max_y = @max(max_y, coord.y + 1);
    }

    // Calulate All possible rectangles with normalized bounds
    var rects: std.ArrayList(Rect) = .empty;
    defer _ = rects.deinit(allocator);

    for (coords_normed.items, 0..) |edge1, i| {
        for (coords_normed.items[i + 1 ..]) |edge2| {
            try rects.append(allocator, Rect.init(edge1, edge2));
        }
    }

    // Sort rects in descending order by area
    std.mem.sort(Rect, rects.items, {}, rectCmp);

    // Make 2D Array of bounds
    const floor = try allocator.alloc([]u8, max_y);
    defer allocator.free(floor);
    for (floor) |*x| {
        x.* = try allocator.alloc(u8, max_x);
    }
    defer for (floor) |*x| {
        allocator.free(x.*);
    };

    // Initialize
    for (0..max_y) |y| {
        for (0..max_x) |x| {
            floor[y][x] = ' ';
        }
    }

    for (coords_normed.items) |coord| {
        floor[coord.y][coord.x] = '#';
    }

    // Draw Perimeter
    try drawPerimeter(allocator, floor, coords_normed.items, max_x, max_y);

    printFloor(floor, max_x, max_y);

    return 0;
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
