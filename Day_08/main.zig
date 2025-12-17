const std = @import("std");

const Solution = struct {
    part1: usize,
    part2: usize,
};

const RELEVANT_CIRCUITS_CNT: usize = 3;

const Coord = struct { x: usize, y: usize, z: usize, id: usize, str: []const u8 };
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
        const rank = try allocator.alloc(usize, n);
        const size = try allocator.alloc(usize, n);

        for (0..n) |i| {
            parent[i] = i; // Initalize all elements are in their own set
            rank[i] = 0; // Size of this set
            size[i] = 1;
        }

        return .{ .parent = parent, .rank = rank, .size = size, .allocator = allocator };
    }

    fn deinit(self: *UnionFind) void {
        self.allocator.free(self.parent);
        self.allocator.free(self.rank);
        self.allocator.free(self.size);
    }

    // Return representative of X's set
    fn find(self: *UnionFind, x: usize) usize {
        if (self.parent[x] != x) {
            self.parent[x] = self.find(self.parent[x]);
        }
        return self.parent[x];
    }

    // Unites the set that includes X and the set that includes Y
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
            // If ranks are the same move Y under X (dosen't matter)
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

    fn print(self: *UnionFind, allocator: std.mem.Allocator) !void {
        const n = self.parent.len;

        // Map root → dynamic array of members
        var components = std.AutoHashMap(usize, std.ArrayList(usize)).init(allocator);
        defer {
            var iter = components.valueIterator();
            while (iter.next()) |list| list.deinit(allocator);
            components.deinit();
        }

        // Build component lists
        for (0..n) |i| {
            const root = self.find(i);

            var entry = try components.getOrPut(root);
            if (!entry.found_existing) {
                entry.value_ptr.* = .empty;
            }
            try entry.value_ptr.append(allocator, i);
        }

        // Print
        std.debug.print("==== UnionFind Components ====\n", .{});

        var iter = components.iterator();
        while (iter.next()) |entry| {
            const root = entry.key_ptr.*;
            const list = entry.value_ptr.*;

            std.debug.print("Circuit (root {d}): ", .{root});
            for (list.items, 0..) |member, idx| {
                if (idx > 0) std.debug.print(", ", .{});
                std.debug.print("{d}", .{member});
            }
            std.debug.print("\n", .{});
        }
    }
};

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("inputs/day08.txt");
    const solution = try playground(allocator, input, 1000);
    std.debug.print("Part 1 Answer: {d}\n", .{solution.part1});
    std.debug.print("Part 2 Answer: {d}\n", .{solution.part2});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

fn playground(allocator: std.mem.Allocator, input: []const u8, pairs: usize) !Solution {
    var coords: std.ArrayList(Coord) = .empty;
    defer _ = coords.deinit(allocator);

    // Parse input into list of coordinates where each line is the index of that coordinate.
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var values = std.mem.splitScalar(u8, line, ',');
        const x = try std.fmt.parseInt(usize, values.next().?, 10);
        const y = try std.fmt.parseInt(usize, values.next().?, 10);
        const z = try std.fmt.parseInt(usize, values.next().?, 10);

        const idx = coords.items.len;
        const coord: Coord = .{ .x = x, .y = y, .z = z, .id = idx, .str = line };
        try coords.append(allocator, coord);
    }

    var connections: std.ArrayList(Connection) = .empty;
    defer connections.deinit(allocator);

    // Create list of all possible connections between coordinates
    for (coords.items, 0..) |start, i| {
        for (coords.items[i + 1 ..]) |end| {
            try connections.append(allocator, Connection.init(start, end));
        }
    }

    // Sort connections by distance
    std.mem.sort(Connection, connections.items, {}, struct {
        fn lessThan(context: void, a: Connection, b: Connection) bool {
            _ = context;
            return a.dist < b.dist;
        }
    }.lessThan);

    var uf = try UnionFind.init(allocator, coords.items.len);
    defer uf.deinit();

    // Build circuits starting from closest connections
    for (connections.items[0..pairs]) |conn| {
        _ = uf.unite(conn.a.id, conn.b.id);
    }
    var component_sizes: std.ArrayList(usize) = .empty;
    defer component_sizes.deinit(allocator);

    var seen = std.AutoHashMap(usize, void).init(allocator);
    defer seen.deinit();

    for (0..coords.items.len) |i| {
        const root = uf.find(i);
        if (!seen.contains(root)) {
            try seen.put(root, {});
            try component_sizes.append(allocator, uf.getSize(root));
        }
    }

    // Sort circuits by size
    std.mem.sort(usize, component_sizes.items, {}, std.sort.desc(usize));

    // Calulate answer from largest 3 circuits
    var part1: usize = 1;
    for (component_sizes.items[0..RELEVANT_CIRCUITS_CNT]) |size| {
        part1 *= size;
    }

    // Build circuits starting from closest connections until all are connected
    var part2: usize = 0;
    for (connections.items) |conn| {
        if (uf.unite(conn.a.id, conn.b.id)) {
            if (uf.numComponents() == 1) {
                part2 = conn.a.x * conn.b.x;
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

    try std.testing.expectEqual(40, (try playground(allocator, input, 10)).part1);
}

test "part 2" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(25272, (try playground(allocator, input, 10)).part2);
}
