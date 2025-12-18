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

const FreeVarInfo = struct {
    free_vars: []usize,
    constraints: [][]i64, // Each constraint is coefficients for free vars + constant
    allocator: std.mem.Allocator,

    fn deinit(self: *@This()) void {
        self.allocator.free(self.free_vars);
        for (self.constraints) |constraint| {
            self.allocator.free(constraint);
        }
        self.allocator.free(self.constraints);
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

fn identifyFreeVariables(allocator: std.mem.Allocator, matrix: Matrix) !FreeVarInfo {
    var free_vars: std.ArrayList(usize) = .empty;
    var constraints: std.ArrayList([]i64) = .empty;

    const num_switches = matrix.num_cols - 1;
    var has_pivot = try allocator.alloc(bool, num_switches);
    defer allocator.free(has_pivot);
    @memset(has_pivot, false);

    for (matrix.rows) |row| {
        for (0..num_switches) |col| {
            if (row[col] != 0) {
                has_pivot[col] = true;
                break; // Found the pivot for this row
            }
        }
    }

    for (0..num_switches) |col| {
        if (!has_pivot[col]) {
            try free_vars.append(allocator, col);
        }
    }

    // Identify rows that only contain free variables (constraints)
    if (free_vars.items.len > 0) {
        for (matrix.rows) |row| {
            var only_free_vars = true;
            var all_zero = true;
            for (0..num_switches) |col| {
                if (row[col] != 0) {
                    all_zero = false;
                    var is_free = false;
                    for (free_vars.items) |fv| {
                        if (fv == col) {
                            is_free = true;
                            break;
                        }
                    }
                    if (!is_free) {
                        only_free_vars = false;
                        break;
                    }
                }
            }

            if (only_free_vars and !all_zero) {
                var constraint = try allocator.alloc(i64, free_vars.items.len + 1);
                for (free_vars.items, 0..) |fv, idx| {
                    constraint[idx] = row[fv];
                }
                constraint[free_vars.items.len] = row[num_switches];
                try constraints.append(allocator, constraint);
            }
        }
    }

    return FreeVarInfo{
        .free_vars = try free_vars.toOwnedSlice(allocator),
        .constraints = try constraints.toOwnedSlice(allocator),
        .allocator = allocator,
    };
}

// Calculate total number of presses from a solution vector
fn calculateTotalPresses(switch_presses: []i64) usize {
    var total: usize = 0;
    for (switch_presses) |presses| {
        total += @intCast(presses);
    }
    return total;
}

// Find minimum number of presses by trying all combinations of free variables
fn findMinPresses(allocator: std.mem.Allocator, matrix: Matrix, free_info: FreeVarInfo) !usize {
    const free_vars = free_info.free_vars;
    const num_switches = matrix.num_cols - 1;
    const fixed_count = num_switches - free_vars.len;

    if (free_vars.len == 0) {
        var total_presses: i64 = 0;
        for (0..num_switches) |row| {
            const val = matrix.rows[row][num_switches];
            if (val < 0) return error.NoSolution;
            total_presses += val;
        }
        return @intCast(total_presses);
    }

    // Calculate costs
    var costs = try allocator.alloc(i64, free_vars.len);
    defer allocator.free(costs);
    for (free_vars, 0..) |fv, i| {
        var pivot_impact: i64 = 0;
        for (0..fixed_count) |row| {
            pivot_impact += matrix.rows[row][fv];
        }
        costs[i] = 1 - pivot_impact;
    }

    // Calculate limits
    const limits = try calculateDynamicLimits(allocator, matrix, free_vars);
    defer allocator.free(limits);

    // Initial presses from fixed variables
    var initial_presses: i64 = 0;
    for (0..fixed_count) |row| {
        initial_presses += matrix.rows[row][num_switches];
    }

    // Extract coefficients
    var coeffs = try allocator.alloc([]i64, free_vars.len);
    defer allocator.free(coeffs);
    for (free_vars, 0..) |fv, i| {
        coeffs[i] = try allocator.alloc(i64, matrix.num_rows);
        for (0..matrix.num_rows) |row| {
            coeffs[i][row] = matrix.rows[row][fv];
        }
    }
    defer for (coeffs) |c| allocator.free(c);

    // Initial RHS
    var rhs = try allocator.alloc([]i64, free_vars.len);
    defer {
        for (rhs) |r| allocator.free(r);
        allocator.free(rhs);
    }

    for (0..free_vars.len) |i| {
        rhs[i] = try allocator.alloc(i64, matrix.num_rows);
        for (0..matrix.num_rows) |row| {
            rhs[i][row] = matrix.rows[row][num_switches];
        }
    }

    const result = solveRecursive(costs, limits, coeffs, rhs, fixed_count, initial_presses, 0);
    return if (result) |res| @intCast(res) else error.NoSolution;
}

fn calculateDynamicLimits(allocator: std.mem.Allocator, matrix: Matrix, free_vars: []usize) ![]i64 {
    var limits = try allocator.alloc(i64, free_vars.len);
    const num_switches = matrix.num_cols - 1;

    for (free_vars, 0..) |fv_idx, i| {
        var min_limit: i64 = 1000;
        for (matrix.rows) |row| {
            const c = row[fv_idx];
            const r = row[num_switches];
            // If pivot_coeff * x_pivot + c * x_free = r
            // Since x_pivot >= 0 and pivot_coeff is 1, then c * x_free <= r
            if (c > 0) {
                const limit = @divTrunc(r, c);
                if (limit >= 0) min_limit = @min(min_limit, limit);
            }
        }
        limits[i] = min_limit;
    }
    return limits;
}

fn solveRecursive(
    costs: []const i64,
    limits: []const i64,
    coeffs: []const []i64,
    rhs: [][]i64,
    fixed: usize,
    presses: i64,
    depth: usize,
) ?i64 {
    const height = rhs[depth].len;
    const is_last = depth == coeffs.len - 1;

    if (is_last) {
        var lower: i64 = 0;
        var upper: i64 = limits[depth];

        // Check inequalities for all rows
        for (coeffs[depth], rhs[depth]) |coef, r| {
            if (r >= 0) {
                if (coef > 0) {
                    upper = @min(upper, @divFloor(r, coef));
                }
            } else if (coef < 0) {
                const floor = @divFloor(r + coef + 1, coef);
                lower = @max(lower, floor);
            } else {
                upper = -1;
            }
        }

        // Check equalities (rows beyond the fixed pivot rows)
        for (fixed..height) |row| {
            const c = coeffs[depth][row];
            const r = rhs[depth][row];

            if (c != 0) {
                if (@rem(r, c) == 0) {
                    const val = @divFloor(r, c);
                    upper = @min(upper, val);
                    lower = @max(lower, val);
                } else {
                    upper = -1;
                }
            }
        }

        if (lower > upper) return null;

        // Choose the value that minimizes total presses
        const x = if (costs[depth] >= 0) lower else upper;
        return presses + costs[depth] * x;
    } else {
        var min_result: ?i64 = null;
        var x: i64 = 0;

        while (x <= limits[depth]) : (x += 1) {
            const next_presses = presses + x * costs[depth];

            // Update RHS for next level
            for (0..height) |row| {
                rhs[depth + 1][row] = rhs[depth][row] - x * coeffs[depth][row];
            }

            if (solveRecursive(costs, limits, coeffs, rhs, fixed, next_presses, depth + 1)) |result| {
                if (min_result == null or result < min_result.?) {
                    min_result = result;
                }
            }
        }

        return min_result;
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
