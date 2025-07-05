const jni = @import("jni");

comptime {
    jni.exportJNI("itdelatrisu.opsu.audio.miniaudio.Miniaudio", @import("Miniaudio.zig"));
    jni.exportJNI("itdelatrisu.opsu.audio.miniaudio.MiniaudioSound", @import("MiniaudioSound.zig"));
}
