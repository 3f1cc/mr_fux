package com.mrfux.model;

import java.util.ArrayList;
import java.util.List;

/**
 * A single counterpoint rule violation.
 */
public class Violation {

    public static class StepVoice {
        public final int step;
        public final int voice;

        public StepVoice(int step, int voice) {
            this.step = step;
            this.voice = voice;
        }
    }

    public final int step;
    public final int voice;
    public final String summary;
    public final List<StepVoice> related;

    public Violation(int step, int voice, String summary, List<StepVoice> related) {
        this.step = step;
        this.voice = voice;
        this.summary = summary;
        this.related = related != null ? related : new ArrayList<>();
    }

    /** True if this violation is advisory (summary starts with '*'). */
    public boolean isAdvisory() {
        return summary != null && summary.startsWith("*");
    }
}
