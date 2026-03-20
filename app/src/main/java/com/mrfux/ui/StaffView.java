package com.mrfux.ui;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.util.AttributeSet;
import android.view.MotionEvent;
import android.view.View;

import com.mrfux.model.NoteSequenceModel;
import com.mrfux.model.Violation;

import java.util.List;

/**
 * Grand staff view for mr_fux.
 *
 * Coordinate system mirrors the original Norns 128×64 pixel display,
 * scaled uniformly to fill the view width while maintaining the 2:1
 * aspect ratio.  All "px" values below are in the original 128×64 space;
 * multiply by {@link #scale} to get screen pixels.
 *
 * Staff constants (original pixel space):
 *   STEP        = 2   pixels per diatonic step
 *   MIDDLE_C_Y  = 36  screen Y for middle C
 *   Treble lines at diatonic positions:  +2 +4 +6 +8 +10 (E4-F5)
 *   Bass   lines at diatonic positions:  -2 -4 -6 -8 -10 (A3-G2)
 *
 * Touch gestures:
 *   Tap   → set cursor to nearest step
 *   Swipe up/down on a step → raise/lower pitch of active voice
 */
public class StaffView extends View {

    // ---------------------------------------------------------------
    // Original coordinate constants (128×64 space)
    // ---------------------------------------------------------------
    private static final float STEP       = 2f;
    private static final float MIDDLE_C_Y = 36f;
    private static final float STAFF_X1   = 2f;
    private static final float STAFF_X2   = 126f;

    private static final int[] TREBLE_LINES = {2, 4, 6, 8, 10};
    private static final int[] BASS_LINES   = {-2, -4, -6, -8, -10};

    private static final int[] PC_TO_DIA = {0,0,1,1,2,3,3,4,4,5,5,6};

    // Note layout — narrow mode (layout=2) is the default
    private float noteX0 = 14f;
    private float noteDx = 7f;

    // ---------------------------------------------------------------
    // Grayscale levels (0–15) → alpha on white, on black background
    // ---------------------------------------------------------------
    private static int levelColor(int level) {
        int v = Math.round(level * 255f / 15f);
        return 0xFF000000 | (v << 16) | (v << 8) | v;
    }

    // ---------------------------------------------------------------
    // State
    // ---------------------------------------------------------------
    private NoteSequenceModel model;
    private float scale = 1f;

    // UI state injected from MainActivity
    private int     cursor      = 1;
    private int     activeVoice = 1;
    private boolean checkMode   = false;
    private boolean playing     = false;
    private int     playPos     = 0;

    // Check-mode per-note brightness (set externally)
    private int[]   cfLevels;   // [step-1] brightness level 0-15
    private int[]   cpLevels;

    // Flash state for related notes
    private int flashLevel = 6; // alternates between 6 and 12

    // Scroll
    private float scrollOffset = 0f; // in original pixels

    // Paints
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);

    // Music font (Bravura, SMuFL)
    private Typeface musicTypeface = null;

    private Typeface getMusicTypeface() {
        if (musicTypeface == null) {
            try {
                musicTypeface = Typeface.createFromAsset(getContext().getAssets(), "fonts/Bravura.otf");
            } catch (Exception e) {
                musicTypeface = Typeface.DEFAULT;
            }
        }
        return musicTypeface;
    }

    // Text sizes for Bravura glyphs.
    // At 16*scale, 1 em = 4 staff spaces (exact SMuFL match), but that makes
    // noteheadWhole (advance 422/1000 em = 6.75 units) nearly fill the 7-unit
    // narrow note step, leaving no gap.  Using smaller sizes keeps proportions
    // acceptable while giving visible breathing room between glyphs.
    private float clefTextSize() { return 12f * scale; }   // slightly smaller clefs
    private float noteTextSize() { return 11f * scale; }   // notehead ≈ 4.6 units wide

    // Touch tracking for swipe
    private float touchDownX, touchDownY;
    private int   touchStep = -1;
    private boolean touchMoved = false;

    public interface Listener {
        void onCursorChanged(int step);
        void onPitchSwipe(int semitoneSteps); // positive = up, negative = down
    }

    private Listener listener;

    // ---------------------------------------------------------------
    // Constructors
    // ---------------------------------------------------------------

    public StaffView(Context context) {
        super(context);
    }

    public StaffView(Context context, AttributeSet attrs) {
        super(context, attrs);
    }

    public StaffView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
    }

    // ---------------------------------------------------------------
    // Public API
    // ---------------------------------------------------------------

    public void setModel(NoteSequenceModel m)      { model = m; }
    public void setListener(Listener l)            { listener = l; }
    public void setCursor(int c)                   { cursor = c; updateScroll(); invalidate(); }
    public void setActiveVoice(int v)              { activeVoice = v; invalidate(); }
    public void setCheckMode(boolean c)            { checkMode = c; invalidate(); }
    public void setPlaying(boolean p)              { playing = p; invalidate(); }
    public void setPlayPos(int p)                  { playPos = p; invalidate(); }
    public void setFlashLevel(int l)               { flashLevel = l; invalidate(); }
    public void setNoteLevels(int[] cf, int[] cp)  { cfLevels = cf; cpLevels = cp; invalidate(); }

    public void setLayout(boolean narrow) {
        if (narrow) { noteX0 = 14f; noteDx = 7f; }
        else        { noteX0 = 18f; noteDx = 14f; }
        scrollOffset = 0f;
        updateScroll();
        invalidate();
    }

    // ---------------------------------------------------------------
    // Size
    // ---------------------------------------------------------------

    @Override
    protected void onSizeChanged(int w, int h, int oldw, int oldh) {
        super.onSizeChanged(w, h, oldw, oldh);
        // Scale uniformly to fit both dimensions of the original 128×64 space.
        scale = Math.min(w / 128f, h / 64f);
        updateScroll();
    }

    @Override
    protected void onMeasure(int widthSpec, int heightSpec) {
        int w = MeasureSpec.getSize(widthSpec);
        int desiredH = w / 2; // 2:1 aspect ratio matches Norns 128×64
        setMeasuredDimension(w, resolveSize(desiredH, heightSpec));
    }

    // ---------------------------------------------------------------
    // Coordinate helpers
    // ---------------------------------------------------------------

    private float staffY(int pos) {
        return (MIDDLE_C_Y - pos * STEP) * scale;
    }

    private float noteX(int step) {
        return (noteX0 + (step - 1) * noteDx - scrollOffset) * scale;
    }

    private int midiToStaffPos(int midi) {
        if (midi <= 0) return Integer.MIN_VALUE;
        int octave = midi / 12 - 5;
        int pc     = midi % 12;
        return octave * 7 + PC_TO_DIA[pc];
    }

    private void updateScroll() {
        if (model == null) return;
        float margin = noteDx;
        float x = noteX0 + (cursor - 1) * noteDx;
        if (x - scrollOffset < STAFF_X1 + margin) {
            scrollOffset = x - STAFF_X1 - margin;
        } else if (x - scrollOffset > STAFF_X2 - margin) {
            scrollOffset = x - STAFF_X2 + margin;
        }
        if (scrollOffset < 0) scrollOffset = 0;
    }

    // ---------------------------------------------------------------
    // Drawing
    // ---------------------------------------------------------------

    @Override
    protected void onDraw(Canvas canvas) {
        if (model == null) return;

        canvas.drawColor(0xFF000000);

        drawStaves(canvas);

        int length = model.getLength();

        // Pass 1: cursor markers and ledger lines
        for (int i = 1; i <= length; i++) {
            float x = noteX(i);
            if (x < (STAFF_X1 - noteDx) * scale || x > (STAFF_X2 + noteDx) * scale) continue;

            // Cursor marker below bass staff
            if (i == cursor) {
                float markY = staffY(BASS_LINES[BASS_LINES.length - 1]) + 3 * scale;
                paint.setColor(levelColor(6));
                paint.setStyle(Paint.Style.FILL);
                if (activeVoice == 1) {
                    canvas.drawRect(x - 2 * scale, markY, x + 3 * scale, markY + scale, paint);
                } else {
                    canvas.drawRect(x - scale, markY, x + scale, markY + 2 * scale, paint);
                }
            }

            // Ledger lines
            int cfMidi = model.getCantus(i);
            int cpMidi = model.getCounterpoint(i);
            int cfPos  = midiToStaffPos(cfMidi);
            int cpPos  = midiToStaffPos(cpMidi);
            if (cfMidi > 0) drawLedger(canvas, x, cfPos);
            if (cpMidi > 0) drawLedger(canvas, x, cpPos);
        }

        // Pass 2: note heads
        for (int i = 1; i <= length; i++) {
            float x = noteX(i);
            if (x < (STAFF_X1 - noteDx) * scale || x > (STAFF_X2 + noteDx) * scale) continue;

            int cfMidi = model.getCantus(i);
            int cpMidi = model.getCounterpoint(i);
            int cfPos  = midiToStaffPos(cfMidi);
            int cpPos  = midiToStaffPos(cpMidi);

            int cfLv = noteLevelCf(i);
            int cpLv = noteLevelCp(i);

            // Draw CP before CF so CF always paints on top
            if (cpMidi > 0) drawCpNote(canvas, x, staffY(cpPos), cpLv);
            if (cfMidi > 0) drawCfNote(canvas, x, staffY(cfPos), cfLv);
        }

        // Clefs drawn last so they always appear above scrolled notes
        drawTrebleClef(canvas);
        drawBassClef(canvas);
    }

    private int noteLevelCf(int step) {
        if (checkMode) {
            return cfLevels != null && step <= cfLevels.length ? cfLevels[step - 1] : 3;
        }
        boolean playingHere = playing && step == playPos;
        if (playingHere)                              return 15;
        if (step == cursor && activeVoice == 1)       return 15;
        if (step == cursor)                           return 13;
        return 11;
    }

    private int noteLevelCp(int step) {
        if (checkMode) {
            return cpLevels != null && step <= cpLevels.length ? cpLevels[step - 1] : 3;
        }
        boolean playingHere = playing && step == playPos;
        if (playingHere)                              return 15;
        if (step == cursor && activeVoice == 2)       return 15;
        if (step == cursor)                           return 13;
        return 11;
    }

    private void drawStaves(Canvas canvas) {
        paint.setStyle(Paint.Style.FILL_AND_STROKE);
        paint.setStrokeWidth(1f);
        paint.setColor(levelColor(8));

        float x1 = STAFF_X1 * scale;
        float x2 = STAFF_X2 * scale;

        for (int pos : TREBLE_LINES) {
            float y = staffY(pos);
            canvas.drawLine(x1, y, x2, y, paint);
        }
        for (int pos : BASS_LINES) {
            float y = staffY(pos);
            canvas.drawLine(x1, y, x2, y, paint);
        }
        // Barline on the left
        canvas.drawLine(x1, staffY(TREBLE_LINES[TREBLE_LINES.length - 1]),
                        x1, staffY(BASS_LINES[BASS_LINES.length - 1]), paint);
    }

    private void drawLedger(Canvas canvas, float x, int pos) {
        paint.setColor(levelColor(8));
        paint.setStyle(Paint.Style.FILL_AND_STROKE);
        paint.setStrokeWidth(1f);
        float halfW = 4 * scale;

        // Middle C
        if (pos == 0) {
            float y = staffY(0);
            canvas.drawLine(x - halfW, y, x + halfW, y, paint);
        }
        // Above treble
        for (int p = 12; p <= pos; p += 2) {
            float y = staffY(p);
            canvas.drawLine(x - halfW, y, x + halfW, y, paint);
        }
        // Below bass
        for (int p = -12; p >= pos; p -= 2) {
            float y = staffY(p);
            canvas.drawLine(x - halfW, y, x + halfW, y, paint);
        }
    }

    /**
     * Draw the treble (G) clef using the Bravura music font.
     * SMuFL U+E050: glyph origin sits on the G4 line.
     */
    private void drawTrebleClef(Canvas canvas) {
        paint.setTypeface(getMusicTypeface());
        paint.setTextSize(clefTextSize());
        paint.setColor(levelColor(10));
        paint.setStyle(Paint.Style.FILL);
        paint.setTextAlign(Paint.Align.LEFT);
        canvas.drawText("\uE050", STAFF_X1 * scale, staffY(4), paint);
    }

    /**
     * Draw the bass (F) clef using the Bravura music font.
     * SMuFL U+E062: glyph origin sits on the F3 line.
     */
    private void drawBassClef(Canvas canvas) {
        paint.setTypeface(getMusicTypeface());
        paint.setTextSize(clefTextSize());
        paint.setColor(levelColor(10));
        paint.setStyle(Paint.Style.FILL);
        paint.setTextAlign(Paint.Align.LEFT);
        canvas.drawText("\uE062", STAFF_X1 * scale, staffY(-4), paint);
    }

    /**
     * Draw a cantus firmus whole notehead (SMuFL U+E0A2, round open oval).
     * Glyph origin is horizontally at the left edge; use CENTER align so the
     * notehead is centred on x.  Vertically, the SMuFL origin sits on the
     * staff line (baseline = note position), matching Android drawText baseline.
     */
    private void drawCfNote(Canvas canvas, float x, float y, int level) {
        paint.setTypeface(getMusicTypeface());
        paint.setTextSize(noteTextSize());
        paint.setColor(levelColor(level));
        paint.setStyle(Paint.Style.FILL);
        paint.setTextAlign(Paint.Align.CENTER);
        canvas.drawText("\uE0A2", x, y, paint);
    }

    /**
     * Draw a counterpoint diamond whole notehead (SMuFL U+E0D8 noteheadDiamondWhole).
     * U+E0D8 is the open/hollow diamond whole note (2-contour glyph); U+E0DB is
     * noteheadDiamondBlack (filled), which was used incorrectly before.
     */
    private void drawCpNote(Canvas canvas, float x, float y, int level) {
        paint.setTypeface(getMusicTypeface());
        paint.setTextSize(noteTextSize());
        paint.setColor(levelColor(level));
        paint.setStyle(Paint.Style.FILL);
        paint.setTextAlign(Paint.Align.CENTER);
        canvas.drawText("\uE0D8", x, y, paint);
    }

    // ---------------------------------------------------------------
    // Touch
    // ---------------------------------------------------------------

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        if (model == null) return true;
        float px = event.getX();
        float py = event.getY();

        switch (event.getAction()) {
            case MotionEvent.ACTION_DOWN:
                touchDownX   = px;
                touchDownY   = py;
                touchMoved   = false;
                touchStep    = xToStep(px);
                return true;

            case MotionEvent.ACTION_MOVE:
                float dy = py - touchDownY;
                if (Math.abs(dy) > 8 * scale) {
                    touchMoved = true;
                }
                return true;

            case MotionEvent.ACTION_UP:
                if (!touchMoved) {
                    // Tap: move cursor
                    int step = xToStep(px);
                    if (step >= 1 && step <= model.getLength() && listener != null) {
                        listener.onCursorChanged(step);
                    }
                } else {
                    // Swipe: change pitch
                    float dy2 = py - touchDownY;
                    int steps = (int)(-dy2 / (noteDx * scale)); // swipe up = positive
                    if (steps != 0 && listener != null) {
                        listener.onPitchSwipe(steps);
                    }
                }
                return true;
        }
        return super.onTouchEvent(event);
    }

    /** Convert an x pixel coordinate to the nearest step (1-indexed). */
    private int xToStep(float px) {
        float origX = px / scale + scrollOffset;
        int step = Math.round((origX - noteX0) / noteDx) + 1;
        return Math.max(1, Math.min(model.getLength(), step));
    }

    // ---------------------------------------------------------------
    // Check-mode level computation (called by MainActivity)
    // ---------------------------------------------------------------

    /**
     * Compute per-note brightness arrays for check mode.
     *
     * @param violations   all violations
     * @param cursorStep   current cursor position
     * @param cursorVoice  active voice at cursor
     * @param issueIdx     which issue at cursor is selected (0-indexed)
     * @param flash        current flash brightness for related notes
     * @param length       sequence length
     */
    public static void computeCheckLevels(
            List<Violation> violations,
            int cursorStep, int cursorVoice, int issueIdx,
            int flash, int length,
            int[] outCf, int[] outCp) {

        // Determine related notes for the currently displayed issue
        Violation currentIssue = null;
        int count = 0;
        for (Violation v : violations) {
            if (v.step == cursorStep && v.voice == cursorVoice) {
                if (count == issueIdx) { currentIssue = v; break; }
                count++;
            }
        }

        // Build sets of violating steps
        boolean[] cfViolated = new boolean[length + 1];
        boolean[] cpViolated = new boolean[length + 1];
        for (Violation v : violations) {
            if (v.step >= 1 && v.step <= length) {
                if (v.voice == 1) cfViolated[v.step] = true;
                else              cpViolated[v.step] = true;
            }
        }

        // Build sets of related notes
        boolean[][] related = new boolean[length + 1][3]; // [step][voice]
        if (currentIssue != null) {
            for (Violation.StepVoice r : currentIssue.related) {
                if (r.step >= 1 && r.step <= length && r.voice >= 1 && r.voice <= 2) {
                    related[r.step][r.voice] = true;
                }
            }
        }

        for (int i = 1; i <= length; i++) {
            // CF
            if (related[i][1]) {
                outCf[i - 1] = flash;
            } else if (i == cursorStep && 1 == cursorVoice) {
                outCf[i - 1] = cfViolated[i] ? 15 : 4;
            } else if (cfViolated[i]) {
                outCf[i - 1] = 11;
            } else {
                outCf[i - 1] = 3;
            }
            // CP
            if (related[i][2]) {
                outCp[i - 1] = flash;
            } else if (i == cursorStep && 2 == cursorVoice) {
                outCp[i - 1] = cpViolated[i] ? 15 : 4;
            } else if (cpViolated[i]) {
                outCp[i - 1] = 11;
            } else {
                outCp[i - 1] = 3;
            }
        }
    }
}
