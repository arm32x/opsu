const jni = @import("jni");

comptime {
    jni.exportJNI("itdelatrisu.opsu.audio.Miniaudio", @import("Miniaudio.zig"));
}
