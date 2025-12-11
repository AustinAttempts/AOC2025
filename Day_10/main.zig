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

    return 0;
}

test "part 1" {
    const input = @embedFile("inputs/test_case.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\nRunning part 1 test...\n", .{});
    try std.testing.expectEqual(7, try part1(allocator, input));
}
