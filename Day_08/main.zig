const std = @import("std");

const Solution = struct {
    part1: usize,
    part2: usize,
};

const TOP_CIRCUITS_COUNT: usize = 3;

const Coord = struct {
    x: usize,
    y: usize,
    z: usize,
    id: usize,
};

const Connection = struct {
    a_id: usize,
    b_id: usize,
    dist: usize,

    fn init(a: Coord, b: Coord) Connection {
        return .{
            .a_id = a.id,
            .b_id = b.id,
            .dist = distance(a, b),
        };
    }

    fn distance(a: Coord, b: Coord) usize {
        const dx = @as(isize, @intCast(a.x)) - @as(isize, @intCast(b.x));
        const dy = @as(isize, @intCast(a.y)) - @as(isize, @intCast(b.y));
        const dz = @as(isize, @intCast(a.z)) - @as(isize, @intCast(b.z));
        const dist_sq = (dx * dx) + (dy * dy) + (dz * dz);
        return @intFromFloat(@sqrt(@as(f64, @floatFromInt(dist_sq))));
    }
};

const UnionFind = struct {
    parent: []usize,
    rank: []usize,
    size: []usize,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, n: usize) !UnionFind {
        const parent = try allocator.alloc(usize, n);
        errdefer allocator.free(parent);
        const rank = try allocator.alloc(usize, n);
        errdefer allocator.free(rank);
        const size = try allocator.alloc(usize, n);

        for (0..n) |i| {
            parent[i] = i; // Initialize all elements in their own set
            rank[i] = 0;
            size[i] = 1;
        }

        return .{
            .parent = parent,
            .rank = rank,
            .size = size,
            .allocator = allocator,
        };
    }

    fn deinit(self: *UnionFind) void {
        self.allocator.free(self.parent);
        self.allocator.free(self.rank);
        self.allocator.free(self.size);
    }

    /// Return representative of X's set
    fn find(self: *UnionFind, x: usize) usize {
        if (self.parent[x] != x) {
            self.parent[x] = self.find(self.parent[x]);
        }
        return self.parent[x];
    }

    /// Unites the set that includes X and the set that includes Y
    /// Returns true if the sets were merged, false if they were already in the same set
    fn unite(self: *UnionFind, x: usize, y: usize) bool {
        // Find representative of each set
        const root_x = self.find(x);
        const root_y = self.find(y);

        // Elements are already in the same set
        if (root_x == root_y) return false;

        if (self.rank[root_x] < self.rank[root_y]) {
            // Move X under Y so that depth of tree remains less
            self.parent[root_x] = root_y;
            self.size[root_y] += self.size[root_x];
        } else if (self.rank[root_x] > self.rank[root_y]) {
            // Move Y under X so that depth of tree remains less
            self.parent[root_y] = root_x;
            self.size[root_x] += self.size[root_y];
        } else {
            // If ranks are the same move Y under X (doesn't matter)
            self.parent[root_y] = root_x;
            self.rank[root_x] += 1;
            self.size[root_x] += self.size[root_y];
        }

        return true;
    }

    fn getSize(self: *UnionFind, x: usize) usize {
        return self.size[self.find(x)];
    }

    fn numComponents(self: *UnionFind) usize {
        var count: usize = 0;
        for (0..self.parent.len) |i| {
            if (self.parent[i] == i) count += 1;
        }
        return count;
    }
};

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("inputs/day08.txt");
    const solution = try solve(allocator, input, 1000);
    std.debug.print("Part 1 Answer: {d}\n", .{solution.part1});
    std.debug.print("Part 2 Answer: {d}\n", .{solution.part2});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

/// Solve the circuit connection problem using Kruskal's algorithm
/// connections_to_add: Number of shortest connections to add for part 1
fn solve(allocator: std.mem.Allocator, input: []const u8, connections_to_add: usize) !Solution {
    if (input.len == 0) return .{ .part1 = 0, .part2 = 0 };

    var coords: std.ArrayList(Coord) = .empty;
    defer coords.deinit(allocator);

    // Parse input into list of coordinates where each line is the index of that coordinate
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue; // Skip empty lines

        var values = std.mem.splitScalar(u8, line, ',');
        const x = try std.fmt.parseInt(usize, values.next().?, 10);
        const y = try std.fmt.parseInt(usize, values.next().?, 10);
        const z = try std.fmt.parseInt(usize, values.next().?, 10);

        const idx = coords.items.len;
        const coord: Coord = .{ .x = x, .y = y, .z = z, .id = idx };
        try coords.append(allocator, coord);
    }

    if (coords.items.len == 0) return .{ .part1 = 0, .part2 = 0 };

    var connections: std.ArrayList(Connection) = .empty;
    defer connections.deinit(allocator);

    // Create list of all possible connections between coordinates
    for (coords.items, 0..) |start, i| {
        for (coords.items[i + 1 ..]) |end| {
            try connections.append(allocator, Connection.init(start, end));
        }
    }

    // Sort connections by distance (Kruskal's algorithm)
    std.mem.sort(Connection, connections.items, {}, struct {
        fn lessThan(context: void, a: Connection, b: Connection) bool {
            _ = context;
            return a.dist < b.dist;
        }
    }.lessThan);

    // Part 1: Build circuits using the first N shortest connections
    var uf = try UnionFind.init(allocator, coords.items.len);
    defer uf.deinit();

    const num_connections = @min(connections_to_add, connections.items.len);
    for (connections.items[0..num_connections]) |conn| {
        _ = uf.unite(conn.a_id, conn.b_id);
    }

    // Collect all unique component sizes
    var component_sizes: std.ArrayList(usize) = .empty;
    defer component_sizes.deinit(allocator);

    var seen_roots = std.AutoHashMap(usize, void).init(allocator);
    defer seen_roots.deinit();

    for (0..coords.items.len) |i| {
        const root = uf.find(i);
        if (!seen_roots.contains(root)) {
            try seen_roots.put(root, {});
            try component_sizes.append(allocator, uf.getSize(root));
        }
    }

    // Sort circuits by size (descending)
    std.mem.sort(usize, component_sizes.items, {}, std.sort.desc(usize));

    // Calculate answer from largest circuits
    var part1: usize = 1;
    const circuits_to_multiply = @min(TOP_CIRCUITS_COUNT, component_sizes.items.len);
    for (component_sizes.items[0..circuits_to_multiply]) |size| {
        part1 *= size;
    }

    // Part 2: Build circuits until all coordinates are in one component
    var part2: usize = 0;
    for (connections.items) |conn| {
        if (uf.unite(conn.a_id, conn.b_id)) {
            if (uf.numComponents() == 1) {
                // Get the original coordinates
                const coord_a = coords.items[conn.a_id];
                const coord_b = coords.items[conn.b_id];
                part2 = coord_a.x * coord_b.x;
                break;
            }
        }
    }

    return .{ .part1 = part1, .part2 = part2 };
}

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(40, (try solve(allocator, input, 10)).part1);
}

test "part 2" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(25272, (try solve(allocator, input, 10)).part2);
}
