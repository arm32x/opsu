const std = @import("std");
const jni = @import("jni");
const ma = @import("miniaudio");

// Allows doing `try exceptions.check();` to return after an exception
pub fn check(env: jni.JNIEnv) error{Exception}!void {
    if (env.exceptionCheck()) {
        return error.Exception;
    }
}

pub fn throwNew(env: jni.JNIEnv, class_name: [*:0]const u8, message: [*:0]const u8) error{Exception} {
    const exception_class = env.findClass(class_name);
    try check(env);

    env.throwNew(exception_class, message) catch |err| return throwFromZigError(env, err);
    return error.Exception;
}

pub fn throwOutOfMemoryError(env: jni.JNIEnv) error{Exception} {
    return throwNew(env, "java/lang/OutOfMemoryError", "Out of memory in Zig code");
}

pub fn throwMiniaudioException(env: jni.JNIEnv, result: ma.ma_result, message: [*:0]const u8) error{Exception} {
    // Make sure an exception hasn't already been thrown
    try check(env);

    // Find the exception class and constructor
    const exception_class = env.findClass("itdelatrisu/opsu/audio/MiniaudioException");
    try check(env);
    const constructor = env.getMethodID(exception_class, "<init>", "(ILjava/lang/String;)V");
    try check(env);

    // Create an exception object
    const message_string = env.newStringUTF(message);
    try check(env);
    const exception = env.newObject(exception_class, constructor, &[_]jni.jvalue{
        .{ .i = result },
        .{ .l = message_string },
    });
    try check(env);

    // Throw the exception
    env.throw(exception) catch |err| return throwFromZigError(env, err);
    return error.Exception;
}

pub fn throwFromZigError(env: jni.JNIEnv, err: anyerror) error{Exception} {
    // Make sure an exception hasn't already been thrown
    try check(env);

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
