const std = @import("std");
const regex = @import("regex");
const colors = @import("./colors.zig");

pub fn main() !void {
    try colors.parse_color_string("gradient(#89b4fa, #89b4faff, rgb(203, 166, 247), rgba(203, 166, 247, 1), to right, true)");
}
