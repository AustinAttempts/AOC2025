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
    var range: std.ArrayList(Range) = .empty;
    defer range.deinit(allocator);

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) break; // Handle change in sections

        var bounds = std.mem.splitScalar(u8, line, '-');
        const start_id = try std.fmt.parseInt(usize, bounds.next().?, 10);
        const end_id = try std.fmt.parseInt(usize, bounds.next().?, 10);
        const valid_range: Range = .{ .start = start_id, .end = end_id };
        try range.append(allocator, valid_range);
        std.debug.print("{s}\n", .{line});
    }

    var sorted = false;
    while (!sorted) {
        sorted = true;
        var i: usize = 0;

        while (i < range.items.len) {
            var j: usize = i + 1;
            var merged = false;

            while (j < range.items.len) {
                const existing = &range.items[i];
                const check = &range.items[j];

                if (existing.start <= check.end and existing.end >= check.start) {
                    existing.start = @min(existing.start, check.start);
                    existing.end = @max(existing.end, check.end);

                    std.debug.print("{d}-{d} merged into {d}-{d}\n", .{ check.start, check.end, existing.start, existing.end });

                    _ = range.orderedRemove(j);
                    sorted = false;
                    merged = true;
                } else {
                    j += 1;
                }
            }

            if (merged) {
                i = 0;
            } else {
                i += 1;
            }
        }
    }

    for (range.items) |value| {
        std.debug.print("Counting Range: {d}-{d}\n", .{ value.start, value.end });
        fresh_ingredients += (value.end - value.start + 1);
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
