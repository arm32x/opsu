const std = @import("std");
const jni = @import("jni");
const ma = @import("miniaudio");

const Miniaudio = @import("Miniaudio.zig");
const utils = @import("utils.zig");

const Self = @This();

sound: ma.ma_sound,
// If we created this sound from a ByteBuffer, we need to keep track of the
// data source so we can free it later.
data_source: union(enum) {
    none, // managed by the ma_sound
    audio_buffer: ma.ma_audio_buffer,
},

const one_frame_of_silence = [_]u16{0};

pub fn jniInitFromFile(
    cEnv: *jni.cEnv,
    class: jni.jclass,
    miniaudio_handle: jni.jlong,
    file_path_string: jni.jstring,
) callconv(.C) jni.jlong {
    const env = jni.JNIEnv.warp(cEnv);
    return initFromFile(env, class, miniaudio_handle, file_path_string) catch 0;
}

fn initFromFile(
    env: jni.JNIEnv,
    _: jni.jclass,
    miniaudio_handle: jni.jlong,
    file_path_string: jni.jstring,
) error{Exception}!jni.jlong {
    const allocator = std.heap.c_allocator;
    const miniaudio = utils.ptrFromHandle(Miniaudio, miniaudio_handle);

    const file_path = try utils.getJavaStringAsUtf8(env, allocator, file_path_string);
    defer allocator.free(file_path);

    const self = allocator.create(Self) catch return utils.throwOutOfMemoryError(env);
    errdefer allocator.destroy(self);
    self.* = .{
        .sound = undefined, // initialized below
        .data_source = .none,
    };

    const result = ma.ma_sound_init_from_file(
        &miniaudio.engine,
        file_path,
        ma.MA_SOUND_FLAG_DECODE,
        null, // group
        null, // done fence
        &self.sound,
    );
    if (result != ma.MA_SUCCESS) {
        return utils.throwMiniaudioException(env, result, "Failed to initialize sound");
    }

    return utils.handleFromPtr(self);
}

pub fn jniInitFromDirectByteBuffer(
    cEnv: *jni.cEnv,
    class: jni.jclass,
    miniaudio_handle: jni.jlong,
    byte_buffer: jni.jobject,
    format: jni.jint,
    channels: jni.jint,
    sample_rate: jni.jint,
) callconv(.C) jni.jlong {
    const env = jni.JNIEnv.warp(cEnv);
    return initFromDirectByteBuffer(env, class, miniaudio_handle, byte_buffer, format, channels, sample_rate) catch 0;
}

fn initFromDirectByteBuffer(
    env: jni.JNIEnv,
    _: jni.jclass,
    miniaudio_handle: jni.jlong,
    byte_buffer: jni.jobject,
    format_signed: jni.jint,
    channels_signed: jni.jint,
    sample_rate_signed: jni.jint,
) error{Exception}!jni.jlong {
    const allocator = std.heap.c_allocator;
    const miniaudio = utils.ptrFromHandle(Miniaudio, miniaudio_handle);
    const format: ma.ma_format = @intCast(format_signed);
    const channels: u32 = @intCast(channels_signed);
    const sample_rate: u32 = @intCast(sample_rate_signed);
    var result: ma.ma_result = ma.MA_SUCCESS;

    const buffer_address: ?[*]u8 = @ptrFromInt(env.getDirectBufferAddress(byte_buffer));
    const buffer_capacity = env.getDirectBufferCapacity(byte_buffer);
    if (buffer_address == null or buffer_capacity == -1) {
        return utils.throwNew(env, "java/lang/RuntimeException", "Could not access direct ByteBuffer");
    }
    const buffer: []u8 = buffer_address.?[0..@intCast(buffer_capacity)];

    const bytes_per_frame = ma.ma_get_bytes_per_frame(format, channels);
    const len_in_frames: u64 = buffer.len / bytes_per_frame;

    const self = allocator.create(Self) catch return utils.throwOutOfMemoryError(env);
    errdefer allocator.destroy(self);
    self.* = .{
        .sound = undefined, // initialized below
        .data_source = .{ .audio_buffer = undefined }, // initialized below
    };

    // ma_audio_buffer doesn't support empty buffers. If we are given an empty
    // buffer, then we use 1 frame of silence instead.
    const config = if (len_in_frames == 0) ma.ma_audio_buffer_config{
        .format = ma.ma_format_s16,
        .channels = 1,
        .sampleRate = ma.ma_standard_sample_rate_44100,
        .sizeInFrames = 1,
        .pData = &one_frame_of_silence,
    } else ma.ma_audio_buffer_config{
        .format = format,
        .channels = channels,
        .sampleRate = sample_rate,
        .sizeInFrames = len_in_frames,
        .pData = buffer.ptr,
    };
    result = ma.ma_audio_buffer_init(&config, &self.data_source.audio_buffer);
    if (result != ma.MA_SUCCESS) {
        return utils.throwMiniaudioException(env, result, "Failed to initialize audio buffer");
    }

    result = ma.ma_sound_init_from_data_source(
        &miniaudio.engine,
        &self.data_source.audio_buffer,
        0, // flags
        null, // group
        &self.sound,
    );
    if (result != ma.MA_SUCCESS) {
        return utils.throwMiniaudioException(env, result, "Failed to initialize sound");
    }

    return utils.handleFromPtr(self);
}

pub fn jniDestroy(cEnv: *jni.cEnv, class: jni.jclass, handle: jni.jlong) callconv(.C) void {
    const env = jni.JNIEnv.warp(cEnv);
    return destroy(env, class, handle) catch {};
}

fn destroy(_: jni.JNIEnv, _: jni.jclass, handle: jni.jlong) error{Exception}!void {
    const allocator = std.heap.c_allocator;
    const self = utils.ptrFromHandle(Self, handle);

    ma.ma_sound_uninit(&self.sound);
    switch (self.data_source) {
        .none => {},
        .audio_buffer => |*audio_buffer| ma.ma_audio_buffer_uninit(audio_buffer),
    }

    allocator.destroy(self);
}

pub fn jniStart(cEnv: *jni.cEnv, class: jni.jclass, handle: jni.jlong) callconv(.C) void {
    const env = jni.JNIEnv.warp(cEnv);
    return start(env, class, handle) catch {};
}

fn start(env: jni.JNIEnv, _: jni.jclass, handle: jni.jlong) error{Exception}!void {
    const self = utils.ptrFromHandle(Self, handle);

    const result = ma.ma_sound_start(&self.sound);
    if (result != ma.MA_SUCCESS) {
        return utils.throwMiniaudioException(env, result, "Failed to start sound");
    }
}

pub fn jniStop(cEnv: *jni.cEnv, class: jni.jclass, handle: jni.jlong) callconv(.C) void {
    const env = jni.JNIEnv.warp(cEnv);
    return stop(env, class, handle) catch {};
}

fn stop(env: jni.JNIEnv, _: jni.jclass, handle: jni.jlong) error{Exception}!void {
    const self = utils.ptrFromHandle(Self, handle);

    const result = ma.ma_sound_stop(&self.sound);
    if (result != ma.MA_SUCCESS) {
        return utils.throwMiniaudioException(env, result, "Failed to stop sound");
    }
}

pub fn jniIsPlaying(cEnv: *jni.cEnv, class: jni.jclass, handle: jni.jlong) callconv(.C) jni.jboolean {
    const env = jni.JNIEnv.warp(cEnv);
    return isPlaying(env, class, handle) catch 0;
}

fn isPlaying(_: jni.JNIEnv, _: jni.jclass, handle: jni.jlong) error{Exception}!jni.jboolean {
    const self = utils.ptrFromHandle(Self, handle);
    const is_playing = ma.ma_sound_is_playing(&self.sound) != 0;
    return jni.boolToJboolean(is_playing);
}

pub fn jniGetVolume(cEnv: *jni.cEnv, class: jni.jclass, handle: jni.jlong) callconv(.C) jni.jfloat {
    const env = jni.JNIEnv.warp(cEnv);
    return getVolume(env, class, handle) catch 0;
}

fn getVolume(_: jni.JNIEnv, _: jni.jclass, handle: jni.jlong) error{Exception}!jni.jfloat {
    const self = utils.ptrFromHandle(Self, handle);
    return ma.ma_sound_get_volume(&self.sound);
}

pub fn jniSetVolume(cEnv: *jni.cEnv, class: jni.jclass, handle: jni.jlong, volume: jni.jfloat) callconv(.C) void {
    const env = jni.JNIEnv.warp(cEnv);
    return setVolume(env, class, handle, volume) catch {};
}

fn setVolume(_: jni.JNIEnv, _: jni.jclass, handle: jni.jlong, volume: jni.jfloat) error{Exception}!void {
    const self = utils.ptrFromHandle(Self, handle);
    ma.ma_sound_set_volume(&self.sound, volume);
}

pub fn jniSeekToPcmFrame(cEnv: *jni.cEnv, class: jni.jclass, handle: jni.jlong, frame_index: jni.jlong) callconv(.C) void {
    const env = jni.JNIEnv.warp(cEnv);
    return seekToPcmFrame(env, class, handle, frame_index) catch {};
}

fn seekToPcmFrame(env: jni.JNIEnv, _: jni.jclass, handle: jni.jlong, frame_index_signed: jni.jlong) error{Exception}!void {
    const self = utils.ptrFromHandle(Self, handle);
    const frame_index: u64 = @intCast(frame_index_signed);

    const result = ma.ma_sound_seek_to_pcm_frame(&self.sound, frame_index);
    if (result != ma.MA_SUCCESS) {
        return utils.throwMiniaudioException(env, result, "Failed to seek sound");
    }
}
