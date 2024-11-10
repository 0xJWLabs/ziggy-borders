const std = @import("std");
const win32 = @import("win32");
const regex = @import("regex");
const utils = @import("./utils.zig");

const everything = win32.everything;
const zig = win32.zig;

const BOOL = everything.BOOL;
const D2D1_COLOR_F = everything.D2D_COLOR_F;
const D2D1_GRADIENT_STOP = everything.D2D1_GRADIENT_STOP;
const DwmGetColorizationColor = everything.DwmGetColorizationColor;
const FALSE = zig.FALSE;

const FLAG_IGNORECASE = regex.FLAG_IGNORECASE;

pub const GradientDirection = union(enum) {
    String: []const u8, // equivalent to `String(String)` in Rust
    Map: GradientDirectionCoordinates, // equivalent to `Map(GradientDirectionCoordinates)` in Rust
};

pub const GradientDirectionCoordinates = struct { start: [2]f32, end: [2]f32 };

pub const GradientDefinition = struct {
    colors: []const u8, // For simplicity, using `[]const u8` here; adjust as needed
    direction: GradientDirection,
    animation: ?bool, // Optional bool in Zig
};

// Gradient struct
pub const Gradient = struct {
    direction: ?[]f32, // Optional vector of floats
    gradient_stops: []D2D1_GRADIENT_STOP, // Array of gradient stops
    animation: ?bool, // Optional bool in Zig
};

// Color enum (Solid or Gradient)
pub const Color = union(enum) {
    Solid: D2D1_COLOR_F,
    Gradient: Gradient,
};

const DefaultColor = D2D1_COLOR_F{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 };

fn get_accent_color() D2D1_COLOR_F {
    const pcr_colorization: u32 = 0;
    const pf_opaqueblend: BOOL = FALSE;

    const result = DwmGetColorizationColor(&pcr_colorization, &pf_opaqueblend);
    if (result < 0) {
        std.debug.print("Error getting accent color, error code: {}\n", .{result});
        return DefaultColor;
    }

    const red = @as(f32, @floatFromInt(((pcr_colorization & 0x00FF0000) >> 16))) / 255.0;
    const green = @as(f32, @floatFromInt(((pcr_colorization & 0x0000FF00) >> 8))) / 255.0;
    const blue = @as(f32, @floatFromInt((pcr_colorization & 0x000000FF))) / 255.0;

    return D2D1_COLOR_F{ .r = red, .g = green, .b = blue, .a = 1.0 };
}

fn is_direction(direction: []const u8) bool {
    const directions = [8][]const u8{ "to right", "to left", "to top", "to bottom", "to top right", "to top left", "to bottom right", "to bottom left" };

    for (directions) |dir| {
        if (std.mem.eql(u8, direction, dir)) {
            return true;
        }
    }

    return false;
}

fn get_color(color: []const u8) D2D1_COLOR_F {
    if (std.mem.eql(u8, color, "accent")) {
        return get_accent_color();
    } else if (std.mem.startsWith(u8, color, "rgb(") || std.mem.startsWith(u8, color, "rgba(")) {}
}

fn get_color_from_hex(hex: []const u8) !D2D1_COLOR_F {
    // Ensure the hex string starts with '#' and is of the correct length
    if (!(hex.len == 4 or hex.len == 5 or hex.len == 7 or hex.len == 9) or hex[0] != '#') {
        return error.InvalidHexFormat;
    }

    var expanded_hex: [9]u8 = "#000000FF"; // Default to opaque black

    switch (hex.len) {
        4 => {
            // Expand #RGB to #RRGGBB
            expanded_hex[1] = hex[1];
            expanded_hex[2] = hex[1];
            expanded_hex[3] = hex[2];
            expanded_hex[4] = hex[2];
            expanded_hex[5] = hex[3];
            expanded_hex[6] = hex[3];
        },
        5 => {
            // Expand #RGBA to #RRGGBBAA
            expanded_hex[1] = hex[1];
            expanded_hex[2] = hex[1];
            expanded_hex[3] = hex[2];
            expanded_hex[4] = hex[2];
            expanded_hex[5] = hex[3];
            expanded_hex[6] = hex[3];
            expanded_hex[7] = hex[4];
            expanded_hex[8] = hex[4];
        },
        7 => {
            std.mem.copy(u8, expanded_hex[0..7], hex[0..7]);
        },
        9 => {
            std.mem.copy(u8, expanded_hex[0..9], hex[0..9]);
        },
        else => unreachable, // Already validated lengths above
    }

    // Helper function to convert two hex chars to an f32 between 0 and 1

    const r = @as(f32, @floatFromInt(std.fmt.parseInt(u8, expanded_hex[1..3], 16, {}))) / 255.0;
    const g = @as(f32, @floatFromInt(std.fmt.parseInt(u8, expanded_hex[3..5], 16, {}))) / 255.0;
    const b = @as(f32, @floatFromInt(std.fmt.parseInt(u8, expanded_hex[5..7], 16, {}))) / 255.0;
    const a = @as(f32, @floatFromInt(std.fmt.parseInt(u8, expanded_hex[7..9], 16, {}))) / 255.0;

    // Parse RGB and Alpha values
    return D2D1_COLOR_F{
        .r = r,
        .g = g,
        .b = b,
        .a = a,
    };
}

pub fn get_color_from_rgba(color: []const u8) D2D1_COLOR_F {
    var rgba_trimmed: []const u8 = color;

    if (std.mem.startsWith(u8, color, "rgb(")) {
        rgba_trimmed = color[4..];
    } else if (std.mem.startsWith(u8, color, "rgba(")) {
        rgba_trimmed = color[5..];
    }

    rgba_trimmed = std.mem.trim(u8, rgba_trimmed, ")");

    const components: []std.mem.SplitIterator(u8) = std.mem.split(u8, rgba_trimmed, ',');
    if (components.len != 3 and components.len != 4) {
        return D2D1_COLOR_F{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 }; // Default color on failure
    }

    const r: f32 = try @as(f32, @floatFromInt(std.fmt.parseInt(u32, components[0], 10))) / 255.0 catch 0.0;
    const g: f32 = try @as(f32, @floatFromInt(std.fmt.parseInt(u32, components[1], 10))) / 255.0 catch 0.0;
    const b: f32 = try @as(f32, @floatFromInt(std.fmt.parseInt(u32, components[2], 10))) / 255.0 catch 0.0;
    var a: f32 = undefined;

    if (components.len == 4) {
        a = try @as(f32, @floatFromInt(std.fmt.parseInt(u32, components[3], 10))) / 255.0 catch 0.0;
    } else {
        a = 1.0;
    }

    return D2D1_COLOR_F{ .r = r, .g = g, .b = b, .a = a };
}

pub fn parse_color_string(color: []const u8) !void {
    const allocator = std.heap.page_allocator;

    if (std.mem.startsWith(u8, color, "gradient(") and std.mem.endsWith(u8, color, ")")) {
        return parse_color_string(color[9 .. color.len - 1]); // Recursively parse gradient content
    }

    const rePattern = "#[0-9A-F]{3,8}|rgba?\\([0-9]{1,3},\\s*[0-9]{1,3},\\s*[0-9]{1,3}(?:,\\s*[0-9]*(?:\\.[0-9]+)?)?\\)|accent|transparent";

    var re = try regex.Regex.compile(allocator, rePattern, FLAG_IGNORECASE);
    defer re.deinit();

    const captures = try re.capturesAlloc(allocator, color, true);
    defer regex.Regex.freeCaptures(allocator, captures);

    var colors_vec = std.ArrayList([]const u8).init(allocator);
    defer colors_vec.deinit();

    for (captures) |capture| {
        const groups = capture.groups;
        for (groups) |str| {
            try colors_vec.append(str.slice);
        }
    }

    for (colors_vec.items) |color_item| {
        std.debug.print("Captured color: {s}\n", .{color_item});
    }

    const last_color = colors_vec.getLast();
    const start_pos = std.mem.indexOf(u8, color, last_color) orelse @as(usize, 0);
    if (start_pos != 0) {
        const rest = std.mem.trim(u8, color[(start_pos + last_color.len)..], " ");
        var rest_of_input_array = std.ArrayList([]const u8).init(allocator);
        defer rest_of_input_array.deinit();

        var iter = std.mem.split(u8, rest, ",");

        while (iter.next()) |part| {
            const trimmed = std.mem.trim(u8, part, " ");
            if (trimmed.len > 0) try rest_of_input_array.append(trimmed);
        }

        var direction: ?[]const u8 = null;
        var animation: bool = false;

        for (rest_of_input_array.items) |str| {
            if (std.mem.eql(u8, str, "true") or std.mem.eql(u8, str, "false")) {
                animation = utils.str_to_bool(str);
            } else if (is_direction(str) and direction == null) {
                direction = str;
            }
        }

        // Debug output to verify the parsed values
        if (animation) {
            std.debug.print("Animation: true\n", .{});
        } else {
            std.debug.print("Animation: false\n", .{});
        }

        if (direction) |d| {
            std.debug.print("Direction: {s}\n", .{d});
        } else {
            std.debug.print("Direction: None\n", .{});
        }
    }
}
