package com.mrfux.audio;

import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.os.Handler;
import android.os.Looper;

import com.mrfux.model.NoteSequenceModel;

import java.util.Random;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Step-by-step playback using Karplus–Strong physical-model synthesis.
 *
 * The algorithm models a plucked string (harpsichord / lute timbre) with a
 * natural exponential decay whose rate increases with pitch, matching the
 * behaviour of a real acoustic instrument.  It is historically appropriate
 * for Renaissance counterpoint exercises in the style of Fux.
 *
 * Architecture improvements over the previous sine-wave implementation:
 *   • CF and CP voices are mixed into a single sample buffer per step, so
 *     they are always in phase and cannot drift relative to each other.
 *   • A single AudioTrack runs in STREAM mode for the entire playback
 *     session; write() naturally blocks for one step-duration once the
 *     internal buffer is full, giving low-jitter timing without polling.
 *   • No per-note thread or AudioTrack is created, eliminating the startup
 *     latency that caused clicks and glitches in the previous design.
 */
public class PlaybackController {

    private static final int   SAMPLE_RATE  = 44100;
    private static final float STEP_SECS    = 0.5f;
    private static final int   STEP_SAMPLES = (int)(SAMPLE_RATE * STEP_SECS);

    private final Handler           handler = new Handler(Looper.getMainLooper());
    private final NoteSequenceModel model;

    private final AtomicBoolean playing   = new AtomicBoolean(false);
    private volatile int        soloVoice = 0;
    private Thread              audioThread;

    public interface Listener {
        void onStep(int step);   // 1-indexed, always on main thread
        void onStop();           // always on main thread
    }
    private Listener listener;

    public PlaybackController(NoteSequenceModel model) { this.model = model; }

    public void setListener(Listener l) { listener = l; }
    public boolean isPlaying()          { return playing.get(); }

    // ---------------------------------------------------------------
    // Control API  (always called from the main thread)
    // ---------------------------------------------------------------

    public void start(int soloVoice) {
        stop();
        this.soloVoice = soloVoice;
        playing.set(true);
        audioThread = new Thread(this::runAudio, "mr_fux_audio");
        audioThread.setDaemon(true);
        audioThread.start();
    }

    public void stop() {
        if (playing.getAndSet(false) && listener != null) {
            listener.onStop();   // immediate notification on the main thread
        }
        Thread t = audioThread;
        audioThread = null;
        if (t != null) t.interrupt();
    }

    // ---------------------------------------------------------------
    // Audio rendering loop  (runs on audioThread)
    // ---------------------------------------------------------------

    private void runAudio() {
        int minBuf = AudioTrack.getMinBufferSize(SAMPLE_RATE,
                AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT);
        // Buffer size = exactly one step.  Once it is full, the next write()
        // call blocks until the playing head has consumed the previous step,
        // so we get per-step timing for free without any sleep or polling.
        int bufSize = Math.max(minBuf, STEP_SAMPLES * 2 /* bytes, 16-bit PCM */);

        AudioTrack track = new AudioTrack(
                AudioManager.STREAM_MUSIC, SAMPLE_RATE,
                AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT,
                bufSize, AudioTrack.MODE_STREAM);
        track.play();

        try {
            int length = model.getLength();
            for (int step = 1; step <= length && playing.get(); step++) {
                int cfMidi = soloVoice != 2 ? model.getCantus(step)       : 0;
                int cpMidi = soloVoice != 1 ? model.getCounterpoint(step) : 0;

                writeAll(track, renderStep(cfMidi, cpMidi));

                // Notify the UI after the write so the cursor advances when
                // the note actually starts playing.
                final int s = step;
                handler.post(() -> { if (listener != null) listener.onStep(s); });
            }
            // One extra silent step so the last note can ring out naturally.
            if (playing.get()) {
                writeAll(track, new short[STEP_SAMPLES]);
            }
        } finally {
            track.stop();
            track.release();
        }

        // Fire onStop for a natural end.  An external stop() call already
        // fired it on the main thread, so only act if playing was still true.
        if (playing.getAndSet(false) && listener != null) {
            handler.post(() -> listener.onStop());
        }
    }

    /** Write all samples to the track, handling partial writes in STREAM mode. */
    private static void writeAll(AudioTrack track, short[] buf) {
        int offset = 0;
        while (offset < buf.length) {
            int n = track.write(buf, offset, buf.length - offset);
            if (n <= 0) break;
            offset += n;
        }
    }

    // ---------------------------------------------------------------
    // Per-step mixing
    // ---------------------------------------------------------------

    private short[] renderStep(int cfMidi, int cpMidi) {
        boolean twoVoices = cfMidi > 0 && cpMidi > 0 && cfMidi != cpMidi;
        double[] cfBuf = cfMidi > 0 ? karplusStrong(cfMidi) : null;
        // Skip duplicate generation for unison intervals.
        double[] cpBuf = (cpMidi > 0 && cpMidi != cfMidi) ? karplusStrong(cpMidi) : null;

        // Two voices can sum to ±2.0; scale each by 0.45 → max ±0.9 full-scale.
        // Single voice (or unison played as one): scale by 0.80.
        double gain = twoVoices ? 0.45 : 0.80;

        short[] out = new short[STEP_SAMPLES];
        for (int i = 0; i < STEP_SAMPLES; i++) {
            double v = 0;
            if (cfBuf != null) v += cfBuf[i];
            if (cpBuf != null) v += cpBuf[i];
            out[i] = (short) Math.max(-32767, Math.min(32767, (int)(v * gain * 32767)));
        }
        return out;
    }

    // ---------------------------------------------------------------
    // Karplus–Strong synthesis
    // ---------------------------------------------------------------

    /**
     * Generates {@link #STEP_SAMPLES} samples of a plucked-string tone at the
     * given MIDI pitch using the Karplus–Strong algorithm.
     *
     * <p>Steps:
     * <ol>
     *   <li>Fill a ring buffer of size {@code N ≈ sampleRate / freq} with
     *       bandlimited white noise (one pass of the averaging filter).</li>
     *   <li>For each output sample: emit the ring-buffer head, then replace it
     *       with the average of itself and its neighbour.  This low-pass
     *       feedback filter drives exponential decay of the oscillation.</li>
     * </ol>
     *
     * <p>Because higher frequencies use shorter ring buffers, the filter
     * attenuates them more strongly per unit time, so high notes decay faster
     * than low notes — exactly as on a real plucked-string instrument.
     */
    private double[] karplusStrong(int midiNote) {
        double freq   = 440.0 * Math.pow(2.0, (midiNote - 69) / 12.0);
        int    period = Math.max(2, (int) Math.round(SAMPLE_RATE / freq));

        // Excitation: seed ring buffer with white noise, then bandlimit it
        // with one pass of the same averaging filter used in the main loop.
        double[] ring = new double[period];
        Random rng = new Random(midiNote);   // deterministic seed → consistent timbre
        for (int i = 0; i < period; i++) ring[i] = rng.nextDouble() * 2.0 - 1.0;
        double prev = ring[period - 1];
        for (int i = 0; i < period; i++) {
            double cur = ring[i];
            ring[i] = (cur + prev) * 0.5;
            prev = cur;
        }

        // K-S recurrence: output current head, then average with next neighbour.
        double[] out = new double[STEP_SAMPLES];
        int ptr = 0;
        for (int i = 0; i < STEP_SAMPLES; i++) {
            out[i]    = ring[ptr];
            ring[ptr] = (ring[ptr] + ring[(ptr + 1) % period]) * 0.5;
            ptr = (ptr + 1) % period;
        }
        return out;
    }
}
