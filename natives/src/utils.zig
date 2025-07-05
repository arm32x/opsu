const std = @import("std");
const jni = @import("jni");
const ma = @import("miniaudio");

// jlong <-> pointer conversions:

const UnsignedJlong = switch (jni.jlong) {
    c_long => c_ulong,
    c_longlong => c_ulonglong,
    else => @compileError("Bad jlong type"),
};

pub fn handleFromPtr(value: anytype) jni.jlong {
    const step1: usize = @intFromPtr(value);
    const step2: UnsignedJlong = step1; // Should be widening only
    const step3: jni.jlong = @bitCast(step2);
    return step3;
}

pub fn ptrFromHandle(comptime T: type, value: jni.jlong) *T {
    const step1: UnsignedJlong = @bitCast(value);
    const step2: usize = @intCast(step1);
    const step3: *T = @ptrFromInt(step2);
    return step3;
}

// Allows doing `try exceptionCheck();` to return after an exception
pub fn exceptionCheck(env: jni.JNIEnv) error{Exception}!void {
    if (env.exceptionCheck()) {
        return error.Exception;
    }
}

// Exceptions:

pub fn throwNew(env: jni.JNIEnv, class_name: [*:0]const u8, message: [*:0]const u8) error{Exception} {
    // Make sure an exception hasn't already been thrown
    try exceptionCheck(env);

    const exception_class = env.findClass(class_name);
    try exceptionCheck(env);

    env.throwNew(exception_class, message) catch |err| return throwFromZigError(env, err);
    return error.Exception;
}

pub fn throwOutOfMemoryError(env: jni.JNIEnv) error{Exception} {
    return throwNew(env, "java/lang/OutOfMemoryError", "Out of memory in Zig code");
}

pub fn throwMiniaudioException(env: jni.JNIEnv, result: ma.ma_result, message: [*:0]const u8) error{Exception} {
    // Make sure an exception hasn't already been thrown
    try exceptionCheck(env);

    // Find the exception class and constructor
    const exception_class = env.findClass("itdelatrisu/opsu/audio/miniaudio/MiniaudioException");
    try exceptionCheck(env);
    const constructor = env.getMethodID(exception_class, "<init>", "(ILjava/lang/String;)V");
    try exceptionCheck(env);

    // Create an exception object
    const message_string = env.newStringUTF(message);
    try exceptionCheck(env);
    const exception = env.newObject(exception_class, constructor, &[_]jni.jvalue{
        .{ .i = result },
        .{ .l = message_string },
    });
    try exceptionCheck(env);

    // Throw the exception
    env.throw(exception) catch |err| return throwFromZigError(env, err);
    return error.Exception;
}

pub fn throwFromZigError(env: jni.JNIEnv, err: anyerror) error{Exception} {
    // Make sure an exception hasn't already been thrown
    try exceptionCheck(env);

    switch (err) {
        error.OutOfMemory, error.JNIOutOfMemory => return throwOutOfMemoryError(env),

        else => {
            var message_buf: [64]u8 = undefined;
            const message = std.fmt.bufPrintZ(&message_buf, "Error in Zig code: {s}", .{@errorName(err)}) catch blk: {
                std.mem.copyForwards(u8, message_buf[message_buf.len - 4 ..], "...\x00");
                break :blk message_buf[0 .. message_buf.len - 1 :0];
            };
            return throwNew(env, "java/lang/RuntimeException", message);
        },
    }
}

// JNI string helpers:

pub fn getJavaStringAsUtf8(env: jni.JNIEnv, allocator: std.mem.Allocator, string: jni.jstring) error{Exception}![:0]u8 {
    // We don't care about this value, but Zig-JNI requires that we pass a
    // non-null pointer here
    var is_copy: bool = false;
    const string_utf16 = env.getStringChars(string, &is_copy);
    defer env.releaseStringChars(string, string_utf16);
    const string_utf8 = std.unicode.utf16LeToUtf8AllocZ(allocator, std.mem.span(string_utf16)) catch |err| return throwFromZigError(env, err);
    return string_utf8;
}
