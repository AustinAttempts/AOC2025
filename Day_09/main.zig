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

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
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

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\nRunning part 1 test...\n", .{});
    try std.testing.expectEqual(50, try part1(allocator, input));
}
