const std = @import("std");

const Rational = struct {
    num: i64,
    den: i64,

    fn init(n: i64, d: i64) Rational {
        if (d == 0) return .{ .num = 0, .den = 1 };
        var num = n;
        var den = d;
        if (den < 0) {
            num = -num;
            den = -den;
        }
        const g = gcd(@abs(num), @abs(den));
        return .{
            .num = @divTrunc(num, @as(i64, @intCast(g))),
            .den = @divTrunc(den, @as(i64, @intCast(g))),
        };
    }

    fn gcd(a: u64, b: u64) u64 {
        var x = a;
        var y = b;
        while (y != 0) {
            const t = y;
            y = x % y;
            x = t;
        }
        return if (x == 0) 1 else x;
    }

    fn add(self: Rational, other: Rational) Rational {
        return init(self.num * other.den + other.num * self.den, self.den * other.den);
    }

    fn sub(self: Rational, other: Rational) Rational {
        return init(self.num * other.den - other.num * self.den, self.den * other.den);
    }

    fn mul(self: Rational, other: Rational) Rational {
        return init(self.num * other.num, self.den * other.den);
    }

    fn div(self: Rational, other: Rational) Rational {
        return init(self.num * other.den, self.den * other.num);
    }

    fn isZero(self: Rational) bool {
        return self.num == 0;
    }

    fn toInt(self: Rational) ?i64 {
        if (self.den == 0 or @rem(self.num, self.den) != 0) return null;
        return @divTrunc(self.num, self.den);
    }

    fn fromInt(n: i64) Rational {
        return .{ .num = n, .den = 1 };
    }
};

const Machine = struct {
    key: []u8,
    switches: [][]usize,
    joltage: []usize,

    fn init(key: []u8, switches: [][]usize, joltage: []usize) Machine {
        return .{ .key = key, .switches = switches, .joltage = joltage };
    }

    fn deinit(self: *Machine, allocator: std.mem.Allocator) void {
        allocator.free(self.key);
        for (self.switches) |sw| allocator.free(sw);
        allocator.free(self.switches);
        allocator.free(self.joltage);
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

    // Part 2 Logic: Integer Linear Programming using Rational Gaussian Elimination
    fn solvePart2(self: Machine) !u64 {
        const num_buttons = self.switches.len;
        const num_counters = self.joltage.len;

        // 1. Build Rational Matrix [A | b]
        var matrix = try std.heap.page_allocator.alloc([65]Rational, num_counters);
        defer std.heap.page_allocator.free(matrix);

        for (0..num_counters) |row| {
            for (0..num_buttons) |col| {
                matrix[row][col] = if (self.switches[col][row] == 1) Rational.fromInt(1) else Rational.fromInt(0);
            }
            matrix[row][num_buttons] = Rational.fromInt(@intCast(self.joltage[row]));
        }

        // 2. Gaussian Elimination
        var pivot_cols = [_]i32{-1} ** 64;
        var current_row: usize = 0;
        for (0..num_buttons) |col| {
            var pivot_row: ?usize = null;
            for (current_row..num_counters) |r| {
                if (!matrix[r][col].isZero()) {
                    pivot_row = r;
                    break;
                }
            }

            if (pivot_row) |pr| {
                // Swap rows
                const tmp = matrix[current_row];
                matrix[current_row] = matrix[pr];
                matrix[pr] = tmp;

                const p_val = matrix[current_row][col];
                for (0..num_buttons + 1) |c| matrix[current_row][c] = matrix[current_row][c].div(p_val);

                for (0..num_counters) |r| {
                    if (r != current_row and !matrix[r][col].isZero()) {
                        const factor = matrix[r][col];
                        for (0..num_buttons + 1) |c| {
                            matrix[r][c] = matrix[r][c].sub(factor.mul(matrix[current_row][c]));
                        }
                    }
                }
                pivot_cols[current_row] = @intCast(col);
                current_row += 1;
            }
        }

        // Inconsistency check
        for (current_row..num_counters) |r| {
            if (!matrix[r][num_buttons].isZero()) return error.NoSolution;
        }

        // 3. Identify Free Variables
        var is_pivot = [_]bool{false} ** 64;
        for (0..current_row) |r| is_pivot[@intCast(pivot_cols[r])] = true;

        var free_vars = [_]usize{0} ** 64;
        var num_free: usize = 0;
        for (0..num_buttons) |col| {
            if (!is_pivot[col]) {
                free_vars[num_free] = col;
                num_free += 1;
            }
        }

        // 4. Search
        var max_t: u64 = 0;
        for (self.joltage) |t| max_t = @max(max_t, t);

        var min_cost: u64 = std.math.maxInt(u64);
        var free_vals = [_]u64{0} ** 64;

        searchFreeVariables(matrix, num_buttons, current_row, &pivot_cols, &free_vars, num_free, max_t + 1, &free_vals, 0, 0, &min_cost);

        if (min_cost == std.math.maxInt(u64)) return error.NoSolution;
        return min_cost;
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

    // Find minimum presses for all machines and sum them up
    var total_presses: usize = 0;
    for (machines.items) |machine| {
        if (try machine.findMinPresses(allocator)) |presses| {
            total_presses += presses;
        } else {
            return error.NoSolution;
        }
    }

    return total_presses;
}

fn part2(allocator: std.mem.Allocator, input: []const u8) !usize {
    var machines: std.ArrayList(Machine) = .empty;
    defer {
        for (machines.items) |*m| m.deinit(allocator);
        machines.deinit(allocator);
    }

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        try machines.append(allocator, try parseLine(allocator, line));
    }

    var total_p2: usize = 0;
    for (machines.items) |m| {
        total_p2 += try m.solvePart2();
    }

    return total_p2;
}

fn parseLine(allocator: std.mem.Allocator, line: []const u8) !Machine {
    var key: std.ArrayList(u8) = .empty;
    var switches: std.ArrayList([]usize) = .empty;
    var joltage: std.ArrayList(usize) = .empty;

    var tokens = std.mem.tokenizeAny(u8, line, " ");
    while (tokens.next()) |token| {
        if (token[0] == '[') {
            for (token) |c| {
                if (c == '#') try key.append(allocator, 1) else if (c == '.') try key.append(allocator, 0);
            }
        } else if (token[0] == '(') {
            var sw = try allocator.alloc(usize, key.items.len);
            @memset(sw, 0);
            var nums = std.mem.tokenizeAny(u8, token, "(,) ");
            while (nums.next()) |n| {
                const idx = try std.fmt.parseInt(usize, n, 10);
                sw[idx] = 1;
            }
            try switches.append(allocator, sw);
        } else if (token[0] == '{') {
            var nums = std.mem.tokenizeAny(u8, token, "{,} ");
            while (nums.next()) |n| try joltage.append(allocator, try std.fmt.parseInt(usize, n, 10));
        }
    }
    return Machine.init(try key.toOwnedSlice(allocator), try switches.toOwnedSlice(allocator), try joltage.toOwnedSlice(allocator));
}

fn searchFreeVariables(
    matrix: []const [65]Rational,
    num_buttons: usize,
    num_pivots: usize,
    pivot_cols: []const i32,
    free_vars: []const usize,
    num_free: usize,
    bound: u64,
    free_vals: []u64,
    depth: usize,
    current_free_cost: u64,
    min_cost: *u64,
) void {
    if (current_free_cost >= min_cost.*) return;

    if (depth == num_free) {
        var solution = [_]i64{0} ** 64;
        for (0..num_free) |f| solution[free_vars[f]] = @intCast(free_vals[f]);

        var total_cost = current_free_cost;
        var row_idx = num_pivots;
        while (row_idx > 0) {
            row_idx -= 1;
            const col: usize = @intCast(pivot_cols[row_idx]);
            var val = matrix[row_idx][num_buttons];
            for (col + 1..num_buttons) |c| {
                val = val.sub(matrix[row_idx][c].mul(Rational.fromInt(solution[c])));
            }

            if (val.toInt()) |v| {
                if (v < 0) return;
                solution[col] = v;
                total_cost += @intCast(v);
                if (total_cost >= min_cost.*) return;
            } else return;
        }
        min_cost.* = total_cost;
        return;
    }

    const budget = if (min_cost.* > current_free_cost) min_cost.* - current_free_cost else 0;
    const this_bound = @min(bound, budget);

    var v: u64 = 0;
    while (v < this_bound) : (v += 1) {
        free_vals[depth] = v;
        searchFreeVariables(matrix, num_buttons, num_pivots, pivot_cols, free_vars, num_free, bound, free_vals, depth + 1, current_free_cost + v, min_cost);
        if (min_cost.* <= current_free_cost + v) break;
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
