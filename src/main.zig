const std = @import("std");
const AOC2025 = @import("AOC2025");

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    std.debug.print("Advent of Code 2025:\n", .{});
    try AOC2025.day01.solve();
    try AOC2025.day02.solve();
    try AOC2025.day03.solve();
    try AOC2025.day04.solve();
}
