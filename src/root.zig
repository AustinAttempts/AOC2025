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

test {
    std.testing.refAllDecls(@This());
    _ = @import("puzzles/day01.zig");
    _ = @import("puzzles/day02.zig");
    _ = @import("puzzles/day03.zig");
    _ = @import("puzzles/day04.zig");
    _ = @import("puzzles/day05.zig");
}
