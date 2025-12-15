const std = @import("std");

const Solution = struct {
    part1: usize,
    part2: usize,
};

pub fn main() !void {
    var timer = try std.time.Timer.start();
    const input = @embedFile("inputs/day02.txt");
    const solution = try giftShop(input);

    std.debug.print("Part 1 Answer: {d}\n", .{solution.part1});
    std.debug.print("Part 2 Answer: {d}\n", .{solution.part2});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

fn giftShop(input: []const u8) !Solution {
    var part1: usize = 0;
    var part2: usize = 0;
    var buf: [32]u8 = undefined;

    var id_ranges = std.mem.splitScalar(u8, input, ',');
    while (id_ranges.next()) |id_range| {
        if (id_range.len == 0) continue;
        var bounds = std.mem.splitScalar(u8, id_range, '-');
        const start_id = try std.fmt.parseInt(usize, bounds.next().?, 10);
        const end_id = try std.fmt.parseInt(usize, bounds.next().?, 10);

        for (start_id..end_id + 1) |id| {
            const id_str = try std.fmt.bufPrint(&buf, "{d}", .{id});
            if (badIdPart1(id_str)) {
                part1 += id;
            }
            if (badIdPart2(id_str)) {
                part2 += id;
            }
        }
    }

    return .{ .part1 = part1, .part2 = part2 };
}

fn badIdPart1(id: []const u8) bool {
    const len = id.len;
    const first_half = id[0 .. len / 2];
    const second_half = id[len / 2 .. len];
    if (std.mem.eql(u8, first_half, second_half)) {
        return true;
    }

    return false;
}

fn badIdPart2(id: []const u8) bool {
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
    try std.testing.expect(badIdPart1("55"));
    try std.testing.expect(badIdPart1("6464"));
    try std.testing.expect(badIdPart1("123123"));
    try std.testing.expect(!badIdPart1("101"));
}

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");

    try std.testing.expectEqual(1227775554, (try giftShop(input)).part1);
}

test "Part 2 bad ID detection" {
    try std.testing.expect(badIdPart2("12341234"));
    try std.testing.expect(badIdPart2("123123123"));
    try std.testing.expect(badIdPart2("1212121212"));
    try std.testing.expect(badIdPart2("1111111"));
    try std.testing.expect(badIdPart2("55"));
    try std.testing.expect(badIdPart2("6464"));
    try std.testing.expect(badIdPart2("123123"));
    try std.testing.expect(!badIdPart2("101"));
    try std.testing.expect(!badIdPart2("5"));
}

test "part 2" {
    const input = @embedFile("inputs/test_case.txt");
    try std.testing.expectEqual(4174379265, (try giftShop(input)).part2);
}
