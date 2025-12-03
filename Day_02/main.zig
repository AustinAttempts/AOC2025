const std = @import("std");

pub fn main() !void {
    var timer = try std.time.Timer.start();
    const input = @embedFile("inputs/day02.txt");

    std.debug.print("Part 1 Answer: {d}\n", .{try part1(input)});
    std.debug.print("Part 2 Answer: {d}\n", .{try part2(input)});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

pub fn part1(input: []const u8) !usize {
    var bad_id_sum: usize = 0;
    var id_ranges = std.mem.splitScalar(u8, input, ',');
    var buf: [32]u8 = undefined; // Attempt to remove allocations

    while (id_ranges.next()) |id_range| {
        var bounds = std.mem.splitScalar(u8, id_range, '-');
        const start_id = std.fmt.parseInt(usize, bounds.next().?, 10) catch |err| {
            std.debug.print("failed to parse: {s}\n", .{id_range});
            return err;
        };
        const end_id = std.fmt.parseInt(usize, bounds.next().?, 10) catch |err| {
            std.debug.print("failed to parse: {s}\n", .{id_range});
            return err;
        };

        for (start_id..end_id + 1) |id| {
            const id_str = try std.fmt.bufPrint(&buf, "{d}", .{id});
            if (bad_id_part_1(id_str)) {
                bad_id_sum += id;
            }
        }
    }

    return bad_id_sum;
}

pub fn bad_id_part_1(id: []const u8) bool {
    const len = id.len;
    const first_half = id[0 .. len / 2];
    const second_half = id[len / 2 .. len];
    if (std.mem.eql(u8, first_half, second_half)) {
        return true;
    }

    return false;
}

pub fn part2(input: []const u8) !usize {
    var bad_id_sum: usize = 0;
    var id_ranges = std.mem.splitScalar(u8, input, ',');
    var buf: [32]u8 = undefined; // Attempt to remove allocations

    while (id_ranges.next()) |id_range| {
        var bounds = std.mem.splitScalar(u8, id_range, '-');
        const start_id = std.fmt.parseInt(usize, bounds.next().?, 10) catch |err| {
            std.debug.print("failed to parse: {s}\n", .{id_range});
            return err;
        };
        const end_id = std.fmt.parseInt(usize, bounds.next().?, 10) catch |err| {
            std.debug.print("failed to parse: {s}\n", .{id_range});
            return err;
        };

        for (start_id..end_id + 1) |id| {
            const id_str = try std.fmt.bufPrint(&buf, "{d}", .{id});
            if (bad_id_part_2(id_str)) {
                bad_id_sum += id;
            }
        }
    }

    return bad_id_sum;
}

pub fn bad_id_part_2(id: []const u8) bool {
    const len = id.len;
    for (1..(len / 2) + 1) |i| {
        if (len % i == 0) {
            const substr = id[0..i];
            var is_repeated = true;

            var j: usize = i;
            while (j < len) : (j += i) {
                if (!std.mem.eql(u8, substr, id[j .. j + i])) {
                    is_repeated = false;
                    break;
                }
            }

            if (is_repeated) return true;
        }
    }
    return false;
}

test "Part 1 bad ID detection" {
    try std.testing.expect(bad_id_part_1("55"));
    try std.testing.expect(bad_id_part_1("6464"));
    try std.testing.expect(bad_id_part_1("123123"));
    try std.testing.expect(!bad_id_part_1("101"));
}

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");

    try std.testing.expectEqual(1227775554, try part1(input));
}

test "Part 2 bad ID detection" {
    try std.testing.expect(bad_id_part_2("12341234"));
    try std.testing.expect(bad_id_part_2("123123123"));
    try std.testing.expect(bad_id_part_2("1212121212"));
    try std.testing.expect(bad_id_part_2("1111111"));
    try std.testing.expect(bad_id_part_2("55"));
    try std.testing.expect(bad_id_part_2("6464"));
    try std.testing.expect(bad_id_part_2("123123"));
    try std.testing.expect(!bad_id_part_2("101"));
    try std.testing.expect(!bad_id_part_2("5"));
}

test "part 2" {
    const input = @embedFile("inputs/test_case.txt");
    try std.testing.expectEqual(4174379265, try part2(input));
}
