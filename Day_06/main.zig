const std = @import("std");

const Solution = struct {
    part1: usize,
    part2: usize,
};

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("inputs/day06.txt");
    const solution = try trashCompactor(allocator, input);
    std.debug.print("Part 1 Answer: {d}\n", .{solution.part1});
    std.debug.print("Part 2 Answer: {d}\n", .{solution.part2});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

fn trashCompactor(allocator: std.mem.Allocator, input: []const u8) !Solution {
    // Part 1: Parse whitespace-separated numbers in columns
    var part1_grid = std.ArrayList(std.ArrayList([]const u8)){};
    defer {
        for (part1_grid.items) |*row| {
            row.deinit(allocator);
        }
        part1_grid.deinit(allocator);
    }

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var row = std.ArrayList([]const u8){};
        var tokens = std.mem.splitAny(u8, line, " \t");
        while (tokens.next()) |token| {
            const cleaned = std.mem.trim(u8, token, " \t");
            if (cleaned.len > 0) {
                try row.append(allocator, cleaned);
            }
        }
        try part1_grid.append(allocator, row);
    }

    const part1 = try calcCols(part1_grid);

    // Part 2: Parse character-by-character grid
    var part2_grid = std.ArrayList(std.ArrayList(u8)){};
    defer {
        for (part2_grid.items) |*row| {
            row.deinit(allocator);
        }
        part2_grid.deinit(allocator);
    }

    lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var row = std.ArrayList(u8){};
        for (line) |char| {
            try row.append(allocator, char);
        }
        try part2_grid.append(allocator, row);
    }

    const part2 = try calcPart2(allocator, part2_grid);

    return Solution{ .part1 = part1, .part2 = part2 };
}

fn calcPart2(allocator: std.mem.Allocator, grid: std.ArrayList(std.ArrayList(u8))) !usize {
    if (grid.items.len == 0) return 0;

    const num_cols = grid.items[0].items.len;
    const last_row_idx = grid.items.len - 1;

    // Extract vertical numbers from right to left
    var col_numbers = std.ArrayList([]const u8){};
    defer {
        for (col_numbers.items) |str| {
            allocator.free(str);
        }
        col_numbers.deinit(allocator);
    }

    var col: usize = num_cols;
    while (col > 0) {
        col -= 1;
        var digits = std.ArrayList(u8){};
        defer digits.deinit(allocator);

        // Collect non-space characters from top to second-to-last row
        for (grid.items[0..last_row_idx]) |row| {
            const char = row.items[col];
            if (char != ' ') {
                try digits.append(allocator, char);
            }
        }
        try col_numbers.append(allocator, try digits.toOwnedSlice(allocator));
    }

    // Process operators right to left
    var total: usize = 0;
    var segment_start: usize = 0;

    col = num_cols;
    while (col > 0) {
        col -= 1;
        const operator = grid.items[last_row_idx].items[col];

        switch (operator) {
            '+', '*' => {
                const segment_end = num_cols - col;
                const result = try evaluateSegment(col_numbers.items[segment_start..segment_end], operator);
                total += result;
                segment_start = segment_end;
            },
            ' ' => {}, // Skip spaces
            else => {
                std.debug.print("Unknown Operator: {c}\n", .{operator});
                return error.InvalidOperator;
            },
        }
    }

    return total;
}

fn evaluateSegment(numbers: []const []const u8, operator: u8) !usize {
    var result: usize = 0;

    for (numbers) |num_str| {
        if (num_str.len == 0) continue;

        const value = try std.fmt.parseInt(usize, num_str, 10);

        switch (operator) {
            '+' => result += value,
            '*' => {
                if (result == 0) {
                    result = value;
                } else {
                    result *= value;
                }
            },
            else => return error.InvalidOperator,
        }
    }

    return result;
}

fn calcCols(grid: std.ArrayList(std.ArrayList([]const u8))) !usize {
    var sum: usize = 0;
    const num_equations = grid.items[0].items.len; // Number of equations to calculate
    var col: usize = 0;
    while (col < num_equations) : (col += 1) {
        var local_sum: usize = 0;
        for (grid.items[0 .. grid.items.len - 1], 0..) |row, row_idx| {
            const value = row.items[col];
            if (row_idx == 0) {
                local_sum = try std.fmt.parseInt(usize, value, 10);
            } else {
                const operator = grid.items[grid.items.len - 1].items[col][0];
                switch (operator) {
                    '+' => {
                        local_sum += try std.fmt.parseInt(usize, value, 10);
                    },
                    '*' => {
                        local_sum *= try std.fmt.parseInt(usize, value, 10);
                    },
                    else => {
                        std.debug.print("Unkown Operator: {c}", .{operator});
                        return error.InvalidOperator;
                    },
                }
            }
        }
        sum += local_sum;
    }
    return sum;
}

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(4277556, (try trashCompactor(allocator, input)).part1);
}

test "split whitespace" {
    const input = "123 328  51 64";
    var splitter = std.mem.splitAny(u8, input, " \t");
    var parts: std.ArrayList([]const u8) = .empty;
    defer parts.deinit(std.testing.allocator);

    while (splitter.next()) |part| {
        const cleaned_part = std.mem.trim(u8, part, " \t");
        if (cleaned_part.len == 0) continue;
        try parts.append(std.testing.allocator, cleaned_part);
    }

    try std.testing.expectEqualSlices(u8, "123", parts.items[0]);
    try std.testing.expectEqualSlices(u8, "328", parts.items[1]);
    try std.testing.expectEqualSlices(u8, "51", parts.items[2]);
    try std.testing.expectEqualSlices(u8, "64", parts.items[3]);
}

test "part 2" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try std.testing.expectEqual(3263827, (try trashCompactor(allocator, input)).part2);
}
