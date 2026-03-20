package com.mrfux.audio;

import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.os.Handler;
import android.os.Looper;

import com.mrfux.model.NoteSequenceModel;

/**
 * Step-by-step playback at 500 ms per step.
 * Generates sine-wave tones via AudioTrack.
 */
public class PlaybackController {

    private static final int   SAMPLE_RATE   = 44100;
    private static final float NOTE_DURATION = 0.42f; // seconds, slightly less than step
    private static final float STEP_DURATION = 0.5f;  // seconds per step

    private final Handler   handler = new Handler(Looper.getMainLooper());
    private NoteSequenceModel model;

    private boolean playing     = false;
    private int     playPos     = 0;      // 0-indexed
    private int     soloVoice   = 0;      // 0=both, 1=CF only, 2=CP only
    private Runnable stepRunnable;

    public interface Listener {
        void onStep(int step);   // 1-indexed
        void onStop();
    }

    private Listener listener;

    public PlaybackController(NoteSequenceModel model) {
        this.model = model;
    }

    public void setListener(Listener l) { listener = l; }
    public boolean isPlaying()          { return playing; }

    public void start(int soloVoice) {
        if (playing) stop();
        this.soloVoice = soloVoice;
        playing = true;
        playPos = 0;
        scheduleStep();
    }

    public void stop() {
        playing = false;
        if (stepRunnable != null) {
            handler.removeCallbacks(stepRunnable);
            stepRunnable = null;
        }
        if (listener != null) listener.onStop();
    }

    private void scheduleStep() {
        stepRunnable = () -> {
            if (!playing) return;
            playPos++;
            int length = model.getLength();
            if (playPos > length) {
                playing = false;
                stepRunnable = null;
                if (listener != null) listener.onStop();
                return;
            }
            // Play notes
            int cfMidi = soloVoice != 2 ? model.getCantus(playPos) : 0;
            int cpMidi = soloVoice != 1 ? model.getCounterpoint(playPos) : 0;
            playNotes(cfMidi, cpMidi);

            if (listener != null) listener.onStep(playPos);

            // Schedule next step
            handler.postDelayed(stepRunnable, (long)(STEP_DURATION * 1000));
        };
        handler.post(stepRunnable);
    }

    private void playNotes(int cf, int cp) {
        if (cf > 0) playNote(cf);
        if (cp > 0 && cp != cf) playNote(cp);
        else if (cp > 0 && cp == cf) playNote(cf); // unison
    }

    private void playNote(final int midiNote) {
        new Thread(() -> {
            double freq = 440.0 * Math.pow(2.0, (midiNote - 69) / 12.0);
            int numSamples = (int)(SAMPLE_RATE * NOTE_DURATION);
            short[] buffer = new short[numSamples];

            int attackSamples = (int)(SAMPLE_RATE * 0.01);
            int releaseSamples = (int)(SAMPLE_RATE * 0.08);

            for (int i = 0; i < numSamples; i++) {
                double t = i / (double) SAMPLE_RATE;
                double sine = Math.sin(2 * Math.PI * freq * t);

                // Simple envelope
                double env;
                if (i < attackSamples) {
                    env = (double) i / attackSamples;
                } else if (i > numSamples - releaseSamples) {
                    env = (double)(numSamples - i) / releaseSamples;
                } else {
                    env = 1.0;
                }

                buffer[i] = (short)(env * sine * 32767 * 0.45);
            }

            int minBuf = AudioTrack.getMinBufferSize(SAMPLE_RATE,
                    AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT);
            int bufSize = Math.max(minBuf, numSamples * 2);

            AudioTrack track = new AudioTrack(
                    AudioManager.STREAM_MUSIC, SAMPLE_RATE,
                    AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT,
                    bufSize, AudioTrack.MODE_STATIC);
            track.write(buffer, 0, numSamples);
            track.play();

            // Release after note finishes
            try { Thread.sleep((long)(NOTE_DURATION * 1000) + 50); }
            catch (InterruptedException ignored) {}
            track.stop();
            track.release();
        }).start();
    }
}
