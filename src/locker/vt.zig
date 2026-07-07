// Hand rewrite of <linux/vt.h> header to Zig

pub inline fn isValidConsole(n: u32) bool {
    return n >= 1 and n <= 63;
}
// NOTE: historically tty numbers:
//   - tty0 is not a real console; it is an alias for "current active VT"
//   - real virtual consoles start at tty1 (MIN_NR_CONSOLES = 1)
//   - VTs occupy the minor range 1–63
//   - starting from minor 64 begin serial lines (ttyS0 = minor 64)
//   - therefore MAX_NR_CONSOLES = 63 to avoid overlap with serial devices


pub const Ioctl = enum(u32) {
    OPENQRY       = 0x5600,     // find available vt
    
    GETMODE       = 0x5601,     // get mode of active vt
    SETMODE       = 0x5602,     // set mode of active vt
    
    GETSTATE      = 0x5603,     // get global vt state;
                                // does not work for consoles 16 and higher
                                
    SENDSIG       = 0x5604,     // signal to sent to bitmask of vts
    RELDISP       = 0x5605,     // release display
    
    ACTIVATE      = 0x5606,     // make vt active
    WAITACTIVE    = 0x5607,     // wait for vt activate
    DISALLOCATE   = 0x5608,     // free memory associated to vt
    
    RESIZE        = 0x5609,     // set kernel's idea of screensize
    RESIZEX       = 0x560A,     // same, but + more (idk what it means)
    
    LOCKSWITCH    = 0x560B,     // block vt switching
    UNLOCKSWITCH  = 0x560C,     // allow vt switching
    
    GETHIFONTMASK = 0x560D,     // return hi font mask
    
    WAITEVENT     = 0x560E,     // wait for an event
    SETACTIVATE   = 0x560F,     // activate and set the mode of a console
    GETCONSIZECSRPOS = 0x5610,  // get console size and cursor position
};


pub const CMode = extern struct { // C ABI
    mode:   u8,  // Mode.kind enum value
    waitv:  u8,
    relsig: i16,
    acqsig: i16,
    frsig:  i16 = 0,  // unsused value, must be set to 0
};

pub const Mode = struct {
    kind: enum(u8) {
        AUTO    = 0x00,  // auto vt switching
        PROCESS = 0x01,  // process controls switching
        ACKACQ  = 0x02,  // acknowledge switch
    },
    waitv:  u8,   // if non-zero, writes to the VT block when the console is not actve
    relsig: i16,  // signal to raise on release request from kernel
    acqsig: i16,  // signal sent by kernel when VT is acquired


    pub fn toC(self: *Mode) CMode {
        return .{
            .mode   = @intFromEnum(self.kind),
            .waitv  = self.waitv,
            .relsig = self.relsig,
            .acqsig = self.acqsig,
        };
    }

    pub fn fromC(c: CMode) Mode {
        return .{
            .kind   = @enumFromInt(c.mode),
            .waitv  = c.waitv,
            .relsig = c.relsig,
            .acqsig = c.acqsig,
        };
    }
};


pub const Stat = extern struct {
    active: u16,  // number of active vt
    signal: u16,  // signal to send
    state:  u16,  // vt bitmask
};

pub const Sizes = extern struct {
    rows:   u16,  // amount of text lines
    cols:   u16,  // amount of text columns
    scroll: u16,  // number of lines of scrollback
};

pub const ConSize = extern struct {
    rows: u16,  // amount of text lines
    cols: u16,  // amount of text columns

    vlin: u16,  // number of pixel rows on screen
    clin: u16,  // height in pixels of a character cell

    vcol: u16,  // number of pixel columns on screen
    ccol: u16,  // width in pixels of a character cell
};



pub const CEvent = extern struct { // C ABI
    event: u32,  // Event.kind enum value
    old:   u32,
    new:   u32,
    pad:   [4]u32 = .{ 0, 0, 0, 0 },  // padding for expansion
};

pub const Event = struct {
    kind: enum(u32) {
        SWITCH  = 0x0001,
        BLANK   = 0x0002,
        UNBLANK = 0x0004,
        RESIZE  = 0x0008,
    },
    old: u32,  // old console
    new: u32,  // new console

    
    pub const MAXCOUNT = 0x000F;

    pub fn toC(self: *Event) CEvent {
        return .{
            .event = @intFromEnum(self.kind),
            .old   = self.old,
            .new   = self.new,
        };
    }

    pub fn fromC(c: CEvent) Event {
        return .{
            .kind = @enumFromInt(c.event),
            .old  = c.old,
            .new  = c.new,
        };
    }
};


pub const SetActivate = extern struct {
    console: u32,
    mode: CMode,
};

pub const ConSizeCsrPos = extern struct {
    con_rows: u16,  // total number of text rows on the console
    con_cols: u16,  // total number of text columns
    csr_row:  u16,  // current cursor row (0-based)
    csr_col:  u16,  // current cursor column (0-based)
};


comptime {
    if (@import("builtin").os.tag != .linux) {
        @compileError("Virtual Terminal setup available only on Linux");
    }
}
