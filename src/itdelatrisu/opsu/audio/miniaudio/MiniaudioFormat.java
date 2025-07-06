package itdelatrisu.opsu.audio.miniaudio;

import javax.sound.sampled.AudioFormat;
import java.nio.ByteOrder;

import javax.sound.sampled.AudioFormat.Encoding;

public enum MiniaudioFormat {
	UNKNOWN(0),
	U8(1),
	S16(2),
	S24(3),
	S32(4),
	F32(5);

	private final int value;

	MiniaudioFormat(int value) {
		this.value = value;
	}

	public static MiniaudioFormat fromAudioFormat(AudioFormat audioFormat) {
		ByteOrder byteOrder = audioFormat.isBigEndian() ? ByteOrder.BIG_ENDIAN : ByteOrder.LITTLE_ENDIAN;
		if (!byteOrder.equals(ByteOrder.nativeOrder())) {
			throw new RuntimeException("miniaudio only supports native-endian audio");
		}

		Encoding encoding = audioFormat.getEncoding();
		int sampleSize = audioFormat.getSampleSizeInBits();
		if (encoding.equals(Encoding.PCM_UNSIGNED) && sampleSize == 8) {
			return U8;
		} else if (encoding.equals(Encoding.PCM_SIGNED)) {
			switch (sampleSize) {
				case 16:
					return S16;
				case 24:
					return S24;
				case 32:
					return S32;
			}
		} else if (encoding.equals(Encoding.PCM_FLOAT) && sampleSize == 32) {
			return F32;
		}

		throw new RuntimeException("miniaudio does not support audio format: " + audioFormat);
	}

	int getValue() {
		return value;
	}
}
