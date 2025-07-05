const std = @import("std");
const jni = @import("jni");
const ma = @import("miniaudio");

const utils = @import("utils.zig");

const Self = @This();

engine: ma.ma_engine,

pub fn jniInit(cEnv: *jni.cEnv, class: jni.jclass) callconv(.C) jni.jlong {
    const env = jni.JNIEnv.warp(cEnv);
    return init(env, class) catch 0;
}

fn init(env: jni.JNIEnv, _: jni.jclass) error{Exception}!jni.jlong {
    const allocator = std.heap.c_allocator;

    const self = allocator.create(Self) catch return utils.throwOutOfMemoryError(env);

    const result = ma.ma_engine_init(null, &self.engine);
    if (result != ma.MA_SUCCESS) {
        return utils.throwMiniaudioException(env, result, "Failed to create miniaudio engine");
    }

    return utils.handleFromPtr(self);
}

pub fn jniDestroy(cEnv: *jni.cEnv, class: jni.jclass, handle: jni.jlong) callconv(.C) void {
    const env = jni.JNIEnv.warp(cEnv);
    destroy(env, class, handle) catch {};
}

fn destroy(_: jni.JNIEnv, _: jni.jclass, handle: jni.jlong) error{Exception}!void {
    const allocator = std.heap.c_allocator;
    const self = utils.ptrFromHandle(Self, handle);

    ma.ma_engine_uninit(&self.engine);

    allocator.destroy(self);
}

pub fn jniGetVersion(cEnv: *jni.cEnv, _: jni.jclass) callconv(.C) jni.jstring {
    const env = jni.JNIEnv.warp(cEnv);
    return env.newStringUTF(ma.ma_version_string());
}
