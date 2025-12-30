//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

pub const day01 = @import("puzzles/day01.zig");

test {
    std.testing.refAllDecls(@This());
    _ = @import("puzzles/day01.zig");
}
