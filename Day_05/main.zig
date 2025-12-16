const std = @import("std");

const Solution = struct {
    part1: usize,
    part2: usize,
};

const Range = struct {
    start: usize,
    end: usize,
};

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("inputs/day05.txt");
    const solution = try cafeteria(allocator, input);
    std.debug.print("Part 1 Answer: {d}\n", .{solution.part1});
    std.debug.print("Part 2 Answer: {d}\n", .{solution.part2});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

fn cafeteria(allocator: std.mem.Allocator, input: []const u8) !Solution {
    // Parse Ranges Data into ArrayLists
    var ranges: std.ArrayList(Range) = .empty;
    defer ranges.deinit(allocator);
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) break; // Handle change in sections

        var bounds = std.mem.splitScalar(u8, line, '-');
        const start_id = try std.fmt.parseInt(usize, bounds.next().?, 10);
        const end_id = try std.fmt.parseInt(usize, bounds.next().?, 10);
        const valid_range: Range = .{ .start = start_id, .end = end_id };
        try ranges.append(allocator, valid_range);
    }

    var part1: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        const id = try std.fmt.parseInt(usize, line, 10);
        for (ranges.items) |value| {
            if (id >= value.start and id <= value.end) {
                part1 += 1;
                break;
            }
        }
    }

    // Sort Ranges by Start Value
    std.mem.sort(Range, ranges.items, {}, struct {
        fn lessThan(_: void, a: Range, b: Range) bool {
            return a.start < b.start;
        }
    }.lessThan);

    // Merge Overlapping Ranges
    var merged: std.ArrayList(Range) = .empty;
    defer merged.deinit(allocator);
    try merged.append(allocator, ranges.items[0]);

    for (ranges.items[1..]) |current| {
        var last = &merged.items[merged.items.len - 1];

        if (current.start <= last.end + 1) { // Ranges overlap or are adjacent, merge them
            last.end = @max(last.end, current.end);
        } else { // No overlap, add as new range
            try merged.append(allocator, current);
        }
    }

    // Count Total Unique IDs in Merged Ranges
    var part2: usize = 0;
    for (merged.items) |value| {
        part2 += (value.end - value.start + 1);
    }

    return .{ .part1 = part1, .part2 = part2 };
}

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(3, (try cafeteria(allocator, input)).part1);
}

test "part 2" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(14, (try cafeteria(allocator, input)).part2);
}

test "part 2 edge case" {
    const input = @embedFile("inputs/edge_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(41, (try cafeteria(allocator, input)).part2);
}
