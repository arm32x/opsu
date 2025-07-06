const std = @import("std");
const ma = @import("miniaudio");

// This can't be the top-level struct since it needs to be `extern`
pub const ZeroSizedDataSource = extern struct {
    base: ma.ma_data_source_base,
    format: ma.ma_format,
    channels: u32,
    sample_rate: u32,

    const Self = @This();

    pub fn init(format: ma.ma_format, channels: u32, sample_rate: u32) struct { Self, ma.ma_result } {
        var self = Self{
            .base = undefined,
            .format = format,
            .channels = channels,
            .sample_rate = sample_rate,
        };

        var base_config = ma.ma_data_source_config_init();
        base_config.vtable = &vtable;

        const result = ma.ma_data_source_init(&base_config, &self.base);
        return .{ self, result };
    }

    pub fn deinit(self: *Self) void {
        ma.ma_data_source_uninit(&self.base);
    }

    fn onRead(
        _: ?*ma.ma_data_source,
        frames_out: ?*anyopaque,
        frame_count: ma.ma_uint64,
        frames_read: ?*ma.ma_uint64,
    ) callconv(.C) ma.ma_result {
        _ = frames_out;
        _ = frame_count;
        frames_read.?.* = 0;
        return ma.MA_AT_END;
    }

    fn onSeek(_: ?*ma.ma_data_source, frame_index: ma.ma_uint64) callconv(.C) ma.ma_result {
        return if (frame_index == 0) ma.MA_SUCCESS else ma.MA_INVALID_ARGS;
    }

    fn onGetDataFormat(
        data_source: ?*ma.ma_data_source,
        format: ?*ma.ma_format,
        channels: ?*ma.ma_uint32,
        sample_rate: ?*ma.ma_uint32,
        channel_map: ?[*]ma.ma_channel,
        channel_map_cap: usize,
    ) callconv(.C) ma.ma_result {
        const self: *Self = @ptrCast(@alignCast(data_source.?));

        format.?.* = self.format;
        channels.?.* = self.channels;
        sample_rate.?.* = self.sample_rate;
        ma.ma_channel_map_init_standard(ma.ma_standard_channel_map_default, channel_map, channel_map_cap, self.channels);

        return ma.MA_SUCCESS;
    }

    fn onGetCursor(_: ?*ma.ma_data_source, cursor: ?*ma.ma_uint64) callconv(.C) ma.ma_result {
        cursor.?.* = 0;
        return ma.MA_SUCCESS;
    }

    fn onGetLength(_: ?*ma.ma_data_source, length: ?*ma.ma_uint64) callconv(.C) ma.ma_result {
        length.?.* = 0;
        return ma.MA_SUCCESS;
    }

    pub const vtable: ma.ma_data_source_vtable = .{
        .onRead = onRead,
        .onSeek = onSeek,
        .onGetDataFormat = onGetDataFormat,
        .onGetCursor = onGetCursor,
        .onGetLength = onGetLength,
        .flags = 0,
    };
};
