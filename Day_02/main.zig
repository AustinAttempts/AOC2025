const std = @import("std");

pub fn main() !void {
    const input = @embedFile("inputs/day02.txt");
    std.debug.print("Part 1 Answer: {d}\n", .{try part1(input)});
}

pub fn part1(input: []const u8) !usize {
    var bad_id_sum: usize = 0;
    var id_ranges = std.mem.splitScalar(u8, input, ',');
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
            const id_str = try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{id});
            defer std.heap.page_allocator.free(id_str);
            if (bad_id(id_str)) {
                bad_id_sum += id;
            }
        }
    }

    return bad_id_sum;
}

pub fn bad_id(id: []const u8) bool {
    const len = id.len;

    const first_half = id[0 .. len / 2];
    const second_half = id[len / 2 .. len];
    if (std.mem.eql(u8, first_half, second_half)) {
        return true;
    }

    return false;
}

test "bad ID detection" {
    try std.testing.expect(bad_id("55"));
    try std.testing.expect(bad_id("6464"));
    try std.testing.expect(bad_id("123123"));
    try std.testing.expect(!bad_id("101"));
}

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");
    try std.testing.expectEqual(1227775554, try part1(input));
}
