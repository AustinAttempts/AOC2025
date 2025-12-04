const std = @import("std");

const Coord = struct { x: usize, y: usize };

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("inputs/day04.txt");
    std.debug.print("Part 1 Answer: {d}\n", .{try part1(allocator, input)});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

pub fn part1(allocator: std.mem.Allocator, input: []const u8) !usize {
    //TODO: Implement solution
    var valid_rolls: usize = 0;
    var map = std.ArrayHashMap(Coord, u8, std.array_hash_map.AutoContext(Coord), true).init(allocator);
    defer map.deinit();

    var current_pos: Coord = .{ .x = 0, .y = 0 };
    var max_size: Coord = .{ .x = 0, .y = 0 };
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        while (current_pos.x < line.len) {
            try map.put(current_pos, line[current_pos.x]);
            if (current_pos.x > max_size.x) {
                max_size.x = current_pos.x;
            }
            current_pos.x += 1;
        }
        if (current_pos.y > max_size.y) {
            max_size.y = current_pos.y;
        }
        current_pos.y += 1;
        current_pos.x = 0;
    }

    max_size.x += 1;
    max_size.y += 1;

    for (0..max_size.y) |y| {
        for (0..max_size.x) |x| {
            var roll_cnt: usize = 0;
            if ((map.get(.{ .x = x, .y = y }) orelse '?') != '.') {
                const directions = [8][2]i32{
                    .{ -1, 0 }, // left
                    .{ 1, 0 }, // right
                    .{ 0, -1 }, // up
                    .{ 0, 1 }, // down
                    .{ -1, -1 }, // top-left
                    .{ 1, -1 }, // top-right
                    .{ -1, 1 }, // bottom-left
                    .{ 1, 1 }, // bottom-right
                };

                for (directions) |dir| {
                    const nx = @as(i32, @intCast(x)) + dir[0];
                    const ny = @as(i32, @intCast(y)) + dir[1];

                    if (nx >= 0 and nx < max_size.x and ny >= 0 and ny < max_size.y) {
                        const coord = Coord{ .x = @intCast(nx), .y = @intCast(ny) };
                        if ((map.get(coord) orelse '?') != '.') {
                            roll_cnt += 1;
                        }
                    }
                }
                if (roll_cnt < 4) {
                    try map.put(.{ .x = x, .y = y }, 'X');
                    valid_rolls += 1;
                }
            }
            std.debug.print("{c}", .{map.get(.{ .x = x, .y = y }) orelse '?'});
        }
        std.debug.print("\n", .{});
    }

    return valid_rolls;
}

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(13, try part1(allocator, input));
}
