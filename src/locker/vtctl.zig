const std   = @import("std");
const linux = std.os.linux;

const vt    = @import("vt.zig");


pub var relsig_pending = std.atomic.Value(bool).init(false);
pub var acqsig_pending = std.atomic.Value(bool).init(false);

fn handle_relsig(_: linux.SIG) callconv(.c) void {
    relsig_pending.store(true, .seq_cst);
}

fn handle_acqsig(_: linux.SIG) callconv(.c) void {
    acqsig_pending.store(true, .seq_cst);
}


pub fn initSignals() !void {
    var sa_rel: linux.Sigaction = .{
        .handler = .{ .handler = handle_relsig },
        .flags   = linux.SA.RESTART,
        .mask    = linux.sigemptyset(),
    };
    if (linux.sigaction(linux.SIG.USR1, &sa_rel, null) != 0) return error.SigAction1Failed;

    var sa_acq: linux.Sigaction = .{
        .handler = .{ .handler = handle_acqsig },
        .flags   = linux.SA.RESTART,
        .mask    = linux.sigemptyset(),
    };
    if (linux.sigaction(linux.SIG.USR1, &sa_acq, null) != 0) return error.SigAction2Failed;
}

pub fn getActiveVT(fd: linux.fd_t) !u16 {
    var st: vt.Stat = undefined;
    
    if (vt.ioctl(fd, .GETSTATE, @intFromPtr(&st)) < 0) return error.GetStateFailed;
        
    return st.active;
}

pub fn setVT(n: u32, fd: linux.fd_t) !void {
    var mode = vt.SetActivate{
        .console = switch (n) {
            0    => try getActiveVT(fd),
            else => n,
        },
        .mode    = vt.Mode{
            .kind   = .PROCESS,
            .waitv  = 0,
            .relsig = @intFromEnum(linux.SIG.USR1),
            .acqsig = @intFromEnum(linux.SIG.USR2),
        },
    };

    if (vt.ioctl(fd, .SETACTIVATE, @intFromPtr(&mode)) < 0) return error.SetActivateFailed;
}

pub fn setAuto(fd: linux.fd_t) !void {
    var mode: vt.Mode = undefined;
    const ptr = @intFromPtr(&mode);
    
    if (vt.ioctl(fd, .GETMODE, ptr) < 0) return error.GetStateFailed;

    mode.kind = .AUTO;
    _ = vt.ioctl(fd, .SETMODE, ptr);
}

pub fn denySwitch(fd: linux.fd_t) !void {
    _ = vt.ioctl(fd, .RELDISP, 0);
}
