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

    fn solveLinearSystem(self: Machine, allocator: std.mem.Allocator) !?[]usize {
        const n_switches = self.switches.len;
        const n_lights = self.joltage.len;

        // Create augmented matrix [A^T | b]
        // We transpose because switches[i] represents column i in the matrix
        var matrix = try allocator.alloc([]f64, n_lights);
        defer {
            for (matrix) |row| allocator.free(row);
            allocator.free(matrix);
        }

        for (0..n_lights) |i| {
            matrix[i] = try allocator.alloc(f64, n_switches + 1);
            // Copy switch values (transposed)
            for (0..n_switches) |j| {
                matrix[i][j] = @floatFromInt(self.switches[j][i]);
            }
            // Add target value (joltage)
            matrix[i][n_switches] = @floatFromInt(self.joltage[i]);
        }

        // Gaussian elimination with partial pivoting
        for (0..@min(n_lights, n_switches)) |col| {
            // Find pivot
            var max_row = col;
            var max_val = @abs(matrix[col][col]);
            for (col + 1..n_lights) |row| {
                const val = @abs(matrix[row][col]);
                if (val > max_val) {
                    max_val = val;
                    max_row = row;
                }
            }

            // Swap rows if needed
            if (max_row != col) {
                const temp = matrix[col];
                matrix[col] = matrix[max_row];
                matrix[max_row] = temp;
            }

            // Check for zero pivot (no unique solution)
            if (@abs(matrix[col][col]) < 1e-10) {
                continue;
            }

            // Eliminate column
            for (col + 1..n_lights) |row| {
                const factor = matrix[row][col] / matrix[col][col];
                for (col..n_switches + 1) |j| {
                    matrix[row][j] -= factor * matrix[col][j];
                }
            }
        }

        // Back substitution
        var solution = try allocator.alloc(f64, n_switches);
        defer allocator.free(solution);
        @memset(solution, 0);

        var row: isize = @intCast(@min(n_lights, n_switches) - 1);
        while (row >= 0) : (row -= 1) {
            const r: usize = @intCast(row);
            if (@abs(matrix[r][r]) < 1e-10) {
                // No unique solution or inconsistent system
                return null;
            }

            var sum: f64 = matrix[r][n_switches];
            for (r + 1..n_switches) |j| {
                sum -= matrix[r][j] * solution[j];
            }
            solution[r] = sum / matrix[r][r];
        }

        // Convert to integers and verify solution is non-negative
        var result = try allocator.alloc(usize, n_switches);
        for (solution, 0..) |val, i| {
            // Check if solution is approximately an integer
            const rounded = @round(val);
            if (@abs(val - rounded) > 1e-6) {
                allocator.free(result);
                return null; // Not an integer solution
            }

            if (rounded < 0) {
                allocator.free(result);
                return null; // Negative presses not allowed
            }

            result[i] = @intFromFloat(rounded);
        }

        // Verify the solution
        for (0..n_lights) |i| {
            var sum: usize = 0;
            for (0..n_switches) |j| {
                sum += self.switches[j][i] * result[j];
            }
            if (sum != self.joltage[i]) {
                allocator.free(result);
                return null; // Solution doesn't work
            }
        }

        return result;
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

    // Find minimum presses for all machines and sum them up
    var total_presses: usize = 0;
    for (machines.items) |machine| {
        if (try machine.solveLinearSystem(allocator)) |solution| {
            defer allocator.free(solution);

            var presses: usize = 0;
            for (solution) |s| {
                presses += s;
            }
            std.debug.print("Min presses for this machine: {d}\n", .{presses});
            total_presses += presses;
        } else {
            std.debug.print("No solution found for this machine!\n", .{});
            return error.NoSolution;
        }
    }

    return total_presses;
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
