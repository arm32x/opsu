package itdelatrisu.opsu.audio;

import java.nio.file.Path;

public final class Miniaudio {
	private static final Object lock = new Object();
	private static long handle = -1;

	public static void init(Path nativesDir) {
		synchronized (lock) {
			if (handle != -1) {
				return;
			}

			// For some reason, Java can't find the library if we do a simple
			// System.loadLibrary call
			Path libraryFile = nativesDir.resolve(System.mapLibraryName(getLibraryName()));
			System.load(libraryFile.toAbsolutePath().toString());

			handle = jniInit();

			System.out.printf("Loaded miniaudio %s%n", getVersion());
		}
	}

	public static void destroy() {
		synchronized (lock) {
			if (handle == -1) {
				return;
			}

			jniDestroy(handle);
			handle = -1;
		}
	}

	public static String getVersion() {
		return jniGetVersion();
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
