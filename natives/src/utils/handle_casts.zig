const jni = @import("jni");

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
