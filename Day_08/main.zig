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

const RELEVANT_CIRCUITS_CNT: usize = 3;

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("inputs/day08.txt");
    std.debug.print("Part 1 Answer: {d}\n", .{try part1(allocator, input, 1000)});
    std.debug.print("Part 2 Answer: {d}\n", .{try part2(allocator, input)});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

fn mergeCircuits(allocator: std.mem.Allocator, circuits: *std.ArrayList(std.ArrayList(Coord))) !void {
    var i: usize = 0;
    while (i < circuits.items.len) {
        var j: usize = i + 1;
        while (j < circuits.items.len) {
            var has_overlap = false;

            // Check if circuit i and circuit j have any common coordinates
            for (circuits.items[i].items) |coord_i| {
                for (circuits.items[j].items) |coord_j| {
                    if (std.mem.eql(u8, coord_i.str, coord_j.str)) {
                        has_overlap = true;
                        break;
                    }
                }
                if (has_overlap) break;
            }

            if (has_overlap) {
                // Merge circuit j into circuit i
                for (circuits.items[j].items) |coord_j| {
                    // Check if coord_j is already in circuit i
                    var already_exists = false;
                    for (circuits.items[i].items) |coord_i| {
                        if (std.mem.eql(u8, coord_i.str, coord_j.str)) {
                            already_exists = true;
                            break;
                        }
                    }

                    // Only add if it doesn't exist
                    if (!already_exists) {
                        try circuits.items[i].append(allocator, coord_j);
                    }
                }

                // Remove circuit j
                var removed = circuits.orderedRemove(j);
                removed.deinit(allocator);
                // Don't increment j since we removed an element
            } else {
                j += 1;
            }
        }
        i += 1;
    }
}

fn compareCircuitSize(context: void, a: std.ArrayList(Coord), b: std.ArrayList(Coord)) bool {
    _ = context;
    return a.items.len > b.items.len;
}

fn printCircuits(circuits: std.ArrayList(std.ArrayList(Coord))) void {
    std.debug.print("\nCircuits:\n", .{});
    for (circuits.items) |circuit| {
        std.debug.print("Circuit: ", .{});
        for (circuit.items) |coord| {
            std.debug.print("({s}) ", .{coord.str});
        }
        std.debug.print("\n", .{});
    }
}

fn part1(allocator: std.mem.Allocator, input: []const u8, pairs: usize) !usize {
    var coords: std.ArrayList(Coord) = .empty;
    defer _ = coords.deinit(allocator);

    // Parse input into list of coordinates
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var values = std.mem.splitScalar(u8, line, ',');
        const x = try std.fmt.parseInt(usize, values.next().?, 10);
        const y = try std.fmt.parseInt(usize, values.next().?, 10);
        const z = try std.fmt.parseInt(usize, values.next().?, 10);
        const coord: Coord = .{ .x = x, .y = y, .z = z, .str = line };
        try coords.append(allocator, coord);
    }

    var connections: std.ArrayList(Connection) = .empty;
    defer connections.deinit(allocator);

    // Create list of all possible connections between coordinates
    for (coords.items, 0..) |start, i| {
        for (coords.items[i + 1 ..]) |end| {
            const conn: Connection = Connection.init(start, end);
            try connections.append(allocator, conn);
        }
    }

    // Sort connections by distance
    std.mem.sort(Connection, connections.items, {}, struct {
        fn lessThan(context: void, a: Connection, b: Connection) bool {
            _ = context;
            return a.dist < b.dist;
        }
    }.lessThan);

    var circuits: std.ArrayList(std.ArrayList(Coord)) = .empty;
    defer {
        for (circuits.items) |*circuit| {
            circuit.deinit(allocator);
        }
        circuits.deinit(allocator);
    }

    // Build circuits from connections
    for (0..pairs) |i| {
        const conn = connections.items[i];
        std.debug.print("({s})<->({s}) = {d}\n", .{ conn.a.str, conn.b.str, conn.dist });

        var placed = false;

        for (circuits.items) |*circuit| {
            var found_a = false;
            var found_b = false;

            for (circuit.items) |coord| {
                if (std.mem.eql(u8, coord.str, conn.a.str)) found_a = true;
                if (std.mem.eql(u8, coord.str, conn.b.str)) found_b = true;
            }

            if (found_a and !found_b) {
                try circuit.append(allocator, conn.b);
                placed = true;
                break;
            } else if (found_b and !found_a) {
                try circuit.append(allocator, conn.a);
                placed = true;
                break;
            } else if (found_a and found_b) {
                placed = true;
                break;
            }
        }

        if (!placed) {
            var new_circuit: std.ArrayList(Coord) = .empty;
            try new_circuit.append(allocator, conn.a);
            try new_circuit.append(allocator, conn.b);
            try circuits.append(allocator, new_circuit);
        }
    }

    // Merge circuits that overlap
    var changed = true;
    while (changed) {
        const original_len = circuits.items.len;
        try mergeCircuits(allocator, &circuits);
        changed = circuits.items.len != original_len;
    }

    // Sort circuits by size
    std.mem.sort(std.ArrayList(Coord), circuits.items, {}, compareCircuitSize);

    printCircuits(circuits);

    // Calulate answer from largest 3 circuits
    std.debug.print("{d} Largest circuit sizes: ", .{RELEVANT_CIRCUITS_CNT});
    var sum: usize = 1;
    for (circuits.items[0..RELEVANT_CIRCUITS_CNT]) |circuit| {
        std.debug.print("{d} ", .{circuit.items.len});
        sum *= circuit.items.len;
    }
    std.debug.print("\n", .{});

    return sum;
}

fn part2(allocator: std.mem.Allocator, input: []const u8) !usize {
    var coords: std.ArrayList(Coord) = .empty;
    defer _ = coords.deinit(allocator);

    // Parse input into list of coordinates
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var values = std.mem.splitScalar(u8, line, ',');
        const x = try std.fmt.parseInt(usize, values.next().?, 10);
        const y = try std.fmt.parseInt(usize, values.next().?, 10);
        const z = try std.fmt.parseInt(usize, values.next().?, 10);
        const coord: Coord = .{ .x = x, .y = y, .z = z, .str = line };
        try coords.append(allocator, coord);
    }

    var connections: std.ArrayList(Connection) = .empty;
    defer connections.deinit(allocator);

    // Create list of all possible connections between coordinates
    for (coords.items, 0..) |start, i| {
        for (coords.items[i + 1 ..]) |end| {
            const conn: Connection = Connection.init(start, end);
            try connections.append(allocator, conn);
        }
    }

    // Sort connections by distance
    std.mem.sort(Connection, connections.items, {}, struct {
        fn lessThan(context: void, a: Connection, b: Connection) bool {
            _ = context;
            return a.dist < b.dist;
        }
    }.lessThan);

    var circuits: std.ArrayList(std.ArrayList(Coord)) = .empty;
    defer {
        for (circuits.items) |*circuit| {
            circuit.deinit(allocator);
        }
        circuits.deinit(allocator);
    }

    // Loop until all connections are in one circuit
    var last_connection: ?Connection = null;
    // Build circuits from connections
    for (connections.items) |conn| {
        last_connection = conn;
        var placed = false;

        for (circuits.items) |*circuit| {
            var found_a = false;
            var found_b = false;

            for (circuit.items) |coord| {
                if (std.mem.eql(u8, coord.str, conn.a.str)) found_a = true;
                if (std.mem.eql(u8, coord.str, conn.b.str)) found_b = true;
            }

            if (found_a and !found_b) {
                try circuit.append(allocator, conn.b);
                placed = true;
                break;
            } else if (found_b and !found_a) {
                try circuit.append(allocator, conn.a);
                placed = true;
                break;
            } else if (found_a and found_b) {
                placed = true;
                break;
            }
        }

        if (!placed) {
            var new_circuit: std.ArrayList(Coord) = .empty;
            try new_circuit.append(allocator, conn.a);
            try new_circuit.append(allocator, conn.b);
            try circuits.append(allocator, new_circuit);
        }

        // Merge circuits that overlap
        var changed = true;
        while (changed) {
            const original_len = circuits.items.len;
            try mergeCircuits(allocator, &circuits);
            changed = circuits.items.len != original_len;
        }

        // Check if we're done (all coords in one circuit)
        if (circuits.items.len == 1 and circuits.items[0].items.len == coords.items.len) {
            break;
        }
    }

    var sum: usize = 1;
    if (last_connection != null) {
        std.debug.print("last connection was: {s} <--> {s}\n", .{ last_connection.?.a.str, last_connection.?.b.str });
        sum = last_connection.?.a.x * last_connection.?.b.x;
    }

    return sum;
}

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\nRunning part 1 test...\n", .{});
    try std.testing.expectEqual(40, try part1(allocator, input, 10));
}

test "part 2" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\nRunning part 2 test...\n", .{});
    try std.testing.expectEqual(25272, try part2(allocator, input));
}
