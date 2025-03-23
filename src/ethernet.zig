const std = @import("std");

pub const MacAddress = [6]u8;

pub const EtherType = enum(u16) {
    IPV4 = 0x0800,
    ARP = 0x0806,
    IPV6 = 0x86DD,
};

pub const EthernetFrame = struct {
    buffer: [1514]u8,
    len: usize,

    pub fn init(dmac: MacAddress, smac: MacAddress, ether_type: EtherType, payload: []const u8) !EthernetFrame {
        var frame = EthernetFrame{
            .buffer = undefined,
            .len = 0,
        };

        try frame.setHeader(dmac, smac, ether_type);
        try frame.setPayload(payload);

        return frame;
    }

    fn setHeader(self: *EthernetFrame, dmac: MacAddress, smac: MacAddress, ether_type: EtherType) !void {
        if (self.buffer.len < 14) {
            return error.BufferTooSmall;
        }

        @memcpy(self.buffer[0..6], &dmac);
        @memcpy(self.buffer[6..12], &smac);

        std.mem.writeInt(u16, self.buffer[12..14], @intFromEnum(ether_type), .big);

        if (self.len < 14) {
            self.len = 14;
        }
    }

    fn setPayload(self: *EthernetFrame, payload: []const u8) !void {
        const header_size = 14;
        if (header_size + payload.len > self.buffer.len) {
            return error.PayloadTooLarge;
        }

        @memcpy(self.buffer[header_size .. header_size + payload.len], payload);
        self.len = header_size + payload.len;

        if (self.len < 60) {
            @memset(self.buffer[self.len..60], 0);
            self.len = 60;
        }
    }

    pub fn extractDmac(self: *const EthernetFrame) []const u8 {
        return self.buffer[0..6];
    }

    pub fn extractSmac(self: *const EthernetFrame) []const u8 {
        return self.buffer[6..12];
    }

    pub fn extractEtherType(self: *const EthernetFrame) u16 {
        return std.mem.readInt(u16, self.buffer[12..14], .big);
    }

    pub fn extractPayload(self: *const EthernetFrame) []const u8 {
        return self.buffer[14..self.len];
    }

    pub fn asBytes(self: *const EthernetFrame) []const u8 {
        return self.buffer[0..self.len];
    }

    pub fn writeTo(self: *const EthernetFrame, writer: anytype) !void {
        try writer.writeAll(self.asBytes());
    }
};
