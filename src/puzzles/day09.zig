const std = @import("std");
const aoc = @import("../root.zig");

const Solution = aoc.Solution;

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

    fn corners(self: Rect) [4]Coord {
        const x1 = @min(self.a.x, self.b.x);
        const y1 = @min(self.a.y, self.b.y);
        const x2 = @max(self.a.x, self.b.x);
        const y2 = @max(self.a.y, self.b.y);

        return [4]Coord{
            .{ .x = x1, .y = y1 },
            .{ .x = x2, .y = y1 },
            .{ .x = x1, .y = y2 },
            .{ .x = x2, .y = y2 },
        };
    }

    fn bounds(self: Rect) struct { x1: usize, y1: usize, x2: usize, y2: usize } {
        return .{
            .x1 = @min(self.a.x, self.b.x),
            .y1 = @min(self.a.y, self.b.y),
            .x2 = @max(self.a.x, self.b.x),
            .y2 = @max(self.a.y, self.b.y),
        };
    }
};

pub fn solve() !void {
    const input = @embedFile("../inputs/day09.txt");
    try aoc.runSolution("Day 09", input, movieTheatre, .{});
}

fn movieTheatre(allocator: std.mem.Allocator, input: []const u8) !Solution {
    // Parse coordinates
    var coords: std.ArrayList(Coord) = .empty;
    defer coords.deinit(allocator);

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var values = std.mem.splitScalar(u8, line, ',');
        const x = try std.fmt.parseInt(usize, values.next().?, 10);
        const y = try std.fmt.parseInt(usize, values.next().?, 10);
        try coords.append(allocator, .{ .x = x, .y = y });
    }

    // Find bounds for normalization
    var min_x: usize = std.math.maxInt(usize);
    var min_y: usize = std.math.maxInt(usize);
    for (coords.items) |coord| {
        min_x = @min(min_x, coord.x);
        min_y = @min(min_y, coord.y);
    }

    // Normalize coordinates in-place
    for (coords.items) |*coord| {
        coord.x -= min_x;
        coord.y -= min_y;
    }

    const polygon = coords.items;

    // Optional: output for visualization
    // try outputPolygonToText(polygon, "polygon_vertices.csv");

    // Generate all possible rectangles
    var candidate_rects: std.ArrayList(Rect) = .empty;
    defer candidate_rects.deinit(allocator);

    for (polygon, 0..) |vertex1, i| {
        for (polygon[i + 1 ..]) |vertex2| {
            try candidate_rects.append(allocator, Rect.init(vertex1, vertex2));
        }
    }

    // Sort by area descending
    std.mem.sort(Rect, candidate_rects.items, {}, rectCmp);

    const part1: usize = candidate_rects.items[0].area;

    // Find largest rectangle fully inside the polygon
    var part2: usize = 0;
    for (candidate_rects.items) |rect| {
        if (isRectangleInsidePolygon(rect, polygon)) {
            part2 = rect.area;
            break;
        }
    }

    return .{ .part1 = part1, .part2 = part2 };
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

fn distanceSquared(a: Coord, b: Coord) usize {
    const dx = @abs(@as(isize, @intCast(a.x)) - @as(isize, @intCast(b.x)));
    const dy = @abs(@as(isize, @intCast(a.y)) - @as(isize, @intCast(b.y)));
    return @as(usize, @intCast(dx * dx + dy * dy));
}

fn outputPolygonToText(polygon: []const Coord, filename: []const u8) !void {
    const file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();

    try file.writeAll("# Normalized Polygon Vertices (x,y)\n");

    var buffer: [64]u8 = undefined;
    for (polygon) |coord| {
        const line_len = try std.fmt.bufPrint(&buffer, "{d},{d}\n", .{ coord.x, coord.y });
        try file.writeAll(line_len);
    }
}

/// Check if point is strictly inside rectangle (excluding boundary)
fn isStrictlyInsideRect(p: Coord, x1: usize, y1: usize, x2: usize, y2: usize) bool {
    return p.x > x1 and p.x < x2 and p.y > y1 and p.y < y2;
}

/// Check if rectangle is completely inside polygon
///
/// Algorithm uses three checks to ensure containment:
/// 1. All four corners must be inside or on the polygon boundary
/// 2. No polygon vertices can be strictly inside the rectangle interior
///    (this handles concave notches that could cut through the rectangle)
/// 3. Every point along all four edges must be inside or on the polygon
///    (this ensures edges don't cross outside the polygon boundary)
fn isRectangleInsidePolygon(rect: Rect, polygon: []const Coord) bool {
    const b = rect.bounds();

    // Step 1: Check all corners are inside or on polygon boundary
    const corners = rect.corners();
    for (corners) |corner| {
        if (!isPointInsidePolygon(corner, polygon)) return false;
    }

    // Step 2: Check no polygon vertex is strictly inside rectangle
    // This handles concave cases where a notch cuts through the rectangle's middle
    for (polygon) |vertex| {
        if (isStrictlyInsideRect(vertex, b.x1, b.y1, b.x2, b.y2)) {
            return false;
        }
    }

    // Step 3: Check all points along vertical edges (left and right)
    for (b.y1..b.y2 + 1) |y| {
        if (!isPointInsidePolygon(.{ .x = b.x1, .y = y }, polygon)) return false;
        if (!isPointInsidePolygon(.{ .x = b.x2, .y = y }, polygon)) return false;
    }

    // Step 4: Check all points along horizontal edges (top and bottom)
    for (b.x1..b.x2 + 1) |x| {
        if (!isPointInsidePolygon(.{ .x = x, .y = b.y1 }, polygon)) return false;
        if (!isPointInsidePolygon(.{ .x = x, .y = b.y2 }, polygon)) return false;
    }

    return true;
}

/// Winding Number Algorithm for point-in-polygon test
/// Returns true if point is inside or on the boundary of the polygon
///
/// The winding number counts how many times the polygon winds around the point.
/// If the count is non-zero, the point is inside. The algorithm also explicitly
/// checks if the point lies on any edge of the polygon.
fn isPointInsidePolygon(point: Coord, polygon: []const Coord) bool {
    const px = @as(isize, @intCast(point.x));
    const py = @as(isize, @intCast(point.y));

    var winding_number: isize = 0;

    for (0..polygon.len) |i| {
        const p1 = polygon[i];
        const p2 = polygon[(i + 1) % polygon.len];

        const x1 = @as(isize, @intCast(p1.x));
        const y1 = @as(isize, @intCast(p1.y));
        const x2 = @as(isize, @intCast(p2.x));
        const y2 = @as(isize, @intCast(p2.y));

        // Check if point lies exactly on the edge
        const cross = crossProduct(p1, p2, point);
        if (cross == 0) {
            // Point is collinear with edge; check if it's between p1 and p2
            const dot = (px - x1) * (x2 - x1) + (py - y1) * (y2 - y1);
            if (dot >= 0) {
                const dot_u = @as(usize, @intCast(dot));
                if (dot_u <= distanceSquared(p1, p2)) {
                    return true; // Point is on the edge
                }
            }
        }

        // Count edge crossings using winding number
        if (y1 <= py) {
            // Edge starts at or below the horizontal ray
            if (y2 > py and cross > 0) {
                // Edge crosses upward and point is to the left
                winding_number += 1;
            }
        } else {
            // Edge starts above the horizontal ray
            if (y2 <= py and cross < 0) {
                // Edge crosses downward and point is to the right
                winding_number -= 1;
            }
        }
    }

    // Point is inside if winding number is non-zero
    return winding_number != 0;
}

test "part 1" {
    const input = @embedFile("../inputs/tests/day09_test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(50, (try movieTheatre(allocator, input)).part1);
}

test "part 2" {
    const input = @embedFile("../inputs/tests/day09_test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(24, (try movieTheatre(allocator, input)).part2);
}
