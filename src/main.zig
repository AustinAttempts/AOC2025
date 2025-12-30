const std = @import("std");
const AOC2025 = @import("AOC2025");

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    std.debug.print("Advent of Code 2025:\n", .{});
    try AOC2025.day01.solve();
}
