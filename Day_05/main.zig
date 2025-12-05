const std = @import("std");
const FreshMap = std.ArrayHashMap(usize, usize, std.array_hash_map.AutoContext(usize), true);

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("inputs/day05.txt");
    std.debug.print("Part 1 Answer: {d}\n", .{try part1(allocator, input)});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

pub fn part1(allocator: std.mem.Allocator, input: []const u8) !usize {
    var fresh_ingredients: usize = 0;
    var fresh = FreshMap.init(allocator);
    defer fresh.deinit();

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) break;
        //TODO: build fresh ingredients list
        var bounds = std.mem.splitScalar(u8, line, '-');
        const start_id = try std.fmt.parseInt(usize, bounds.next().?, 10);
        const end_id = try std.fmt.parseInt(usize, bounds.next().?, 10);
        for (start_id..end_id + 1) |id| {
            _ = try fresh.put(id, 0); // build fresh ingredients map
        }
        std.debug.print("{s}\n", .{line});
    }

    while (lines.next()) |line| {
        //TODO: Check if ingredient is in fresh ingredients list
        const id = try std.fmt.parseInt(usize, line, 10);
        const value = fresh.get(id);
        if (value != null) {
            _ = try fresh.put(id, value.? + 1);
            std.debug.print("{s} <-- Valid Ingredient\n", .{line});
        }
    }

    var fresh_iter = fresh.iterator();
    while (fresh_iter.next()) |entry| {
        fresh_ingredients += entry.value_ptr.*;
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
