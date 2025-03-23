const std = @import("std");
const jni = @import("jni");
const ma = @import("miniaudio");

const Self = @This();

pub fn jniInit(cEnv: *jni.cEnv, _: jni.jclass) callconv(.C) jni.jlong {
    // TODO: Implement this
    _ = cEnv;
    return 42;
}

pub fn jniDestroy(cEnv: *jni.cEnv, _: jni.jclass, handle: jni.jlong) callconv(.C) void {
    // TODO: Implement this
    _ = cEnv;
    _ = handle;
}

pub fn jniGetVersion(cEnv: *jni.cEnv, _: jni.jclass) callconv(.C) jni.jstring {
    const env = jni.JNIEnv.warp(cEnv);
    return env.newStringUTF(ma.ma_version_string());
}
