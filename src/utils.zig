const std = @import("std");

pub fn str_to_bool(str: []const u8) bool {
    return std.mem.eql(u8, str, "true");
}
