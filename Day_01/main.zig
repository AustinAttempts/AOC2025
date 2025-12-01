const std = @import("std");

pub fn main() !void {
    std.debug.print("Hello, World!\n", .{});
}

test "always succeeds" {
    try std.testing.expect(true);
}
