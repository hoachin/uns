const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;
const mem = std.mem;

const TUNSETIFF = 0x400454CA;
const IFF_TAP = 0x0002;
const IFF_NO_PI = 0x1000;

pub const TapDevice = struct {
    fd: posix.fd_t,
    name: []const u8,

    pub fn init(name: []const u8) !TapDevice {
        const flags = posix.O{
            .ACCMODE = .RDWR,
            .CLOEXEC = true,
        };
        const fd = try posix.open("/dev/net/tun", flags, 0);
        if (fd < 0) {
            return error.InvalidFileDescriptor;
        }

        var ifreq: [40]u8 = mem.zeroes([40]u8);
        @memcpy(ifreq[0..name.len], name);
        @memcpy(ifreq[16..18], &mem.toBytes(@as(u16, IFF_TAP | IFF_NO_PI)));

        const ret = linux.ioctl(fd, TUNSETIFF, @intFromPtr(&ifreq));
        if (@intFromEnum(posix.errno(ret)) < @as(u16, 0)) {
            return error.TapSetupFailed;
        }

        return TapDevice{
            .fd = fd,
            .name = name,
        };
    }

    const Writer = std.io.Writer(*TapDevice, posix.WriteError, writeFn);

    pub fn writer(self: *TapDevice) Writer {
        return .{
            .context = self,
        };
    }

    fn writeFn(context: *TapDevice, bytes: []const u8) posix.WriteError!usize {
        return try posix.write(context.fd, bytes);
    }

    const Reader = std.io.Reader(*TapDevice, posix.ReadError, readFn);

    pub fn reader(self: *TapDevice) Reader {
        return .{
            .context = self,
        };
    }

    fn readFn(context: *TapDevice, bytes: []u8) posix.ReadError!usize {
        return try posix.read(context.fd, bytes);
    }

    pub fn deinit(self: *TapDevice) void {
        return posix.close(self.fd);
    }
};
