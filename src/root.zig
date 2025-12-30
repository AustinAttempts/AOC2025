//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

// Shared Solution type
pub const Solution = struct {
    part1: usize,
    part2: usize,
};

pub const day01 = @import("puzzles/day01.zig");
pub const day02 = @import("puzzles/day02.zig");
pub const day03 = @import("puzzles/day03.zig");
pub const day04 = @import("puzzles/day04.zig");
pub const day05 = @import("puzzles/day05.zig");
pub const day06 = @import("puzzles/day06.zig");
pub const day07 = @import("puzzles/day07.zig");
pub const day08 = @import("puzzles/day08.zig");
pub const day09 = @import("puzzles/day09.zig");
pub const day10 = @import("puzzles/day10.zig");
pub const day11 = @import("puzzles/day11.zig");
pub const day12 = @import("puzzles/day12.zig");

test {
    std.testing.refAllDecls(@This());
    _ = @import("puzzles/day01.zig");
    _ = @import("puzzles/day02.zig");
    _ = @import("puzzles/day03.zig");
    _ = @import("puzzles/day04.zig");
    _ = @import("puzzles/day05.zig");
    _ = @import("puzzles/day06.zig");
    _ = @import("puzzles/day07.zig");
    _ = @import("puzzles/day08.zig");
    _ = @import("puzzles/day09.zig");
    _ = @import("puzzles/day10.zig");
    _ = @import("puzzles/day11.zig");
    _ = @import("puzzles/day12.zig");
}
