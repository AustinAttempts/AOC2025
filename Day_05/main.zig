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
    var ranges: std.ArrayList(Range) = .empty;
    defer ranges.deinit(allocator);
    var ids: std.ArrayList(usize) = .empty;
    defer ids.deinit(allocator);

    var lines = std.mem.splitScalar(u8, input, '\n');

    // Parse Ranges
    while (lines.next()) |line| {
        if (line.len == 0) break; // Handle change in sections
        var bounds = std.mem.splitScalar(u8, line, '-');
        const start_id = try std.fmt.parseInt(usize, bounds.next().?, 10);
        const end_id = try std.fmt.parseInt(usize, bounds.next().?, 10);
        try ranges.append(allocator, .{ .start = start_id, .end = end_id });
    }

    // Parse IDs
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        const id = try std.fmt.parseInt(usize, line, 10);
        try ids.append(allocator, id);
    }

    // Part 1: Count valid IDs
    const part1 = countValidIds(ids.items, ranges.items);

    // Part 2: Count total coverage
    const part2 = try countTotalCoverage(allocator, ranges.items);

    return .{ .part1 = part1, .part2 = part2 };
}

fn countValidIds(ids: []const usize, ranges: []const Range) usize {
    var count: usize = 0;
    for (ids) |id| {
        for (ranges) |range| {
            if (id >= range.start and id <= range.end) {
                count += 1;
                break;
            }
        }
    }
    return count;
}

fn countTotalCoverage(allocator: std.mem.Allocator, ranges: []const Range) !usize {
    if (ranges.len == 0) return 0;

    // Copy and sort
    var sorted = try allocator.dupe(Range, ranges);
    defer allocator.free(sorted);

    std.mem.sort(Range, sorted, {}, struct {
        fn lessThan(_: void, a: Range, b: Range) bool {
            return a.start < b.start;
        }
    }.lessThan);

    // Merge and count
    var total: usize = sorted[0].end - sorted[0].start + 1;
    var last_end = sorted[0].end;

    for (sorted[1..]) |current| {
        if (current.start <= last_end + 1) {
            // Overlapping or adjacent - only count the new portion
            if (current.end > last_end) {
                total += current.end - last_end;
                last_end = current.end;
            }
        } else {
            // Non-overlapping - count entire range
            total += current.end - current.start + 1;
            last_end = current.end;
        }
    }

    return total;
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
