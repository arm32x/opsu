const std = @import("std");
const jni = @import("jni");
const ma = @import("miniaudio");

const Miniaudio = @import("Miniaudio.zig");
const utils = @import("utils.zig");

const Self = @This();

sound: ma.ma_sound,

pub fn jniInitFromFile(cEnv: *jni.cEnv, class: jni.jclass, miniaudio_handle: jni.jlong, file_path_string: jni.jstring) callconv(.C) jni.jlong {
    const env = jni.JNIEnv.warp(cEnv);
    return initFromFile(env, class, miniaudio_handle, file_path_string) catch 0;
}

fn initFromFile(env: jni.JNIEnv, _: jni.jclass, miniaudio_handle: jni.jlong, file_path_string: jni.jstring) error{Exception}!jni.jlong {
    const allocator = std.heap.c_allocator;
    const miniaudio = utils.ptrFromHandle(Miniaudio, miniaudio_handle);

    const file_path = try utils.getJavaStringAsUtf8(env, allocator, file_path_string);
    defer allocator.free(file_path);

    const self = allocator.create(Self) catch return utils.throwOutOfMemoryError(env);

    const result = ma.ma_sound_init_from_file(&miniaudio.engine, file_path, ma.MA_SOUND_FLAG_DECODE, null, null, &self.sound);
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

    allocator.destroy(self);
}
