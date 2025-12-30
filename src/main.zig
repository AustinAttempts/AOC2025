const std = @import("std");
const AOC2025 = @import("AOC2025");

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    std.debug.print("\n╔══════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                      🎄 Advent of Code 2025 🎄                           ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════════════════╝\n\n", .{});
    try AOC2025.day01.solve();
    try AOC2025.day02.solve();
    try AOC2025.day03.solve();
    try AOC2025.day04.solve();
    try AOC2025.day05.solve();
    try AOC2025.day06.solve();
    try AOC2025.day07.solve();
    try AOC2025.day08.solve();
    try AOC2025.day09.solve();
    try AOC2025.day10.solve();
    try AOC2025.day11.solve();
    try AOC2025.day12.solve();
}
