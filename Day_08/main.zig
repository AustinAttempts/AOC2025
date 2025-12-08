const std = @import("std");

const CoordMap = std.ArrayHashMap(usize, Connection, std.array_hash_map.AutoContext(usize), true);

const Coord = struct { x: usize, y: usize, z: usize, str: []const u8 };

const Connection = struct {
    a: Coord,
    b: Coord,
    dist: usize,

    fn init(a: Coord, b: Coord) Connection {
        return .{ .a = a, .b = b, .dist = distance(a, b) };
    }

    fn distance(a: Coord, b: Coord) usize {
        const dx = @as(isize, @intCast(a.x)) - @as(isize, @intCast(b.x));
        const dy = @as(isize, @intCast(a.y)) - @as(isize, @intCast(b.y));
        const dz = @as(isize, @intCast(a.z)) - @as(isize, @intCast(b.z));
        const dist_sq = dx * dx + dy * dy + dz * dz;
        return @intFromFloat(@sqrt(@as(f64, @floatFromInt(dist_sq))));
    }
};

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("inputs/day08.txt");
    std.debug.print("Part 1 Answer: {d}\n", .{try part1(allocator, input)});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

fn part1(allocator: std.mem.Allocator, input: []const u8) !usize {
    const sum: usize = 0;

    var coords: std.ArrayList(Coord) = .empty;
    defer _ = coords.deinit(allocator);

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var values = std.mem.splitScalar(u8, line, ',');
        const x = try std.fmt.parseInt(usize, values.next().?, 10);
        const y = try std.fmt.parseInt(usize, values.next().?, 10);
        const z = try std.fmt.parseInt(usize, values.next().?, 10);
        const coord: Coord = .{ .x = x, .y = y, .z = z, .str = line };
        try coords.append(allocator, coord);
    }

    var coordMap = CoordMap.init(allocator);
    defer coordMap.deinit();

    for (coords.items, 0..) |start, i| {
        for (coords.items[i + 1 ..]) |end| {
            const conn: Connection = Connection.init(start, end);
            try coordMap.put(conn.dist, conn);
        }
    }

    var distances: std.ArrayList(usize) = .empty;
    defer distances.deinit(allocator);
    try distances.appendSlice(allocator, coordMap.keys());
    std.mem.sort(usize, distances.items, {}, std.sort.asc(usize));

    var circuits: std.ArrayList(std.ArrayList(Coord)) = .empty;
    defer {
        for (circuits.items) |*circuit| {
            circuit.deinit(allocator);
        }
        circuits.deinit(allocator);
    }

    for (0..10) |i| {
        const conn = coordMap.get(distances.items[i]).?;
        std.debug.print("({s})<->({s}) = {d}\n", .{ conn.a.str, conn.b.str, conn.dist });

        if (i == 0) {
            var new_circuit: std.ArrayList(Coord) = .empty;
            try new_circuit.append(allocator, conn.a);
            try new_circuit.append(allocator, conn.b);
            try circuits.append(allocator, new_circuit);
            continue;
        }

        var placed = false;

        for (circuits.items) |*circuit| {
            for (circuit.items) |coord| {
                if (std.mem.eql(u8, coord.str, conn.a.str)) {
                    try circuit.append(allocator, conn.b);
                    placed = true;
                    break;
                }
                if (std.mem.eql(u8, coord.str, conn.b.str)) {
                    try circuit.append(allocator, conn.b);
                    placed = true;
                    break;
                }
            }
        }

        if (!placed) {
            var new_circuit: std.ArrayList(Coord) = .empty;
            try new_circuit.append(allocator, conn.a);
            try new_circuit.append(allocator, conn.b);
            try circuits.append(allocator, new_circuit);
        }
    }

    std.debug.print("\nCircuits:\n", .{});
    for (circuits.items) |circuit| {
        std.debug.print("Circuit: ", .{});
        for (circuit.items) |coord| {
            std.debug.print("({s}) ", .{coord.str});
        }
        std.debug.print("\n", .{});
    }

    return sum;
}

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\nRunning part 1 test...\n", .{});
    try std.testing.expectEqual(40, try part1(allocator, input));
}
