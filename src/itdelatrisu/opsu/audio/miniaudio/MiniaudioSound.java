package itdelatrisu.opsu.audio.miniaudio;

public final class MiniaudioSound {
	final long handle;

	private MiniaudioSound(long handle) {
		this.handle = handle;
	}

	public static MiniaudioSound fromFile(Miniaudio miniaudio, String filePath) {
		long handle = jniInitFromFile(miniaudio.handle, filePath);
		return new MiniaudioSound(handle);
	}

	private static native long jniInitFromFile(long miniaudioHandle, String filePath);
}
