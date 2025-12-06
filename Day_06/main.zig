const std = @import("std");

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("inputs/day06.txt");
    std.debug.print("Part 1 Answer: {d}\n", .{try part1(allocator, input)});
    std.debug.print("Part 2 Answer: {d}\n", .{try part2(allocator, input)});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

pub fn calcCols(grid: std.ArrayList(std.ArrayList([]const u8))) !usize {
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

pub fn part1(allocator: std.mem.Allocator, input: []const u8) !usize {
    var grid: std.ArrayList(std.ArrayList([]const u8)) = .empty;
    defer {
        for (grid.items) |*row| {
            row.deinit(allocator);
        }
        grid.deinit(allocator);
    }

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var vales = std.mem.splitAny(u8, line, " \t");
        var operands: std.ArrayList([]const u8) = .empty;
        while (vales.next()) |value| {
            const cleaned_value = std.mem.trim(u8, value, " \t");
            if (cleaned_value.len != 0) {
                try operands.append(allocator, cleaned_value);
            }
        }
        try grid.append(allocator, operands);
    }

    return calcCols(grid);
}

pub fn part2(allocator: std.mem.Allocator, input: []const u8) !usize {
    var sum: usize = 0;

    var grid: std.ArrayList(std.ArrayList(u8)) = .empty;
    defer {
        for (grid.items) |*row| {
            row.deinit(allocator);
        }
        grid.deinit(allocator);
    }

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var chars: std.ArrayList(u8) = .empty;
        for (line) |char| {
            try chars.append(allocator, char);
        }
        try grid.append(allocator, chars);
    }

    var math_values: std.ArrayList([]const u8) = .empty;
    defer {
        for (math_values.items) |str| {
            allocator.free(str);
        }
        math_values.deinit(allocator);
    }

    // Iterate columns from right to left
    const num_cols = grid.items[0].items.len;
    var col: usize = num_cols;
    while (col > 0) {
        col -= 1;
        // Iterate rows from top to bottom (excluding last row if needed)
        var numbers: std.ArrayList(u8) = .empty;
        defer numbers.deinit(allocator);
        for (grid.items[0 .. grid.items.len - 1]) |row| {
            const value = row.items[col];
            // TODO: Handle value
            if (value != ' ') {
                try numbers.append(allocator, value);
            }
        }
        try math_values.append(allocator, try numbers.toOwnedSlice(allocator));
        std.debug.print("Column {d} has value: {s}\n", .{ col, math_values.items[num_cols - col - 1] });
    }

    std.debug.print("\nMath Values:\n", .{});
    for (math_values.items) |values| {
        std.debug.print("{s}\n", .{values});
    }

    // Column range
    var upper = num_cols - 1;
    col = num_cols;

    while (col > 0) {
        col -= 1;
        switch (grid.items[grid.items.len - 1].items[col]) {
            '+' => {
                std.debug.print("found + at col: {d}\n", .{col});
                std.debug.print("add values from col: {d}-{d}\n", .{ col, upper });
                var local_sum: usize = 0;
                const right_lim = num_cols - upper - 1;
                const left_lim = num_cols - col;
                std.debug.print("checking math_values[{d} .. {d}]\n", .{ right_lim, left_lim });

                for (math_values.items[right_lim..left_lim]) |value| {
                    if (value.len != 0) {
                        const value_int = try std.fmt.parseInt(usize, value, 10);
                        std.debug.print("{d} ", .{value_int});
                        local_sum += value_int;
                    }
                }
                std.debug.print("Answer: {d}\n", .{local_sum});
                sum += local_sum;
                if (col > 0) {
                    upper = col - 1;
                }
            },
            '*' => {
                std.debug.print("found * at col: {d}\n", .{col});
                std.debug.print("multiply values from col: {d}-{d}\n", .{ col, upper });
                var local_sum: usize = 0;
                const right_lim = num_cols - upper - 1;
                const left_lim = num_cols - col;
                std.debug.print("checking math_values[{d} .. {d}]\n", .{ right_lim, left_lim });
                for (math_values.items[right_lim..left_lim]) |value| {
                    if (value.len != 0) {
                        const value_int = try std.fmt.parseInt(usize, value, 10);
                        std.debug.print("{d} ", .{value_int});
                        if (local_sum == 0) {
                            local_sum = value_int;
                        } else {
                            local_sum *= value_int;
                        }
                    }
                }
                std.debug.print("Answer: {d}\n", .{local_sum});
                sum += local_sum;
                if (col > 0) {
                    upper = col - 1;
                }
            },
            else => {
                // Do nothing
            },
        }
    }

    return sum;
}

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\nRunning part 1 test...\n", .{});
    try std.testing.expectEqual(4277556, try part1(allocator, input));
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

    std.debug.print("\nRunning part 2 test...\n", .{});
    try std.testing.expectEqual(3263827, try part2(allocator, input));
}
