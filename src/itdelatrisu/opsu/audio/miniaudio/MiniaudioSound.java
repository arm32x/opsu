package itdelatrisu.opsu.audio.miniaudio;

import java.nio.ByteBuffer;

public final class MiniaudioSound {
	final long handle;

	private MiniaudioSound(long handle) {
		this.handle = handle;
	}

	public static MiniaudioSound fromFile(Miniaudio miniaudio, String filePath) {
		long handle = jniInitFromFile(miniaudio.handle, filePath);
		return new MiniaudioSound(handle);
	}

	public static MiniaudioSound fromDirectByteBuffer(Miniaudio miniaudio, ByteBuffer byteBuffer, MiniaudioFormat format, int channels, int sampleRate) {
		if (!byteBuffer.isDirect()) {
			throw new RuntimeException("Cannot create miniaudio sound from non-direct ByteBuffer");
		}
		long handle = jniInitFromDirectByteBuffer(miniaudio.handle, byteBuffer, format.getValue(), channels, sampleRate);
		return new MiniaudioSound(handle);
	}

	public void start() {
		jniStart(handle);
	}

	public void stop() {
		jniStop(handle);
	}

	public boolean isPlaying() {
		return jniIsPlaying(handle);
	}

	public float getVolume() {
		return jniGetVolume(handle);
	}

	public void setVolume(float volume) {
		jniSetVolume(handle, volume);
	}

	public void seekToPcmFrame(long frameIndex) {
		jniSeekToPcmFrame(handle, frameIndex);
	}

	public void destroy() {
		jniDestroy(handle);
	}

	private static native long jniInitFromFile(long miniaudioHandle, String filePath);
	private static native long jniInitFromDirectByteBuffer(long miniaudioHandle, ByteBuffer byteBuffer, int format, int channels, int sampleRate);
	private static native void jniDestroy(long handle);

	private static native void jniStart(long handle);
	private static native void jniStop(long handle);
	private static native boolean jniIsPlaying(long handle);
	private static native float jniGetVolume(long handle);
	private static native void jniSetVolume(long handle, float volume);
	private static native void jniSeekToPcmFrame(long handle, long frameIndex);
}
