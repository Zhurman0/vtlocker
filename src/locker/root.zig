const std   = @import("std");
const linux = std.os.linux;

const vtctl = @import("vtctl.zig");
const vt    = @import("vt.zig");
const pam   = @import("pam.zig");
// const ui = @import("ui");


var tty:   linux.fd_t  = -1;
var tty_modified: bool = false;
var epoll: linux.fd_t  = -1;


pub fn init(n: u32) !void {
    var path_buf: [16]u8 = undefined;
    const path = switch (n) {
        0 => "/dev/tty",
        1...15 => try std.fmt.bufPrintZ(&path_buf, "/dev/tty{d}", .{n}),
        else => return error.UnsupportedTTY,
    };


    tty = @intCast(linux.open(path, .{
        .ACCMODE = .RDWR,
        .NONBLOCK = true,
    }, 0));
    if (tty < 0) return error.VTOpenFailed;

    try vtctl.setVT(n, tty);
    tty_modified = true;

    try vtctl.initSignals();


    epoll = @intCast(linux.epoll_create1(linux.EPOLL.CLOEXEC));
    if (epoll < 0) return error.EpollCreateFailed;
    
    const ret: isize = @intCast(linux.epoll_ctl(
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

pub fn deinit() void {
    if (tty_modified) vtctl.setAuto(tty) catch {};
    if (tty > -1)   _ = linux.close(tty);
    if (epoll > -1) _ = linux.close(epoll);
}
