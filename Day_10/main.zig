const std = @import("std");

const Machine = struct {
    key: u8,
    switches: []u8,
    joltage: []const u8,

    fn init(key: u8, switches: []u8, joltage: []const u8) Machine {
        return .{ .key = key, .switches = switches, .joltage = joltage };
    }

    fn deinit(self: *Machine, allocator: std.mem.Allocator) void {
        allocator.free(self.switches);
    }

    fn printMachine(self: Machine) void {
        std.debug.print("Key = 0b{b}\n", .{self.key});
        for (self.switches) |sw| {
            std.debug.print("\tSwitch = 0b{b}\n", .{sw});
        }
        std.debug.print("\tJoltage = {s}\n", .{self.joltage});
    }

    fn findMinPresses(self: Machine, allocator: std.mem.Allocator) !?usize {
        // BFS state: (current_value, num_presses)
        const State = struct {
            value: u8,
            presses: usize,
        };

        var queue: std.ArrayList(State) = .empty;
        defer queue.deinit(allocator);

        var visited = std.AutoHashMap(u8, void).init(allocator);
        defer visited.deinit();

        // Start at 0 with 0 presses
        try queue.append(allocator, .{ .value = 0, .presses = 0 });
        try visited.put(0, {});

        while (queue.items.len > 0) {
            const current = queue.orderedRemove(0);

            // Check if we've reached the key
            if (current.value == self.key) {
                return current.presses;
            }

            // Try pressing each switch
            for (self.switches) |sw| {
                const next_value = current.value ^ sw;

                // If we haven't visited this state, add it to the queue
                if (!visited.contains(next_value)) {
                    try visited.put(next_value, {});
                    try queue.append(allocator, .{
                        .value = next_value,
                        .presses = current.presses + 1,
                    });
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
        var key: u8 = 0;
        var switches: std.ArrayList(u8) = .empty;
        defer _ = switches.deinit(allocator);
        var joltage: []const u8 = "";
        var values = std.mem.splitScalar(u8, line, ' ');
        while (values.next()) |value| {
            const symbol = value[0];
            const cleaned_value = std.mem.trim(u8, value, "{}()[]");
            switch (symbol) {
                '[' => {
                    for (cleaned_value, 0..) |char, i| {
                        if (char == '#') {
                            key = key | (@as(u8, 1) << @as(u3, @intCast(i)));
                        }
                    }
                },
                '(' => {
                    var sw: u8 = 0;
                    var indexes = std.mem.splitScalar(u8, cleaned_value, ',');
                    while (indexes.next()) |index| {
                        const idx = try std.fmt.parseInt(u8, index, 10);
                        sw = sw | (@as(u8, 1) << @as(u3, @intCast(idx)));
                    }
                    try switches.append(allocator, sw);
                },
                '{' => {
                    joltage = cleaned_value;
                },
                else => {
                    std.debug.panic("unknown value: {c} in line {s}", .{ symbol, cleaned_value });
                },
            }
        }
        try machines.append(allocator, Machine.init(key, try switches.toOwnedSlice(allocator), joltage));
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
