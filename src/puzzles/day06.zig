const std = @import("std");
const aoc = @import("../root.zig");

const Solution = aoc.Solution;

const Grid = struct {
    rows: std.ArrayList(std.ArrayList(u8)),
    allocator: std.mem.Allocator,

    fn deinit(self: *Grid) void {
        for (self.rows.items) |*row| {
            row.deinit(self.allocator);
        }
        self.rows.deinit(self.allocator);
    }

    fn height(self: Grid) usize {
        return self.rows.items.len;
    }

    fn width(self: Grid) usize {
        if (self.rows.items.len == 0) return 0;
        return self.rows.items[0].items.len;
    }

    fn operatorRow(self: Grid) usize {
        return self.height() - 1;
    }
};

pub fn solve() !void {
    const input = @embedFile("../inputs/day06.txt");
    try aoc.runSolution("Day 06", input, trashCompactor, .{});
}

fn trashCompactor(allocator: std.mem.Allocator, input: []const u8) !Solution {
    // Parse once into character grid
    var grid = try parseGrid(allocator, input);
    defer grid.deinit();

    // Extract whitespace-separated columns for Part 1
    var columns = try extractColumns(allocator, grid);
    defer freeColumns(allocator, &columns);

    const part1 = try solvePart1(columns, grid);
    const part2 = try solvePart2(allocator, grid);

    return Solution{ .part1 = part1, .part2 = part2 };
}

// Parse input into a character-based grid (parse once!)
fn parseGrid(allocator: std.mem.Allocator, input: []const u8) !Grid {
    var rows = std.ArrayList(std.ArrayList(u8)){};
    errdefer {
        for (rows.items) |*row| {
            row.deinit(allocator);
        }
        rows.deinit(allocator);
    }

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var row = std.ArrayList(u8){};
        errdefer row.deinit(allocator);

        for (line) |char| {
            try row.append(allocator, char);
        }

        try rows.append(allocator, row);
    }

    return Grid{ .rows = rows, .allocator = allocator };
}

// Extract whitespace-separated values from the character grid
fn extractColumns(allocator: std.mem.Allocator, grid: Grid) !std.ArrayList(std.ArrayList([]const u8)) {
    var columns = std.ArrayList(std.ArrayList([]const u8)){};
    errdefer freeColumns(allocator, &columns);

    for (grid.rows.items) |row| {
        var col_values = std.ArrayList([]const u8){};
        errdefer col_values.deinit(allocator);

        var current_value = std.ArrayList(u8){};
        defer current_value.deinit(allocator);

        for (row.items) |char| {
            if (char == ' ' or char == '\t') {
                // End of a value
                if (current_value.items.len > 0) {
                    const owned = try current_value.toOwnedSlice(allocator);
                    try col_values.append(allocator, owned);
                    current_value = std.ArrayList(u8){};
                }
            } else {
                try current_value.append(allocator, char);
            }
        }

        // Don't forget the last value
        if (current_value.items.len > 0) {
            const owned = try current_value.toOwnedSlice(allocator);
            try col_values.append(allocator, owned);
        }

        try columns.append(allocator, col_values);
    }

    return columns;
}

fn freeColumns(allocator: std.mem.Allocator, columns: *std.ArrayList(std.ArrayList([]const u8))) void {
    for (columns.items) |*row| {
        for (row.items) |value| {
            allocator.free(value);
        }
        row.deinit(allocator);
    }
    columns.deinit(allocator);
}

// Part 1: Calculate column equations using extracted values
fn solvePart1(columns: std.ArrayList(std.ArrayList([]const u8)), grid: Grid) !usize {
    if (columns.items.len == 0) return 0;

    const num_cols = columns.items[0].items.len;
    const operator_row_idx = grid.operatorRow();
    var total: usize = 0;

    for (0..num_cols) |col_idx| {
        var column_result: usize = 0;

        // Process each row in the column (except operator row)
        for (columns.items[0..operator_row_idx], 0..) |row, row_idx| {
            const value_str = row.items[col_idx];
            const value = try std.fmt.parseInt(usize, value_str, 10);

            if (row_idx == 0) {
                column_result = value;
            } else {
                const operator = columns.items[operator_row_idx].items[col_idx][0];
                column_result = try applyOperator(column_result, operator, value);
            }
        }

        total += column_result;
    }

    return total;
}

// Part 2: Calculate using vertical numbers from character grid
fn solvePart2(allocator: std.mem.Allocator, grid: Grid) !usize {
    if (grid.height() == 0) return 0;

    // Extract vertical numbers from each column (right to left)
    var vertical_numbers = try extractVerticalNumbers(allocator, grid);
    defer freeVerticalNumbers(allocator, &vertical_numbers);

    // Process operators and calculate result
    return try processOperators(vertical_numbers, grid.rows.items[grid.operatorRow()], grid.width());
}

// Extract numbers reading vertically down each column
fn extractVerticalNumbers(allocator: std.mem.Allocator, grid: Grid) !std.ArrayList([]const u8) {
    const num_cols = grid.width();
    const operator_row_idx = grid.operatorRow();

    var numbers = std.ArrayList([]const u8){};
    errdefer freeVerticalNumbers(allocator, &numbers);

    // Process columns from right to left
    var col: usize = num_cols;
    while (col > 0) {
        col -= 1;

        var digits = std.ArrayList(u8){};
        defer digits.deinit(allocator);

        // Collect digits from top to operator row
        for (grid.rows.items[0..operator_row_idx]) |row| {
            const char = row.items[col];
            if (char != ' ') {
                try digits.append(allocator, char);
            }
        }

        try numbers.append(allocator, try digits.toOwnedSlice(allocator));
    }

    return numbers;
}

fn freeVerticalNumbers(allocator: std.mem.Allocator, numbers: *std.ArrayList([]const u8)) void {
    for (numbers.items) |str| {
        allocator.free(str);
    }
    numbers.deinit(allocator);
}

// Process operators from right to left, grouping numbers
fn processOperators(numbers: std.ArrayList([]const u8), operator_row: std.ArrayList(u8), num_cols: usize) !usize {
    var total: usize = 0;
    var segment_start: usize = 0;

    var col: usize = num_cols;
    while (col > 0) {
        col -= 1;
        const operator = operator_row.items[col];

        switch (operator) {
            '+', '*' => {
                const segment_end = num_cols - col;
                const segment = numbers.items[segment_start..segment_end];
                const result = try evaluateSegment(segment, operator);
                total += result;
                segment_start = segment_end;
            },
            ' ' => {}, // Skip spaces
            else => {
                std.debug.print("Unknown operator: '{c}'\n", .{operator});
                return error.InvalidOperator;
            },
        }
    }

    return total;
}

// Evaluate a segment of numbers with a single operator
fn evaluateSegment(number_strings: []const []const u8, operator: u8) !usize {
    var result: usize = 0;

    for (number_strings) |num_str| {
        if (num_str.len == 0) continue;

        const value = try std.fmt.parseInt(usize, num_str, 10);

        switch (operator) {
            '+' => {
                result += value;
            },
            '*' => {
                result = if (result == 0) value else result * value;
            },
            else => return error.InvalidOperator,
        }
    }

    return result;
}

// Apply a single operation
fn applyOperator(left: usize, operator: u8, right: usize) !usize {
    return switch (operator) {
        '+' => left + right,
        '*' => left * right,
        else => error.InvalidOperator,
    };
}

test "part 1" {
    const input = @embedFile("../inputs/tests/day06_test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const result = try trashCompactor(allocator, input);
    try std.testing.expectEqual(@as(usize, 4277556), result.part1);
}

test "part 2" {
    const input = @embedFile("../inputs/tests/day06_test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const result = try trashCompactor(allocator, input);
    try std.testing.expectEqual(@as(usize, 3263827), result.part2);
}

test "whitespace splitting" {
    const input = "123 328  51 64";
    var splitter = std.mem.splitAny(u8, input, " \t");
    var parts = std.ArrayList([]const u8){};
    defer parts.deinit(std.testing.allocator);

    while (splitter.next()) |part| {
        const trimmed = std.mem.trim(u8, part, " \t");
        if (trimmed.len == 0) continue;
        try parts.append(std.testing.allocator, trimmed);
    }

    try std.testing.expectEqual(@as(usize, 4), parts.items.len);
    try std.testing.expectEqualSlices(u8, "123", parts.items[0]);
    try std.testing.expectEqualSlices(u8, "328", parts.items[1]);
    try std.testing.expectEqualSlices(u8, "51", parts.items[2]);
    try std.testing.expectEqualSlices(u8, "64", parts.items[3]);
}
