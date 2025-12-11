const std = @import("std");

const Machine = struct {
    key: []bool,
    switches: [][]usize,
    joltage: []const u8,

    fn init(key: []bool, switches: [][]usize, joltage: []const u8) Machine {
        return .{ .key = key, .switches = switches, .joltage = joltage };
    }

    fn deinit(self: *Machine, allocator: std.mem.Allocator) void {
        allocator.free(self.key);
        for (self.switches) |sw| {
            allocator.free(sw);
        }
        allocator.free(self.switches);
    }

    fn printMachine(self: Machine) void {
        std.debug.print("Machine:\n", .{});
        std.debug.print("\tKey: ", .{});
        for (self.key) |light| {
            if (light) {
                std.debug.print("#", .{});
            } else {
                std.debug.print(".", .{});
            }
        }
        std.debug.print("\n", .{});

        std.debug.print("\tSwitches: ", .{});
        for (self.switches) |sws| {
            std.debug.print("(", .{});
            for (sws) |sw| {
                std.debug.print("{d} ", .{sw});
            }
            std.debug.print(") ", .{});
        }
        std.debug.print("\n", .{});

        std.debug.print("\tJoltage = {s}\n", .{self.joltage});
    }

    fn findMinPresses(self: Machine, allocator: std.mem.Allocator) !?usize {
        const State = struct {
            lights: []bool,
            presses: usize,

            fn hash(s: @This()) u64 {
                var hasher = std.hash.Wyhash.init(0);
                hasher.update(std.mem.sliceAsBytes(s.lights));
                return hasher.final();
            }

            fn eql(a: @This(), b: @This()) bool {
                return std.mem.eql(bool, a.lights, b.lights);
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

        var queue: std.ArrayList(State) = .empty;
        defer {
            for (queue.items) |state| {
                allocator.free(state.lights);
            }
            queue.deinit(allocator);
        }

        var visited = std.HashMap(State, void, HashContext, std.hash_map.default_max_load_percentage).init(allocator);
        defer {
            var iter = visited.keyIterator();
            while (iter.next()) |key| {
                allocator.free(key.lights);
            }
            visited.deinit();
        }

        // Start with all lights off (all false)
        const start_lights = try allocator.alloc(bool, self.key.len);
        @memset(start_lights, false);

        const start_state = State{ .lights = start_lights, .presses = 0 };
        try queue.append(allocator, start_state);

        const visited_start = try allocator.alloc(bool, self.key.len);
        @memcpy(visited_start, start_lights);
        try visited.put(State{ .lights = visited_start, .presses = 0 }, {});

        while (queue.items.len > 0) {
            const current = queue.orderedRemove(0);
            defer allocator.free(current.lights);

            // Check if we've reached the key
            if (std.mem.eql(bool, current.lights, self.key)) {
                return current.presses;
            }

            // Try pressing each switch
            for (self.switches) |switch_indices| {
                // Clone current state
                const next_lights = try allocator.alloc(bool, self.key.len);
                @memcpy(next_lights, current.lights);

                // Toggle the lights affected by this switch
                for (switch_indices) |idx| {
                    next_lights[idx] = !next_lights[idx];
                }

                // Check if we've visited this state
                var found = false;
                var iter = visited.keyIterator();
                while (iter.next()) |key| {
                    if (std.mem.eql(bool, key.lights, next_lights)) {
                        found = true;
                        break;
                    }
                }

                if (!found) {
                    const visited_lights = try allocator.alloc(bool, self.key.len);
                    @memcpy(visited_lights, next_lights);
                    try visited.put(State{ .lights = visited_lights, .presses = 0 }, {});

                    try queue.append(allocator, State{
                        .lights = next_lights,
                        .presses = current.presses + 1,
                    });
                } else {
                    allocator.free(next_lights);
                }
            }
        }

        // No solution found
        return null;
    }
};

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("inputs/day10.txt");
    std.debug.print("Part 1 Answer: {d}\n", .{try part1(allocator, input)});

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
        var key: std.ArrayList(bool) = .empty;
        defer _ = key.deinit(allocator);
        var switches: std.ArrayList([]usize) = .empty;
        defer _ = switches.deinit(allocator);
        var joltage: []const u8 = "";

        var values = std.mem.splitScalar(u8, line, ' ');
        while (values.next()) |value| {
            const symbol = value[0];
            const cleaned_value = std.mem.trim(u8, value, "{}()[]");
            switch (symbol) {
                '[' => {
                    for (cleaned_value) |char| {
                        if (char == '#') {
                            try key.append(allocator, true);
                        } else {
                            try key.append(allocator, false);
                        }
                    }
                },
                '(' => {
                    var sw: std.ArrayList(usize) = .empty;
                    defer _ = sw.deinit(allocator);

                    var indexes = std.mem.splitScalar(u8, cleaned_value, ',');
                    while (indexes.next()) |index| {
                        const idx = try std.fmt.parseInt(u8, index, 10);
                        try sw.append(allocator, idx);
                    }
                    try switches.append(allocator, try sw.toOwnedSlice(allocator));
                },
                '{' => {
                    joltage = cleaned_value;
                },
                else => {
                    std.debug.panic("unknown value: {c} in line {s}", .{ symbol, cleaned_value });
                },
            }
        }
        try machines.append(allocator, Machine.init(try key.toOwnedSlice(allocator), try switches.toOwnedSlice(allocator), joltage));
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

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\nRunning part 1 test...\n", .{});
    try std.testing.expectEqual(7, try part1(allocator, input));
}
