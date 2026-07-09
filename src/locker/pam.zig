const std = @import("std");


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


pub const MsgStyle = enum(c_int) {
    PROMPT_ECHO_OFF = 1,
    PROMPT_ECHO_ON  = 2,
    ERROR           = 3,
    INFO            = 4,
};

pub const Message = struct {
    style: MsgStyle,
    text:  []const u8,
};

pub const ConvContext = struct {
    user: ?[*:0]const u8,
    pass: ?*[64]u8,
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
    const reply: [*]c.pam_response = @ptrCast(@alignCast(reply_ptr));

    for (reply[0..n]) |*r| {
        r.resp = null;
        r.resp_retcode = 0;
    }


    resp[0] = @ptrCast(reply);

    for (msg[0..n], reply[0..n]) |maybe_ptr, *r| {
        const m = (maybe_ptr orelse return c.PAM_CONV_ERR).*;

        const style: MsgStyle = @enumFromInt(m.msg_style);

        switch (style) {
            .PROMPT_ECHO_OFF, .PROMPT_ECHO_ON => {
                const pw  = ctx.pass orelse return c.PAM_CONV_ERR;

                const raw = c.calloc(pw.len + 1, @sizeOf(u8)) orelse return c.PAM_CONV_ERR;
                const buf: [*:0]u8 = @ptrCast(raw);

                // Note: PAM always freed memory for response that allocated here,
                // so we need to use C malloc/calloc functions.
                // You can see files libpam/pam_item.c:394 and libpam/include/pam_inline.h:398
                // in https://github.com/linux-pam/linux-pam repo for more info.

                @memcpy(buf[0..pw.len], pw);
                buf[pw.len] = 0;

                r.resp = buf;
                r.resp_retcode = 0;
            },

            .ERROR, .INFO => {
                const text = if (m.msg) |p| std.mem.sliceTo(p, 0) else "";
                ctx.last_msg = .{ .style = style, .text = text };
                r.resp = null;
                r.resp_retcode = 0;
            },
        }
    }

    return c.PAM_SUCCESS;
}


pub fn auth(ctx: *ConvContext) !bool {
    var pamh: ?*c.pam_handle_t = null;

    var conv = c.pam_conv{
        .conv = @constCast(&convfn),
        .appdata_ptr = ctx,
    };


    const rc_start = c.pam_start("login", ctx.user, &conv, &pamh);
    if (rc_start != c.PAM_SUCCESS or pamh == null) {
        return error.StartFailed;
    }


    const rc_auth = c.pam_authenticate(pamh, 0);
    if (rc_auth != c.PAM_SUCCESS) {
        _ = c.pam_end(pamh, rc_auth);
        return false;
    }


    const rc_acct = c.pam_acct_mgmt(pamh, 0);
    const rc_end  = c.pam_end(pamh, rc_acct);

    if (rc_end != c.PAM_SUCCESS) return error.EndFailed;


    return (rc_acct == c.PAM_SUCCESS);
}
