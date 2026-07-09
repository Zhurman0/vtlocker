const std   = @import("std");
const linux = std.os.linux;

const vtctl = @import("vtctl.zig");
const vt    = @import("vt.zig");
const pam   = @import("pam.zig");
// const ui = @import("ui");


var tty:   linux.fd_t  = -1;
var tty_modified: bool = false;
var epoll: linux.fd_t  = -1;


pub fn init() !void {
    var ret: isize = undefined;

    
    ret = @bitCast(linux.open("/dev/tty", .{
        .ACCMODE = .RDWR,
        .NONBLOCK = true,
    }, 0));
    if (ret < 0) return error.VTOpenFailed;
    tty = @intCast(ret);

    try vtctl.initSignals();
    try vtctl.setProcess(tty);
    tty_modified = true;


    ret = @bitCast(linux.epoll_create1(linux.EPOLL.CLOEXEC));
    if (ret < 0) return error.EpollCreateFailed;
    epoll = @intCast(ret);
    
    ret = @bitCast(linux.epoll_ctl(
        epoll,
        linux.EPOLL.CTL_ADD,
        tty,
        @constCast(&linux.epoll_event{
            .events = linux.EPOLL.IN,
            .data = .{ .fd = tty },
        }),
    ));
    if (ret < 0) return error.EpollAddFailed;
}


pub fn run(stdout: *std.Io.Writer) !void {
    while (true) {
        var ctx = pam.ConvContext { .user = null, .pass = null };

        try stdout.writeAll("Login: ");
        var user_buf: [64]u8 = [_]u8{ 0 } ** 64;
        const user = try readLineEpoll(epoll, tty, user_buf[0..]);
        if (user.len == 0) continue;

        try stdout.writeAll("Password: ");
        var pass_buf: [64]u8 = [_]u8{ 0 } ** 64;
        const password = try readLineEpoll(epoll, tty, pass_buf[0..]);
        if (password.len == 0) continue;


        ctx = .{
            .user = @as([*:0]u8, @ptrCast(&user_buf)),
            .pass = &pass_buf,
        };

        const ok = pam.auth(&ctx) catch |err| {
            std.log.err("{s}", .{ @errorName(err) });
            continue;
        };

        if (ok) {
            try stdout.writeAll("auth ok\n",);
            break;
        } else {
            try stdout.writeAll("auth failed\n");
            if (ctx.last_msg) |msg| {
                try stdout.print("pam {s}: {s}\n", .{ @tagName(msg.style), msg.text });
            }
        }
    }
}



pub fn deinit() void {
    if (tty_modified) vtctl.setAuto(tty) catch {};
    if (tty > -1)   _ = linux.close(tty);
    if (epoll > -1) _ = linux.close(epoll);
}


fn readLineEpoll(epoll_fd: linux.fd_t, tty_fd: linux.fd_t, buf: []u8) ![]u8 {
    var len: usize = 0;
    var events: [4]linux.epoll_event = undefined;

    while (true) {
        const n: isize = @bitCast(linux.epoll_wait(epoll_fd, &events, events.len, -1));
        if (n <= 0) continue;


        var tmp: [16]u8 = undefined;
        const r = try std.posix.read(tty_fd, &tmp);

        for (tmp[0..r]) |b| {
            switch (b) {
                '\r', '\n' => return buf[0..len],
                0x7f       => { if (len > 0) len -= 1; },

                else => {
                    if (len < buf.len) {
                        buf[len] = b;
                        len += 1;
                    }
                },
            }
        }
    }
}
