const std = @import("std");
const locker = @import("locker");


fn parseArgs(argv: []const []const u8) !Args {
    var result = Args{};
    var skip = false;

    for (1..argv.len) |i| {
        if (skip) {
            skip = false;
            continue;
        }

        const arg = argv[i];

        // flags
        if (arg[0] == '-' and arg.len > 1) {

            // help
            if (arg[1] == 'h' or std.mem.eql(u8, arg, "--help")) {
                result.help = true;

            // mask character
            } else if (arg[1] == 'm' or std.mem.eql(u8, arg, "--mask")) {
                if (i + 1 >= argv.len) return error.MissingFlagValue;

                const m = argv[i + 1];
                if (m.len != 1) return error.InvalidMaskChar;

                result.mask = m[0];

                skip = true;

            } else {
                std.log.warn("Unknown flag: {s}", .{arg});
                result.help = true;
            }

        // positional argument: tty number
        } else {
            if (result.tty != 0) {
                std.log.warn("Unexpected extra positional argument: {s}", .{arg});
            } else {
                result.tty  = std.fmt.parseInt(u32, arg, 10) catch |err| switch (err) {
                    error.InvalidCharacter => return error.IntegerExpected,

                    else => return err,
                };
            }
        }
    }

    return result;
}


const Args = struct {
    help: bool = false,
    tty:  u32  = 0,     // 0 -> no tty specified
    mask: u8   = 0,     // '\0' -> no mask
};

const helpmsg =
    \\Usage: vtlocker [TTY] [options]
    \\
    \\TTY:  Virtual console number to activate (1..15)
    \\      If omitted, vtlocker works on the current console
    \\
    \\Options:
    \\  -m / --mask CHAR      Mask character for password input (Default: none)
    \\  -h / --help           Show help message
    \\
;


pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;

    const stdout = @constCast(&std.Io.File.stdout().writer(io, &[_]u8{}).interface);


    const argv = try init.minimal.args.toSlice(arena);
    const args = blk: {
        break :blk parseArgs(argv) catch |err| {
            std.log.err("{s}", .{ @errorName(err) });
            break :blk Args{ .help = true };
        };
    };

    if (args.help) {
        try stdout.writeAll(helpmsg);
        return;
    }


    locker.init(args.tty) catch |err| {
        std.log.err("{s}", .{ @errorName(err) });
        locker.deinit();
        return;
    };

    try stdout.writeAll("State: LOCKED (wait 10 sec)\n");
    try io.sleep(.fromSeconds(10), .real);
    
    locker.deinit();
    try stdout.writeAll("State: UNLOCKED\n");
}


test "argsParseTest: empty args" {
    const args = try parseArgs(&.{ "bin" });

    try std.testing.expectEqual(false, args.help);
    try std.testing.expectEqual(@as(u32, 0), args.tty);
    try std.testing.expectEqual(@as(u8, 0), args.mask);
}

test "argsParseTest: tty positional" {
    const args = try parseArgs(&.{ "bin", "6" });

    try std.testing.expectEqual(@as(u32, 6), args.tty);
    try std.testing.expectEqual(@as(u8, 0), args.mask);
}

test "argsParseTest: mask short flag" {
    const args = try parseArgs(&.{
        "bin",
        "-M", "*",
    });

    try std.testing.expectEqual(@as(u32, 0), args.tty);
    try std.testing.expectEqual(@as(u8, '*'), args.mask);
}

test "argsParseTest: mask long flag" {
    const args = try parseArgs(&.{
        "bin",
        "--mask", "#",
    });

    try std.testing.expectEqual(@as(u32, 0), args.tty);
    try std.testing.expectEqual(@as(u8, '#'), args.mask);
}

test "argsParseTest: tty + mask" {
    const args = try parseArgs(&.{
        "bin",
        "3",
        "--mask", "@",
    });

    try std.testing.expectEqual(@as(u32, 3), args.tty);
    try std.testing.expectEqual(@as(u8, '@'), args.mask);
}

test "argsParseTest: help flag" {
    const args = try parseArgs(&.{
        "bin",
        "--help",
    });

    try std.testing.expectEqual(true, args.help);
    try std.testing.expectEqual(@as(u32, 0), args.tty);
    try std.testing.expectEqual(@as(u8, 0), args.mask);
}

test "argsParseTest: mask flag without value" {
    try std.testing.expectError(error.MissingFlagValue, parseArgs(&.{
        "bin",
        "--mask",
    }));
}

test "argsParseTest: mask flag with empty string" {
    try std.testing.expectError(error.InvalidMaskChar, parseArgs(&.{
        "bin",
        "--mask", "",
    }));
}

test "argsParseTest: mask flag with too long string" {
    try std.testing.expectError(error.InvalidMaskChar, parseArgs(&.{
        "bin",
        "--mask", "xx",
    }));
}
