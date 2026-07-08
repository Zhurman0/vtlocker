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


pub fn deinit() void {
    if (tty_modified) vtctl.setAuto(tty) catch {};
    if (tty > -1)   _ = linux.close(tty);
    if (epoll > -1) _ = linux.close(epoll);
}
