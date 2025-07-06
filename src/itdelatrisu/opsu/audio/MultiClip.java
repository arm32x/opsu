/*
 * opsu! - an open-source osu! client
 * Copyright (C) 2014-2017 Jeffrey Han
 *
 * opsu! is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * opsu! is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with opsu!.  If not, see <http://www.gnu.org/licenses/>.
 */

package itdelatrisu.opsu.audio;

import itdelatrisu.opsu.ErrorHandler;
import itdelatrisu.opsu.Utils;
import itdelatrisu.opsu.audio.miniaudio.Miniaudio;
import itdelatrisu.opsu.audio.miniaudio.MiniaudioFormat;
import itdelatrisu.opsu.audio.miniaudio.MiniaudioSound;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.Objects;

import javax.sound.sampled.AudioFormat;
import javax.sound.sampled.AudioInputStream;
import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.Clip;
import javax.sound.sampled.DataLine;
import javax.sound.sampled.FloatControl;
import javax.sound.sampled.LineListener;
import javax.sound.sampled.LineUnavailableException;

/**
 * Extension of Clip that allows playing multiple copies of a Clip simultaneously.
 * http://stackoverflow.com/questions/1854616/
 *
 * @author fluddokt (https://github.com/fluddokt)
 */
public class MultiClip {
	/** Maximum number of extra clips that can be created at one time. */
	private static final int MAX_CLIPS = 20;

	/** A list of all created MultiClips. */
	private static final LinkedList<MultiClip> ALL_MULTICLIPS = new LinkedList<MultiClip>();

	/** Size of a single buffer. */
	private static final int BUFFER_SIZE = 0x1000;

	/** Current number of extra clips created. */
	private static int extraClips = 0;

	/** Current number of clip-closing threads in execution. */
	private static int closingThreads = 0;

	/** A list of clips used for this audio sample. */
	private LinkedList<MiniaudioSound> clips = new LinkedList<>();

	/** The audio input stream. */
	private AudioInputStream audioIn;

	/** The format of this audio sample. */
	private MiniaudioFormat format;

	/** The number of channels in this audio sample (usually mono or stereo). */
	private int channels;

	/** The sample rate of this audio sample. */
	private int sampleRate;

	/** The data for this audio sample. */
	private ByteBuffer audioData;

	/** The name given to this clip. */
	private final String name;

	/**
	 * Constructor.
	 * @param name the clip name
	 * @param audioIn the associated AudioInputStream
	 * @throws IOException if an input or output error occurs
	 */
	public MultiClip(String name, AudioInputStream audioIn) throws IOException {
		this.name = name;
		this.audioIn = audioIn;
		if (audioIn != null) {
			AudioFormat audioFormat = audioIn.getFormat();
			format = MiniaudioFormat.fromAudioFormat(audioFormat);
			channels = audioFormat.getChannels();
			sampleRate = (int) audioFormat.getSampleRate();

			LinkedList<byte[]> allBufs = new LinkedList<byte[]>();

			int totalRead = 0;
			boolean hasData = true;
			while (hasData) {
				totalRead = 0;
				byte[] tbuf = new byte[BUFFER_SIZE];
				while (totalRead < tbuf.length) {
					int read = audioIn.read(tbuf, totalRead, tbuf.length - totalRead);
					if (read < 0) {
						hasData = false;
						break;
					}
					totalRead += read;
				}
				allBufs.add(tbuf);
			}

			audioData = ByteBuffer.allocateDirect((allBufs.size() - 1) * BUFFER_SIZE + totalRead);

			int cnt = 0;
			for (byte[] tbuf : allBufs) {
				int size = BUFFER_SIZE;
				if (cnt == allBufs.size() - 1)
					size = totalRead;
				audioData.put(tbuf, 0, size);
				cnt++;
			}
		}
		getClip();
		ALL_MULTICLIPS.add(this);
	}

	/**
	 * Returns the name of the clip.
	 * @return the name
	 */
	public String getName() { return name; }

	/**
	 * Plays the clip with the specified volume.
	 * @param volume the volume the play at
	 * @param listener the line listener
	 * @throws LineUnavailableException if a clip object is not available or
	 *         if the line cannot be opened due to resource restrictions
	 */
	public void start(float volume, LineListener listener) throws LineUnavailableException {
		MiniaudioSound clip = getClip();
		if (clip == null)
			return;

		clip.setVolume(volume);
		// TODO: Implement callbacks
//		if (listener != null)
//			clip.addLineListener(listener);
		clip.seekToPcmFrame(0);
		clip.start();
	}

	/**
	 * Stops the clip, if active.
	 */
	public void stop() {
		MiniaudioSound clip = getClip();
		if (clip == null)
			return;

		if (clip.isPlaying())
			clip.stop();
	}

	/**
	 * Returns a Clip that is not playing from the list.
	 * If no clip is available, then a new one is created if under MAX_CLIPS.
	 * Otherwise, an existing clip will be returned.
	 * @return the Clip to play
	 */
	private MiniaudioSound getClip() {
		// TODO:
		// Occasionally, even when clips are being closed in a separate thread,
		// playing any clip will cause the game to hang until all clips are
		// closed.  Why?
		if (closingThreads > 0)
			return null;

		// search for existing stopped clips
		for (Iterator<MiniaudioSound> iter = clips.iterator(); iter.hasNext();) {
			MiniaudioSound c = iter.next();
			if (!c.isPlaying()) {
				iter.remove();
				clips.add(c);
				return c;
			}
		}

		MiniaudioSound c = null;
		if (extraClips >= MAX_CLIPS) {
			// use an existing clip
			if (clips.isEmpty())
				return null;
			c = clips.removeFirst();
			c.stop();
			clips.add(c);
		} else {
			// create a new clip
			c = MiniaudioSound.fromDirectByteBuffer(Miniaudio.getInstance(), audioData, format, channels, sampleRate);

			clips.add(c);
			if (clips.size() != 1)
				extraClips++;
		}
		return c;
	}

	/**
	 * Destroys the MultiClip and releases all resources.
	 */
	public void destroy() {
		if (clips.size() > 0) {
			for (MiniaudioSound c : clips) {
				c.stop();
				c.destroy();
			}
			extraClips -= clips.size() - 1;
			clips = new LinkedList<>();
		}
		audioData = null;
		if (audioIn != null) {
			try {
				audioIn.close();
			} catch (IOException e) {
				ErrorHandler.error(String.format("Could not close AudioInputStream for MultiClip %s.", name), e, true);
			}
		}
	}

	/**
	 * Destroys all extra clips.
	 */
	public static void destroyExtraClips() {
		if (extraClips == 0)
			return;

		// find all extra clips
		final LinkedList<MiniaudioSound> clipsToClose = new LinkedList<>();
		for (MultiClip mc : MultiClip.ALL_MULTICLIPS) {
			for (Iterator<MiniaudioSound> iter = mc.clips.iterator(); iter.hasNext();) {
				MiniaudioSound c = iter.next();
				if (mc.clips.size() > 1) {  // retain last Clip in list
					iter.remove();
					clipsToClose.add(c);
				}
			}
		}

		// close clips in a new thread
		new Thread() {
			@Override
			public void run() {
				closingThreads++;
				for (MiniaudioSound c : clipsToClose) {
					c.stop();
					c.destroy();
				}
				closingThreads--;
			}
		}.start();

		// reset extra clip count
		extraClips = 0;
	}
}
