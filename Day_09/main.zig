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

fn rectCmp(context: void, a: Rect, b: Rect) bool {
    _ = context;
    return a.area > b.area;
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

fn outputPolygonToText(allocator: std.mem.Allocator, polygon: []const Coord, filename: []const u8) !void {
    _ = allocator;
    const file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();

    try file.writeAll("# Normalized Polygon Vertices (x,y)\n");

    var buffer: [64]u8 = undefined;
    for (polygon) |coord| {
        const line_len = try std.fmt.bufPrint(&buffer, "{d},{d}\n", .{ coord.x, coord.y });
        try file.writeAll(line_len);
    }
}

fn part1(allocator: std.mem.Allocator, input: []const u8) !usize {
    var coords: std.ArrayList(Coord) = .empty;
    defer _ = coords.deinit(allocator);
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
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
        if (line.len == 0) continue;
        var values = std.mem.splitScalar(u8, line, ',');
        const x = try std.fmt.parseInt(usize, values.next().?, 10);
        const y = try std.fmt.parseInt(usize, values.next().?, 10);
        const coord: Coord = .{ .x = x, .y = y };
        try coords.append(allocator, coord);
    }

    std.debug.print("Total coordinates: {d}\n", .{coords.items.len});

    // Find min values for normalization
    var min_x: usize = std.math.maxInt(usize);
    var min_y: usize = std.math.maxInt(usize);
    for (coords.items) |coord| {
        min_x = @min(min_x, coord.x);
        min_y = @min(min_y, coord.y);
    }

    // Normalize coordinates
    var coords_normed: std.ArrayList(Coord) = .empty;
    defer _ = coords_normed.deinit(allocator);
    for (coords.items) |coord| {
        try coords_normed.append(allocator, .{ .x = coord.x - min_x, .y = coord.y - min_y });
    }

    std.debug.print("Normalized coordinates (offset by {d},{d})\n", .{ min_x, min_y });

    // Find bounds after normalization
    var max_x: usize = 0;
    var max_y: usize = 0;
    for (coords_normed.items) |coord| {
        max_x = @max(max_x, coord.x);
        max_y = @max(max_y, coord.y);
    }
    std.debug.print("Normalized bounds: {d} x {d}\n", .{ max_x, max_y });

    // The simple_polygon is the ordered list of normalized coordinates (the boundary)
    const simple_polygon = coords_normed.items;
    std.debug.print("Polygon has {d} points\n", .{simple_polygon.len});

    // Output vertices for visualization
    try outputPolygonToText(allocator, simple_polygon, "polygon_vertices.csv");
    std.debug.print("Polygon vertices written to polygon_vertices.csv\n", .{});

    // Calculate all possible rectangles using normalized coordinates
    std.debug.print("Calculating rectangles...\n", .{});
    var rects: std.ArrayList(Rect) = .empty;
    defer _ = rects.deinit(allocator);

    for (coords_normed.items, 0..) |edge1, i| {
        for (coords_normed.items[i + 1 ..]) |edge2| {
            try rects.append(allocator, Rect.init(edge1, edge2));
        }
    }

    // Sort rects in descending order by area
    std.mem.sort(Rect, rects.items, {}, rectCmp);
    std.debug.print("Checking {d} rectangles...\n", .{rects.items.len});

    // Check each rectangle to see if it's inside the simple polygon
    var checked: usize = 0;
    for (rects.items) |rect| {
        checked += 1;
        if (checked % 50 == 0) {
            std.debug.print("Checked {d}/{d} rectangles...\n", .{ checked, rects.items.len });
        }

        if (rectangleInsideSimplePolygon(rect, simple_polygon)) {
            std.debug.print("Found valid rect: ({d},{d})-({d},{d}) area={d}\n", .{ rect.a.x, rect.a.y, rect.b.x, rect.b.y, rect.area });
            return rect.area;
        }
    }

    std.debug.print("No valid rectangle found!\n", .{});
    return 0;
}

// Checks if a point is strictly inside the rectangle (excluding edges)
fn isInsideInterior(p: Coord, r: Rect) bool {
    const x1 = @min(r.a.x, r.b.x);
    const y1 = @min(r.a.y, r.b.y);
    const x2 = @max(r.a.x, r.b.x);
    const y2 = @max(r.a.y, r.b.y);

    return p.x > x1 and p.x < x2 and p.y > y1 and p.y < y2;
}

// Uses fast O(N) check for containment in a simple polygon.
fn rectangleInsideSimplePolygon(rect: Rect, polygon: []const Coord) bool {
    const x1 = @min(rect.a.x, rect.b.x);
    const y1 = @min(rect.a.y, rect.b.y);
    const x2 = @max(rect.a.x, rect.b.x);
    const y2 = @max(rect.a.y, rect.b.y);

    // 1. Check the four corners are inside or on the boundary of the polygon P. (O(N))
    const corner_tl: Coord = .{ .x = x1, .y = y1 };
    const corner_tr: Coord = .{ .x = x2, .y = y1 };
    const corner_bl: Coord = .{ .x = x1, .y = y2 };
    const corner_br: Coord = .{ .x = x2, .y = y2 };

    if (!pointInsideSimplePolygon(corner_tl, polygon)) return false;
    if (!pointInsideSimplePolygon(corner_tr, polygon)) return false;
    if (!pointInsideSimplePolygon(corner_bl, polygon)) return false;
    if (!pointInsideSimplePolygon(corner_br, polygon)) return false;

    // 2. Check that no polygon vertex P is strictly inside the interior of the rectangle R. (O(N))
    // This correctly handles concave notches cutting across the rectangle's middle.
    for (polygon) |p| {
        if (isInsideInterior(p, rect)) {
            return false;
        }
    }

    // 3. Check all left and right edges to verify that no edge exists the polygon
    for (y1..y2 + 1) |y| {
        if (!pointInsideSimplePolygon(.{ .x = x1, .y = y }, polygon)) return false;
        if (!pointInsideSimplePolygon(.{ .x = x2, .y = y }, polygon)) return false;
    }

    // 4. Check all top and bottom edges to verify that no edge exists the polygon
    for (x1..x2 + 1) |x| {
        if (!pointInsideSimplePolygon(.{ .x = x, .y = y1 }, polygon)) return false;
        if (!pointInsideSimplePolygon(.{ .x = x, .y = y2 }, polygon)) return false;
    }

    return true;
}

// Uses Winding Number Algorithm for simple or non-simple polygons (including those with holes)
fn pointInsideSimplePolygon(point: Coord, polygon: []const Coord) bool {
    const px = @as(isize, @intCast(point.x));
    const py = @as(isize, @intCast(point.y));

    var wn: isize = 0; // Winding number counter

    for (0..polygon.len) |i| {
        const p1 = polygon[i];
        const p2 = polygon[(i + 1) % polygon.len];

        const x1 = @as(isize, @intCast(p1.x));
        const y1 = @as(isize, @intCast(p1.y));
        const x2 = @as(isize, @intCast(p2.x));
        const y2 = @as(isize, @intCast(p2.y));

        // Edge case 1: Check if point is on the boundary (robust, kept from previous version)
        const cross_boundary_check = crossProduct(p1, p2, point);
        if (cross_boundary_check == 0) {
            const dot_product = (px - x1) * (x2 - x1) + (py - y1) * (y2 - y1);
            if (dot_product >= 0) {
                const dp_u = @as(usize, @intCast(dot_product));
                if (dp_u <= distance(p1, p2)) {
                    return true; // Point is on an edge
                }
            }
        }

        // Winding Number Algorithm: Check for crossings
        if (y1 <= py) { // P1 is below or on the ray
            if (y2 > py) { // P2 is above the ray (Upward crossing)
                if (cross_boundary_check > 0) {
                    wn += 1; // Increment Winding Number
                }
            }
        } else { // P1 is above the ray (y1 > py)
            if (y2 <= py) { // P2 is below or on the ray (Downward crossing)
                if (cross_boundary_check < 0) {
                    wn -= 1; // Decrement Winding Number
                }
            }
        }
    }

    // Point is inside if the winding number is non-zero
    return wn != 0;
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
