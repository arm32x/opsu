const std = @import("std");
const jni = @import("jni");
const ma = @import("miniaudio");

const utils = @import("utils.zig");

const Self = @This();

context: ma.ma_context,
device: ma.ma_device,
engine: ma.ma_engine,

pub fn jniInit(cEnv: *jni.cEnv, class: jni.jclass) callconv(.C) jni.jlong {
    const env = jni.JNIEnv.warp(cEnv);
    return init(env, class) catch 0;
}

fn init(env: jni.JNIEnv, _: jni.jclass) error{Exception}!jni.jlong {
    const allocator = std.heap.c_allocator;
    var result: ma.ma_result = ma.MA_SUCCESS;

    const self = allocator.create(Self) catch return utils.throwOutOfMemoryError(env);

    // TODO: Allow user to choose which backend they want to use
    result = ma.ma_context_init(null, 0, null, &self.context);
    if (result != ma.MA_SUCCESS) {
        return utils.throwMiniaudioException(env, result, "Failed to create miniaudio context");
    }

    var device_config = ma.ma_device_config_init(ma.ma_device_type_playback);
    device_config.playback.format = ma.ma_format_f32;
    device_config.playback.channels = 2;
    device_config.dataCallback = dataCallback;
    device_config.pUserData = self;
    device_config.performanceProfile = ma.ma_performance_profile_low_latency;
    device_config.periodSizeInMilliseconds = 5;
    device_config.noFixedSizedCallback = 1;
    result = ma.ma_device_init(&self.context, &device_config, &self.device);
    if (result != ma.MA_SUCCESS) {
        return utils.throwMiniaudioException(env, result, "Failed to create miniaudio device");
    }

    var engine_config = ma.ma_engine_config_init();
    // engine_config.pContext = &self.context;
    engine_config.pDevice = &self.device;
    result = ma.ma_engine_init(&engine_config, &self.engine);
    if (result != ma.MA_SUCCESS) {
        return utils.throwMiniaudioException(env, result, "Failed to create miniaudio engine");
    }

    return utils.handleFromPtr(self);
}

fn dataCallback(
    device: ?*ma.ma_device,
    output: ?*anyopaque,
    input: ?*const anyopaque,
    frame_count: ma.ma_uint32,
) callconv(.C) void {
    _ = input;
    const self: *Self = @ptrCast(@alignCast(device.?.pUserData.?));
    _ = ma.ma_engine_read_pcm_frames(&self.engine, output, frame_count, null);
}

pub fn jniDestroy(cEnv: *jni.cEnv, class: jni.jclass, handle: jni.jlong) callconv(.C) void {
    const env = jni.JNIEnv.warp(cEnv);
    destroy(env, class, handle) catch {};
}

fn destroy(_: jni.JNIEnv, _: jni.jclass, handle: jni.jlong) error{Exception}!void {
    const allocator = std.heap.c_allocator;
    const self = utils.ptrFromHandle(Self, handle);

    ma.ma_engine_uninit(&self.engine);
    ma.ma_device_uninit(&self.device);
    _ = ma.ma_context_uninit(&self.context);

    allocator.destroy(self);
}

pub fn jniGetVersion(cEnv: *jni.cEnv, _: jni.jclass) callconv(.C) jni.jstring {
    const env = jni.JNIEnv.warp(cEnv);
    return env.newStringUTF(ma.ma_version_string());
}
