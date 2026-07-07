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


    var req = vt.SetActivate{
        .console = switch (n) {
            0    => try vtctl.getActiveVT(tty),
            else => n,
        },
        .mode    = @constCast(&vt.Mode{
            .kind   = .PROCESS,
            .waitv  = 0,
            .relsig = @intFromEnum(linux.SIG.USR1),
            .acqsig = @intFromEnum(linux.SIG.USR2),
        }).toC(),
    };
    var ret = linux.ioctl(tty, @intFromEnum(vt.Ioctl.SETACTIVATE), @intFromPtr(&req));
    if (ret & (1 << (@bitSizeOf(usize) - 1)) != 0) return error.SetActivateFailed;

    tty_modified = true;

    try vtctl.initSignals();


    epoll = @intCast(linux.epoll_create1(linux.EPOLL.CLOEXEC));
    if (epoll < 0) return error.EpollCreateFailed;
    
    ret = linux.epoll_ctl(epoll, linux.EPOLL.CTL_ADD, tty, @constCast(&linux.epoll_event{
        .events = linux.EPOLL.IN,
        .data = .{ .fd = tty },
    }));
    if (ret & (1 << (@bitSizeOf(usize) - 1)) != 0) return error.EpollAddFailed;
}

pub fn deinit() void {
    if (tty_modified) vtctl.setAuto(tty) catch {};
    if (tty > 0)   _ = linux.close(epoll);
    if (epoll > 0) _ = linux.close(tty);
}
