const std = @import("std");

const State = enum {
    PresentKey,
    PresentShape,
    TreeSize,
};

const Present = struct {
    key: usize,
    shape: [][]const u8,
    area: usize,

    fn init(key: usize, shape: [][]const u8) Present {
        var area: usize = 0;
        for (shape) |line| {
            for (line) |c| {
                if (c == '#') {
                    area += 1;
                }
            }
        }
        return .{ .key = key, .shape = shape, .area = area };
    }

    fn deinit(self: *Present, allocator: std.mem.Allocator) void {
        allocator.free(self.shape);
    }

    fn print(self: Present) void {
        std.debug.print("Present {d} (area={d}):\n", .{ self.key, self.area });
        for (self.shape) |line| {
            std.debug.print("  {s}\n", .{line});
        }
    }
};

const Region = struct {
    x: usize,
    y: usize,
    present_qty: []usize,
    area: usize,

    fn init(x: usize, y: usize, present_qty: []usize) Region {
        const area = x * y;
        return .{ .x = x, .y = y, .present_qty = present_qty, .area = area };
    }

    fn deinit(self: *Region, allocator: std.mem.Allocator) void {
        allocator.free(self.present_qty);
    }

    fn print(self: Region) void {
        std.debug.print("Region {d}x{d} (area={d}):\n", .{ self.x, self.y, self.area });
        std.debug.print("  Present quantities: [", .{});
        for (self.present_qty, 0..) |qty, i| {
            if (i > 0) std.debug.print(", ", .{});
            std.debug.print("{d}", .{qty});
        }
        std.debug.print("]\n", .{});
    }
};

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("inputs/day12.txt");
    std.debug.print("Part 1 Answer: {d}\n", .{try part1(allocator, input)});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

fn part1(allocator: std.mem.Allocator, input: []const u8) !usize {
    var presents = std.AutoHashMap(usize, Present).init(allocator);
    defer {
        var iter = presents.valueIterator();
        while (iter.next()) |present| {
            present.deinit(allocator);
        }
        presents.deinit();
    }
    var regions: std.ArrayList(Region) = .empty;
    defer {
        for (regions.items) |*region| {
            region.deinit(allocator);
        }
        regions.deinit(allocator);
    }

    var key: usize = 0;
    var shape: std.ArrayList([]const u8) = .empty;
    defer shape.deinit(allocator);
    var curr_state = State.PresentShape;
    var prev_state = curr_state;

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        if (std.mem.indexOf(u8, line, ":") == null) {
            curr_state = State.PresentShape;
            try shape.append(allocator, line);
        } else if (std.mem.indexOf(u8, line, "x") != null) {
            curr_state = State.TreeSize;
            if (prev_state == State.PresentShape) {
                try presents.put(key, Present.init(key, try shape.toOwnedSlice(allocator)));
            }
            var chunks = std.mem.splitScalar(u8, line, ':');
            var grid = std.mem.splitScalar(u8, chunks.next().?, 'x');
            const x = try std.fmt.parseInt(usize, grid.next().?, 10);
            const y = try std.fmt.parseInt(usize, grid.next().?, 10);
            var cnts = std.mem.splitScalar(u8, chunks.next().?, ' ');
            var cnts_arr: std.ArrayList(usize) = .empty;
            defer cnts_arr.deinit(allocator);
            while (cnts.next()) |cnt| {
                if (cnt.len == 0) continue;
                try cnts_arr.append(allocator, try std.fmt.parseInt(usize, cnt, 10));
            }
            try regions.append(allocator, Region.init(x, y, try cnts_arr.toOwnedSlice(allocator)));
        } else {
            curr_state = State.PresentKey;
            if (prev_state == State.PresentShape) {
                try presents.put(key, Present.init(key, try shape.toOwnedSlice(allocator)));
            }
            key = try std.fmt.parseInt(usize, std.mem.trim(u8, line, ":"), 10);
        }
        prev_state = curr_state;
    }

    var iter = presents.valueIterator();
    while (iter.next()) |present| {
        present.print();
    }

    for (regions.items) |region| {
        region.print();
    }

    var valid_regions: usize = 0;
    for (regions.items) |region| {
        const max_area = region.area;
        var presents_area: usize = 0;
        for (region.present_qty, 0..) |cnt, i| {
            presents_area += (presents.get(i).?.area) * cnt;
        }
        std.debug.print("Region has area {d} & presents take up area {d}\n", .{ max_area, presents_area });
        if (max_area > presents_area) {
            valid_regions += 1;
        }
    }

    return valid_regions;
}

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\nRunning part 1 test...\n", .{});
    try std.testing.expectEqual(2, try part1(allocator, input));
}
