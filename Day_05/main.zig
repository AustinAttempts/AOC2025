const std = @import("std");

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
    std.debug.print("Part 1 Answer: {d}\n", .{try part1(allocator, input)});
    std.debug.print("Part 2 Answer: {d}\n", .{try part2(allocator, input)});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

pub fn part1(allocator: std.mem.Allocator, input: []const u8) !usize {
    var fresh_ingredients: usize = 0;
    var range: std.ArrayList(Range) = .empty;
    defer range.deinit(allocator);

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) break; // Handle change in sections

        var bounds = std.mem.splitScalar(u8, line, '-');
        const start_id = try std.fmt.parseInt(usize, bounds.next().?, 10);
        const end_id = try std.fmt.parseInt(usize, bounds.next().?, 10);
        try range.append(allocator, .{ .start = start_id, .end = end_id });
        std.debug.print("{s}\n", .{line});
    }

    while (lines.next()) |line| {
        const id = try std.fmt.parseInt(usize, line, 10);
        for (range.items) |value| {
            if (id >= value.start and id <= value.end) {
                std.debug.print("{d} <-- Fresh Ingredient\n", .{id});
                fresh_ingredients += 1;
                break;
            }
        }
    }

    return fresh_ingredients;
}

pub fn part2(allocator: std.mem.Allocator, input: []const u8) !usize {
    var fresh_ingredients: usize = 0;

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
        std.debug.print("{s}\n", .{line});
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
            std.debug.print("Merged Range: {d}-{d}\n", .{ current.start, last.end });
        } else { // No overlap, add as new range
            try merged.append(allocator, current);
        }
    }

    // Count Total Unique IDs in Merged Ranges
    for (merged.items) |value| {
        fresh_ingredients += (value.end - value.start + 1);
        std.debug.print("Counting Range: {d}-{d}\n", .{ value.start, value.end });
    }

    return fresh_ingredients;
}

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(3, try part1(allocator, input));
}

test "part 2" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(14, try part2(allocator, input));
}

test "part 2 edge case" {
    const input = @embedFile("inputs/edge_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(41, try part2(allocator, input));
}
