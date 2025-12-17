const std = @import("std");

const Machine = struct {
    key: []u8,
    switches: [][]usize,
    joltage: []usize,

    fn init(key: []u8, switches: [][]usize, joltage: []usize) Machine {
        if (key.len != joltage.len) {
            std.debug.panic("key and joltage must be the same length", .{});
        }

        for (switches) |sw| {
            if (sw.len != key.len) {
                std.debug.panic("switches must be the same length as key", .{});
            }
        }

        return .{ .key = key, .switches = switches, .joltage = joltage };
    }

    fn deinit(self: *Machine, allocator: std.mem.Allocator) void {
        allocator.free(self.key);
        for (self.switches) |sw| {
            allocator.free(sw);
        }
        allocator.free(self.switches);
        allocator.free(self.joltage);
    }

    fn printMachine(self: Machine) void {
        std.debug.print("Machine:\n", .{});

        // Print Light Result
        std.debug.print("\tLights: [", .{});
        for (0..self.key.len - 2) |i| {
            std.debug.print("{d}, ", .{self.key[i]});
        }
        std.debug.print("{d}]\n", .{self.key[self.key.len - 1]});

        // Print Joltage Result
        std.debug.print("\tJoltage: [", .{});
        for (0..self.joltage.len - 2) |i| {
            std.debug.print("{d}, ", .{self.joltage[i]});
        }
        std.debug.print("{d}]\n", .{self.joltage[self.joltage.len - 1]});

        // Print Switches
        std.debug.print("\tSwitches:\n", .{});
        for (self.switches) |sws| {
            std.debug.print("\t\t[", .{});
            for (0..sws.len - 2) |i| {
                std.debug.print("{d},", .{sws[i]});
            }
            std.debug.print("{d}]\n", .{sws[sws.len - 1]});
        }
        std.debug.print("\n", .{});
    }

    fn findMinPresses(self: Machine, allocator: std.mem.Allocator) !?usize {
        const State = struct {
            lights: []u8,
            presses: usize,

            fn hash(s: @This()) u64 {
                var hasher = std.hash.Wyhash.init(0);
                hasher.update(s.lights);
                return hasher.final();
            }

            fn eql(a: @This(), b: @This()) bool {
                return std.mem.eql(u8, a.lights, b.lights);
            }
        };

        const HashContext = struct {
            pub fn hash(_: @This(), s: State) u64 {
                return s.hash();
            }
            pub fn eql(_: @This(), a: State, b: State) bool {
                return a.eql(b);
            }
        };

        // Standard BFS queue initialization and cleanup
        var queue: std.ArrayList(State) = .empty;
        defer {
            for (queue.items) |state| {
                allocator.free(state.lights);
            }
            queue.deinit(allocator);
        }

        // Standard BFS visited set initialization and cleanup
        var visited = std.HashMap(State, void, HashContext, std.hash_map.default_max_load_percentage).init(allocator);
        defer {
            var iter = visited.keyIterator();
            while (iter.next()) |key| {
                allocator.free(key.lights);
            }
            visited.deinit();
        }

        // Start with all lights off (all 0)
        const start_lights = try allocator.alloc(u8, self.key.len);
        @memset(start_lights, 0);

        const start_state = State{ .lights = start_lights, .presses = 0 };
        try queue.append(allocator, start_state);

        // Add start state to visited set
        // A copy must be made for the HashMap key because the queue will free the memory later.
        const visited_start = try allocator.alloc(u8, self.key.len);
        @memcpy(visited_start, start_lights);
        try visited.put(State{ .lights = visited_start, .presses = 0 }, {});

        while (queue.items.len > 0) {
            const current = queue.orderedRemove(0);

            // Check if we've reached the key
            if (std.mem.eql(u8, current.lights, self.key)) {
                allocator.free(current.lights);
                return current.presses;
            }

            // Try pressing each switch
            for (self.switches) |switch_mask| {
                // Clone current state
                const next_lights = try allocator.alloc(u8, self.key.len);
                @memcpy(next_lights, current.lights);

                // Iterate over all possible light indices
                var idx: usize = 0;
                while (idx < self.key.len) : (idx += 1) {
                    if (switch_mask[idx] == 1) {
                        next_lights[idx] = 1 - next_lights[idx];
                    }
                }

                // Check if we've visited this state using the HashMap `get` method.
                if (visited.get(State{ .lights = next_lights, .presses = 0 }) == null) {
                    // Not visited: add a copy to the visited set and the original to the queue

                    // 1. Add to visited set
                    const visited_lights = try allocator.alloc(u8, self.key.len);
                    @memcpy(visited_lights, next_lights);
                    try visited.put(State{ .lights = visited_lights, .presses = 0 }, {});

                    // 2. Add to queue (uses the current `next_lights` memory)
                    try queue.append(allocator, State{
                        .lights = next_lights,
                        .presses = current.presses + 1,
                    });
                } else {
                    // Already visited: free the memory allocated for this state
                    allocator.free(next_lights);
                }
            }
            // Free the memory for the current state now that all neighbors are processed
            allocator.free(current.lights);
        }

        // No solution found
        return null;
    }
};

const Matrix = struct {
    rows: [][]i64,
    num_rows: usize,
    num_cols: usize,

    fn init(allocator: std.mem.Allocator, num_rows: usize, num_cols: usize) !Matrix {
        const rows = try allocator.alloc([]i64, num_rows);
        for (rows) |*row| {
            row.* = try allocator.alloc(i64, num_cols);
            @memset(row.*, 0);
        }
        return .{
            .rows = rows,
            .num_rows = num_rows,
            .num_cols = num_cols,
        };
    }

    fn deinit(self: *Matrix, allocator: std.mem.Allocator) void {
        for (self.rows) |row| {
            allocator.free(row);
        }
        allocator.free(self.rows);
    }

    fn print(self: Matrix) void {
        std.debug.print("Matrix ({d}x{d}):\n", .{ self.num_rows, self.num_cols });
        for (self.rows) |row| {
            std.debug.print("  [", .{});
            for (row, 0..) |val, i| {
                if (i < row.len - 1) {
                    std.debug.print("{d:3}, ", .{val});
                } else {
                    std.debug.print("{d:3}", .{val});
                }
            }
            std.debug.print("]\n", .{});
        }
    }
};

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("inputs/day10.txt");
    std.debug.print("Part 1 Answer: {d}\n", .{try part1(allocator, input)});
    std.debug.print("Part 2 Answer: {d}\n", .{try part2(allocator, input)});

    const elapsed = timer.read();
    std.debug.print("Run Time: {d:.2}ms\n", .{@as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms});
}

fn part1(allocator: std.mem.Allocator, input: []const u8) !usize {
    var machines: std.ArrayList(Machine) = .empty;
    defer {
        for (machines.items) |*machine| {
            machine.deinit(allocator);
        }
        machines.deinit(allocator);
    }

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var key: std.ArrayList(u8) = .empty;
        defer _ = key.deinit(allocator);
        var switches: std.ArrayList([]usize) = .empty;
        defer _ = switches.deinit(allocator);
        var joltage: std.ArrayList(usize) = .empty;
        defer _ = joltage.deinit(allocator);

        var values = std.mem.splitScalar(u8, line, ' ');
        while (values.next()) |value| {
            const symbol = value[0];
            const cleaned_value = std.mem.trim(u8, value, "{}()[]");
            switch (symbol) {
                '[' => {
                    for (cleaned_value) |char| {
                        if (char == '#') {
                            try key.append(allocator, 1);
                        } else {
                            try key.append(allocator, 0);
                        }
                    }
                },
                '(' => {
                    var sw = try allocator.alloc(usize, key.items.len);
                    @memset(sw, 0);
                    var indexes = std.mem.splitScalar(u8, cleaned_value, ',');
                    while (indexes.next()) |index| {
                        const val = try std.fmt.parseInt(usize, index, 10);
                        sw[val] = 1;
                    }
                    try switches.append(allocator, sw);
                },
                '{' => {
                    var joltages = std.mem.splitScalar(u8, cleaned_value, ',');
                    while (joltages.next()) |jolt| {
                        const val = try std.fmt.parseInt(usize, jolt, 10);

                        try joltage.append(allocator, val);
                    }
                },
                else => {
                    std.debug.panic("unknown value: {c} in line {s}", .{ symbol, cleaned_value });
                },
            }
        }
        try machines.append(allocator, Machine.init(try key.toOwnedSlice(allocator), try switches.toOwnedSlice(allocator), try joltage.toOwnedSlice(allocator)));
    }

    for (machines.items) |machine| {
        machine.printMachine();
    }

    // Find minimum presses for all machines and sum them up
    var total_presses: usize = 0;
    for (machines.items) |machine| {
        if (try machine.findMinPresses(allocator)) |presses| {
            std.debug.print("Min presses for this machine: {d}\n", .{presses});
            total_presses += presses;
        } else {
            std.debug.print("No solution found for this machine!\n", .{});
            return error.NoSolution;
        }
    }

    return total_presses;
}

fn part2(allocator: std.mem.Allocator, input: []const u8) !usize {
    var machines: std.ArrayList(Machine) = .empty;
    defer {
        for (machines.items) |*machine| {
            machine.deinit(allocator);
        }
        machines.deinit(allocator);
    }

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var key: std.ArrayList(u8) = .empty;
        defer _ = key.deinit(allocator);
        var switches: std.ArrayList([]usize) = .empty;
        defer _ = switches.deinit(allocator);
        var joltage: std.ArrayList(usize) = .empty;
        defer _ = joltage.deinit(allocator);

        var values = std.mem.splitScalar(u8, line, ' ');
        while (values.next()) |value| {
            const symbol = value[0];
            const cleaned_value = std.mem.trim(u8, value, "{}()[]");
            switch (symbol) {
                '[' => {
                    for (cleaned_value) |char| {
                        if (char == '#') {
                            try key.append(allocator, 1);
                        } else {
                            try key.append(allocator, 0);
                        }
                    }
                },
                '(' => {
                    var sw = try allocator.alloc(usize, key.items.len);
                    @memset(sw, 0);
                    var indexes = std.mem.splitScalar(u8, cleaned_value, ',');
                    while (indexes.next()) |index| {
                        const val = try std.fmt.parseInt(usize, index, 10);
                        sw[val] = 1;
                    }
                    try switches.append(allocator, sw);
                },
                '{' => {
                    var joltages = std.mem.splitScalar(u8, cleaned_value, ',');
                    while (joltages.next()) |jolt| {
                        const val = try std.fmt.parseInt(usize, jolt, 10);

                        try joltage.append(allocator, val);
                    }
                },
                else => {
                    std.debug.panic("unknown value: {c} in line {s}", .{ symbol, cleaned_value });
                },
            }
        }
        try machines.append(allocator, Machine.init(try key.toOwnedSlice(allocator), try switches.toOwnedSlice(allocator), try joltage.toOwnedSlice(allocator)));
    }

    for (machines.items) |machine| {
        machine.printMachine();
    }

    for (machines.items) |machine| {
        // TODO: Built matrix of buttons associated to joltages
        // ex. Machine = [.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}
        // Matrix = 0, 0, 0, 0, 1, 1, 3
        //          0, 1, 0, 0, 0, 1, 5
        //          0, 0, 1, 1, 1, 0, 4
        //          1, 1, 0, 1, 0, 0, 7
        var matrix = try buildMatrix(allocator, machine);
        defer matrix.deinit(allocator);

        std.debug.print("Original matrix:\n", .{});
        matrix.print();

        //TODO: Transform matix to row echelon form
        // ex. Using above Matrix:
        // Matrix = 1, 0, 0, 1, 0, -1, 2
        //          0, 1, 0, 0, 0, 1, 5
        //          0, 0, 1, 1, 0, -1, 1
        //          0, 0, 0, 0, 1, 1, 3
        toRowEchelonForm(&matrix);

        std.debug.print("Row echelon form:\n", .{});
        matrix.print();
    }

    return 0;
}

// Build the augmented matrix from a machine
// Each row is a LIGHT position, each column is a SWITCH, last column is joltage
fn buildMatrix(allocator: std.mem.Allocator, machine: Machine) !Matrix {
    const num_rows = machine.key.len; // one row per light
    const num_cols = machine.switches.len + 1; // one column per switch + joltage column

    var matrix = try Matrix.init(allocator, num_rows, num_cols);

    // For each light position (row)
    for (0..machine.key.len) |light_idx| {
        // For each switch (column)
        for (machine.switches, 0..) |switch_mask, switch_idx| {
            // Does this switch affect this light?
            matrix.rows[light_idx][switch_idx] = @intCast(switch_mask[light_idx]);
        }
        // Fill in the joltage value for this light (last column)
        matrix.rows[light_idx][num_cols - 1] = @intCast(machine.joltage[light_idx]);
    }

    return matrix;
}

// Transform matrix to row echelon form using Gaussian elimination
fn toRowEchelonForm(matrix: *Matrix) void {
    var pivot_row: usize = 0;

    for (0..matrix.num_cols - 1) |col| {
        if (pivot_row >= matrix.num_rows) break;

        // Find a non-zero pivot in this column
        var found_pivot = false;
        for (pivot_row..matrix.num_rows) |row| {
            if (matrix.rows[row][col] != 0) {
                // Swap rows if needed
                if (row != pivot_row) {
                    const temp = matrix.rows[pivot_row];
                    matrix.rows[pivot_row] = matrix.rows[row];
                    matrix.rows[row] = temp;
                }
                found_pivot = true;
                break;
            }
        }

        if (!found_pivot) continue;

        // Eliminate all rows below the pivot
        for (pivot_row + 1..matrix.num_rows) |row| {
            if (matrix.rows[row][col] != 0) {
                // XOR the rows (since we're working in GF(2) - binary field)
                for (0..matrix.num_cols) |c| {
                    matrix.rows[row][c] ^= matrix.rows[pivot_row][c];
                }
            }
        }

        pivot_row += 1;
    }
}

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\nRunning part 1 test...\n", .{});
    try std.testing.expectEqual(7, try part1(allocator, input));
}

test "part 2" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\nRunning part 2 test...\n", .{});
    try std.testing.expectEqual(33, try part2(allocator, input));
}

test "Min Joltage Presses" {
    const input = @embedFile("inputs/joltage.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\nRunning Minimum Joltage Presess Test...\n", .{});
    try std.testing.expectEqual(33, try part2(allocator, input));
}
