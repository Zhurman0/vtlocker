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
    
    const ret = linux.ioctl(fd, @intFromEnum(vt.Ioctl.GETSTATE), @intFromPtr(&st));
    if (ret & (1 << (@bitSizeOf(usize) - 1)) != 0) return error.GetStateFailed;
        
    return st.active;
}

pub fn setProcess(fd: linux.fd_t) !void {
    var mode_c: vt.CMode = undefined;
    
    const ret = linux.ioctl(fd, vt.Ioctl.GETMODE, @intFromPtr(&mode_c));
    if (ret & (1 << (@bitSizeOf(usize) - 1)) != 0) return error.GetModeFailed;

    var mode = vt.Mode.fromC(mode_c);
    mode.kind   = .PROCESS;
    mode.waitv  = 0;
    mode.relsig = linux.SIG.USR1;
    mode.acqsig = linux.SIG.USR2;

    _ = linux.ioctl(fd, @intFromEnum(vt.Ioctl.SETMODE), @intFromPtr(&mode.toC()));
}

pub fn setAuto(fd: linux.fd_t) !void {
    var mode_c: vt.CMode = undefined;
    
    const ret = linux.ioctl(fd, @intFromEnum(vt.Ioctl.GETMODE), @intFromPtr(&mode_c));
    if (ret & (1 << (@bitSizeOf(usize) - 1)) != 0) return error.GetStateFailed;

    var mode = vt.Mode.fromC(mode_c);
    mode.kind = .AUTO;

    _ = linux.ioctl(fd, @intFromEnum(vt.Ioctl.SETMODE), @intFromPtr(&mode.toC()));
}

pub fn denySwitch(fd: linux.fd_t) !void {
    _ = linux.ioctl(fd, @intFromEnum(vt.Ioctl.RELDISP), 0);
}
