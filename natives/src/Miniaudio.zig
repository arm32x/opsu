const std = @import("std");
const jni = @import("jni");
const ma = @import("miniaudio");

const exceptions = @import("utils/exceptions.zig");
const handle_casts = @import("utils/handle_casts.zig");

const Self = @This();

pub fn jniInit(cEnv: *jni.cEnv, class: jni.jclass) callconv(.C) jni.jlong {
    const env = jni.JNIEnv.warp(cEnv);
    return init(env, class) catch 0;
}

fn init(env: jni.JNIEnv, _: jni.jclass) error{Exception}!jni.jlong {
    const allocator = std.heap.c_allocator;

    const self = allocator.create(Self) catch try exceptions.throwOutOfMemoryError(env);
    return handle_casts.handleFromPtr(self);
}

pub fn jniDestroy(cEnv: *jni.cEnv, class: jni.jclass, handle: jni.jlong) callconv(.C) void {
    const env = jni.JNIEnv.warp(cEnv);
    destroy(env, class, handle) catch {};
}

fn destroy(_: jni.JNIEnv, _: jni.jclass, handle: jni.jlong) error{Exception}!void {
    const allocator = std.heap.c_allocator;
    const self = handle_casts.ptrFromHandle(Self, handle);

    allocator.destroy(self);
}

pub fn jniGetVersion(cEnv: *jni.cEnv, _: jni.jclass) callconv(.C) jni.jstring {
    const env = jni.JNIEnv.warp(cEnv);
    return env.newStringUTF(ma.ma_version_string());
}
