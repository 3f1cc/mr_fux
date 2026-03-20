package com.mrfux.model;

import com.mrfux.rules.RuleEngine;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;

/**
 * Core data model: holds cantus firmus, counterpoint, and the current
 * set of violations. All musical logic lives here.
 */
public class NoteSequenceModel {

    public static final int MAX_LENGTH = 24;
    public static final int MIDI_MIN   = 36;  // C2
    public static final int MIDI_MAX   = 84;  // C6

    /** Pitch classes of natural (diatonic) notes: C D E F G A B */
    private static final Set<Integer> NATURAL_PC =
            new HashSet<>(Arrays.asList(0, 2, 4, 5, 7, 9, 11));

    // Default cantus firmus: C4 D4 E4 F4 G4 F4 E4 D4
    private static final int[] DEFAULT_CF = {60, 62, 64, 65, 67, 65, 64, 62};

    private final int[] cantus;
    private final int[] counterpoint;
    private int length;
    private List<Violation> violations;
    private final RuleEngine ruleEngine;

    public interface ChangeListener {
        void onModelChanged();
    }

    private ChangeListener changeListener;

    public NoteSequenceModel() {
        cantus       = new int[MAX_LENGTH];
        counterpoint = new int[MAX_LENGTH];
        violations   = new ArrayList<>();
        ruleEngine   = new RuleEngine();
        length       = 8;
        for (int i = 0; i < MAX_LENGTH; i++) {
            cantus[i]       = i < DEFAULT_CF.length ? DEFAULT_CF[i] : 0;
            counterpoint[i] = 0;
        }
    }

    public void setChangeListener(ChangeListener listener) {
        this.changeListener = listener;
    }

    // ---------------------------------------------------------------
    // Accessors
    // ---------------------------------------------------------------

    public int getLength() { return length; }

    public void setLength(int len) {
        length     = Math.max(4, Math.min(MAX_LENGTH, len));
        violations = new ArrayList<>();
        notifyChanged();
    }

    public int getCantus(int step)       { return cantus[step - 1]; }
    public int getCounterpoint(int step) { return counterpoint[step - 1]; }

    public void setCantus(int step, int midi)       { cantus[step - 1] = midi; }
    public void setCounterpoint(int step, int midi) { counterpoint[step - 1] = midi; }

    public List<Violation> getViolations() { return violations; }

    // ---------------------------------------------------------------
    // Pitch editing
    // ---------------------------------------------------------------

    /**
     * Step a MIDI note by |delta| diatonic steps, skipping chromatic pitches.
     * Clamps to [MIDI_MIN, MIDI_MAX].
     */
    public static int diatonicStep(int midi, int delta) {
        if (midi <= 0) midi = 60; // default to middle C if empty
        int n   = midi;
        int dir = delta > 0 ? 1 : -1;
        for (int i = 0; i < Math.abs(delta); i++) {
            do { n += dir; } while (!NATURAL_PC.contains(Math.floorMod(n, 12)));
        }
        return Math.max(MIDI_MIN, Math.min(MIDI_MAX, n));
    }

    public static boolean isNatural(int midi) {
        return NATURAL_PC.contains(Math.floorMod(midi, 12));
    }

    // ---------------------------------------------------------------
    // Rule checking
    // ---------------------------------------------------------------

    public void runChecks() {
        violations = ruleEngine.check(cantus, counterpoint, length);
    }

    /** All violations at a given (step, voice). */
    public List<Violation> violationsAt(int step, int voice) {
        List<Violation> result = new ArrayList<>();
        for (Violation v : violations) {
            if (v.step == step && v.voice == voice) result.add(v);
        }
        return result;
    }

    /** True if there is any violation at (step, voice). */
    public boolean hasViolation(int step, int voice) {
        for (Violation v : violations) {
            if (v.step == step && v.voice == voice) return true;
        }
        return false;
    }

    // ---------------------------------------------------------------
    // File I/O
    // ---------------------------------------------------------------

    public void saveToFile(File file) throws IOException, JSONException {
        runChecks();
        JSONObject obj = new JSONObject();
        obj.put("length", length);

        JSONArray cfArr = new JSONArray();
        JSONArray cpArr = new JSONArray();
        for (int i = 0; i < MAX_LENGTH; i++) {
            cfArr.put(cantus[i]);
            cpArr.put(counterpoint[i]);
        }
        obj.put("cantus", cfArr);
        obj.put("counterpoint", cpArr);

        JSONArray vArr = new JSONArray();
        for (Violation v : violations) {
            JSONObject vObj = new JSONObject();
            vObj.put("step",    v.step);
            vObj.put("voice",   v.voice);
            vObj.put("summary", v.summary);
            JSONArray rArr = new JSONArray();
            for (Violation.StepVoice r : v.related) {
                JSONObject rObj = new JSONObject();
                rObj.put("step",  r.step);
                rObj.put("voice", r.voice);
                rArr.put(rObj);
            }
            vObj.put("related", rArr);
            vArr.put(vObj);
        }
        obj.put("violations", vArr);

        try (FileWriter w = new FileWriter(file)) {
            w.write(obj.toString(2));
        }
    }

    public void loadFromFile(File file) throws IOException, JSONException {
        StringBuilder sb = new StringBuilder();
        try (FileReader r = new FileReader(file)) {
            char[] buf = new char[4096];
            int n;
            while ((n = r.read(buf)) != -1) sb.append(buf, 0, n);
        }
        JSONObject obj = new JSONObject(sb.toString());

        if (obj.has("length")) {
            length = Math.max(4, Math.min(MAX_LENGTH, obj.getInt("length")));
        }

        if (obj.has("cantus")) {
            JSONArray arr = obj.getJSONArray("cantus");
            for (int i = 0; i < MAX_LENGTH; i++) {
                cantus[i] = i < arr.length() ? arr.getInt(i) : 0;
            }
        }

        if (obj.has("counterpoint")) {
            JSONArray arr = obj.getJSONArray("counterpoint");
            for (int i = 0; i < MAX_LENGTH; i++) {
                counterpoint[i] = i < arr.length() ? arr.getInt(i) : 0;
            }
        }

        violations = new ArrayList<>();
        if (obj.has("violations")) {
            JSONArray arr = obj.getJSONArray("violations");
            for (int i = 0; i < arr.length(); i++) {
                JSONObject vObj = arr.getJSONObject(i);
                List<Violation.StepVoice> related = new ArrayList<>();
                if (vObj.has("related")) {
                    JSONArray rArr = vObj.getJSONArray("related");
                    for (int j = 0; j < rArr.length(); j++) {
                        JSONObject rObj = rArr.getJSONObject(j);
                        related.add(new Violation.StepVoice(
                                rObj.getInt("step"), rObj.getInt("voice")));
                    }
                }
                violations.add(new Violation(
                        vObj.getInt("step"),
                        vObj.getInt("voice"),
                        vObj.getString("summary"),
                        related));
            }
        }

        notifyChanged();
    }

    private void notifyChanged() {
        if (changeListener != null) changeListener.onModelChanged();
    }

    // ---------------------------------------------------------------
    // Raw array access for RuleEngine
    // ---------------------------------------------------------------

    /** Returns a copy of the cantus array (1-indexed, length MAX_LENGTH). */
    public int[] getCantusArray()       { return cantus.clone(); }
    public int[] getCounterpointArray() { return counterpoint.clone(); }
}
