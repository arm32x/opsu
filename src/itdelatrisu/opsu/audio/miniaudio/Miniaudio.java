package itdelatrisu.opsu.audio.miniaudio;

import java.nio.file.Path;

public final class Miniaudio {
	private static final Object initLock = new Object();
	private static Miniaudio instance = null;

	private final long handle;

	private Miniaudio(long handle) {
		this.handle = handle;
	}

	public static String getVersion() {
		return jniGetVersion();
	}

	public static void init(Path nativesDir) {
		synchronized (initLock) {
			if (instance != null) {
				throw new RuntimeException("miniaudio is already initialized");
			}

			// For some reason, Java can't find the library if we do a simple
			// System.loadLibrary call
			Path libraryFile = nativesDir.resolve(System.mapLibraryName(getLibraryName()));
			System.load(libraryFile.toAbsolutePath().toString());

			long handle = jniInit();
			instance = new Miniaudio(handle);

			System.out.printf("Loaded miniaudio %s%n", getVersion());
		}
	}

	public static Miniaudio getInstance() {
		Miniaudio result = instance;
		if (result == null) {
			throw new RuntimeException("miniaudio is not initialized");
		}
		return result;
	}

	public void destroy() {
		synchronized (initLock) {
			jniDestroy(handle);
			instance = null;
		}
	}

	private static String getLibraryName() {
		String arch = System.getProperty("os.arch");
		switch (arch) {
			case "amd64":
			case "x86_64":
				return "opsu64";
			case "x86":
			case "i386":
			case "i486":
			case "i586":
			case "i686":
				return "opsu";
			default:
				System.err.printf("Warning: Unknown architecture %s. Loading natives will probably fail.%n", arch);
				return "opsu";
		}
	}

	private static native long jniInit();
	private static native void jniDestroy(long handle);

	private static native String jniGetVersion();
}
