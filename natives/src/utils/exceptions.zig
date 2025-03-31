const std = @import("std");
const jni = @import("jni");

// Allows doing `try exceptions.check();` to return after an exception.
pub fn check(env: jni.JNIEnv) error{Exception}!void {
    if (env.exceptionCheck()) {
        return error.Exception;
    }
}

pub fn throwNew(env: jni.JNIEnv, class_name: [*:0]const u8, message: [*:0]const u8) error{Exception}!noreturn {
    const exception_class = env.findClass(class_name);
    try check(env);

    env.throwNew(exception_class, message) catch |err| try throwFromZigError(env, err);
    return error.Exception;
}

pub fn throwOutOfMemoryError(env: jni.JNIEnv) error{Exception}!noreturn {
    return throwNew(env, "java/lang/OutOfMemoryError", "Out of memory in Zig code");
}

pub fn throwFromZigError(env: jni.JNIEnv, err: anyerror) error{Exception}!noreturn {
    // Make sure an exception hasn't already been thrown
    try check(env);

    switch (err) {
        error.OutOfMemory, error.JNIOutOfMemory => try throwOutOfMemoryError(env),

        else => {
            var message_buf: [64]u8 = undefined;
            const message = std.fmt.bufPrintZ(&message_buf, "Error in Zig code: {s}", .{@errorName(err)}) catch blk: {
                std.mem.copyForwards(u8, message_buf[message_buf.len - 4 ..], "...\x00");
                break :blk message_buf[0 .. message_buf.len - 1 :0];
            };
            try throwNew(env, "java/lang/RuntimeException", message);
        },
    }
}
