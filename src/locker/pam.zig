const std = @import("std");


pub const MsgStyle = enum(c_int) {
    PROMPT_ECHO_OFF = 1,
    PROMPT_ECHO_ON  = 2,
    ERROR_MSG       = 3,
    TEXT_INFO       = 4,
};

pub const Message = struct {
    style: MsgStyle,
    text:  []const u8,
};

pub const Result = struct {
    ok: bool,
    last_msg: ?Message,
};


const c = struct {
    pub const pam_handle_t = opaque {};

    pub const pam_message = extern struct {
        msg_style: c_int,
        msg: ?[*:0]const u8,
    };

    pub const pam_response = extern struct {
        resp: ?[*:0]u8,
        resp_retcode: c_int,
    };

    pub const pam_conv = extern struct {
        conv: ?*fn (
            num_msg: c_int,
            msg: [*]const ?*pam_message,
            resp: [*]?*pam_response,
            appdata_ptr: ?*anyopaque,
        ) callconv(.c) c_int,
        appdata_ptr: ?*anyopaque,
    };

    pub const PAM_SUCCESS: c_int = 0;
    pub const PAM_CONV_ERR: c_int = -1;

    extern fn pam_start(
        service_name: [*:0]const u8,
        user: ?[*:0]const u8,
        pam_conv: ?*pam_conv,
        pamh: *?*pam_handle_t,
    ) c_int;

    extern fn pam_end(pamh: ?*pam_handle_t, pam_status: c_int) c_int;
    extern fn pam_authenticate(pamh: ?*pam_handle_t, flags: c_int) c_int;
    extern fn pam_acct_mgmt(pamh: ?*pam_handle_t, flags: c_int) c_int;

    extern fn calloc(nmemb: usize, size: usize) ?*anyopaque;
};


const ConvContext = struct {
    password: []const u8,
    last_msg: ?Message = null,
};

fn convfn(
    num_msg: c_int,
    msg: [*]const ?*c.pam_message,
    resp: [*]?*c.pam_response,
    appdata_ptr: ?*anyopaque,
) callconv(.c) c_int {
    const ctx: *ConvContext = @ptrCast(@alignCast(
        appdata_ptr orelse return c.PAM_CONV_ERR
    ));

    const n: usize = @intCast(num_msg);


    const reply_ptr = c.calloc(n, @sizeOf(c.pam_response)) orelse return c.PAM_CONV_ERR;
    const reply_base: [*]c.pam_response = @ptrCast(@alignCast(reply_ptr));
    const reply_slice = reply_base[0..n];

    for (reply_slice) |*r| {
        r.resp = null;
        r.resp_retcode = 0;
    }


    resp[0] = @ptrCast(reply_slice.ptr);

    const msg_slice = msg[0..n];

    for (msg_slice, reply_slice) |maybe_ptr, *r| {
        const m_ptr = maybe_ptr orelse return c.PAM_CONV_ERR;
        const m = m_ptr.*;

        const style: MsgStyle = @enumFromInt(m.msg_style);

        switch (style) {
            .PROMPT_ECHO_OFF, .PROMPT_ECHO_ON => {
                const pw = ctx.password;


                const raw = c.calloc(pw.len + 1, @sizeOf(u8)) orelse return c.PAM_CONV_ERR;
                const buf: [*:0]u8 = @ptrCast(raw);

                @memcpy(buf[0..pw.len], pw);
                buf[pw.len] = 0;

                r.resp = buf;
                r.resp_retcode = 0;
            },

            .ERROR_MSG, .TEXT_INFO => {
                const text = if (m.msg) |p| std.mem.sliceTo(p, 0) else "";
                ctx.last_msg = .{ .style = style, .text = text };
                r.resp = null;
                r.resp_retcode = 0;
            },
        }
    }

    return c.PAM_SUCCESS;
}


pub fn auth(
    allocator: std.mem.Allocator,
    user: []const u8,
    password: []const u8,
) !Result {
    var pamh: ?*c.pam_handle_t = null;

    var service_buf: [6:0]u8 = .{ 'l','o','g','i','n',0 };
    const service_name: [*:0]const u8 = &service_buf;

    var user_buf: [64]u8 = undefined;
    if (user.len >= user_buf.len) return error.UserTooLong;
    @memcpy(user_buf[0..user.len], user);
    user_buf[user.len] = 0;
    const user_z: [*:0]const u8 = @ptrCast(&user_buf);

    const ctx_storage = try allocator.create(ConvContext);
    ctx_storage.* = ConvContext{
        .password = password,
    };

    var conv = c.pam_conv{
        .conv = @constCast(&convfn),
        .appdata_ptr = ctx_storage,
    };

    const rc_start = c.pam_start(service_name, user_z, &conv, &pamh);
    if (rc_start != c.PAM_SUCCESS or pamh == null) {
        allocator.destroy(ctx_storage);
        return error.StartFailed;
    }

    const rc_auth = c.pam_authenticate(pamh, 0);
    if (rc_auth != c.PAM_SUCCESS) {
        _ = c.pam_end(pamh, rc_auth);
        const last = ctx_storage.last_msg;
        allocator.destroy(ctx_storage);
        return .{ .ok = false, .last_msg = last };
    }

    const rc_acct = c.pam_acct_mgmt(pamh, 0);
    const rc_end  = c.pam_end(pamh, rc_acct);

    const last = ctx_storage.last_msg;
    allocator.destroy(ctx_storage);

    if (rc_end != c.PAM_SUCCESS) return error.EndFailed;

    return .{ .ok = (rc_acct == c.PAM_SUCCESS), .last_msg = last };
}
