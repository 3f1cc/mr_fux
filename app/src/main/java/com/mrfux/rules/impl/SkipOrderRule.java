package com.mrfux.rules.impl;

import com.mrfux.model.Violation;
import com.mrfux.rules.Rule;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * Rules for same-direction skips (AM3):
 *  (a) second skip must be smaller than first
 *  (b) span must not be dissonant
 *  (c) span must not exceed octave
 *  (d) no three or more consecutive same-direction skips
 */
public class SkipOrderRule implements Rule {

    private static final Set<Integer> DISSONANT =
            new HashSet<>(Arrays.asList(1, 2, 5, 6, 10, 11));

    @Override public String name() { return "skip-order"; }
    @Override public String type() { return "melodic"; }

    @Override
    public List<Violation> check(int[] cf, int[] cp, int length) {
        List<Violation> result = new ArrayList<>();
        checkVoice(cf, 1, length, result);
        checkVoice(cp, 2, length, result);
        return result;
    }

    private void checkVoice(int[] notes, int voice, int length, List<Violation> result) {
        for (int i = 2; i < length; i++) {
            if (notes[i] > 0 && notes[i-1] > 0 && notes[i-2] > 0) {
                int d1 = notes[i-1] - notes[i-2];
                int d2 = notes[i]   - notes[i-1];
                boolean sameDir   = (d1 > 0 && d2 > 0) || (d1 < 0 && d2 < 0);
                boolean firstSkip  = Math.abs(d1) >= 3 && Math.abs(d1) <= 5;
                boolean secondSkip = Math.abs(d2) >= 3 && Math.abs(d2) <= 5;

                if (sameDir && firstSkip && secondSkip) {
                    // (a) second skip must be strictly smaller
                    if (Math.abs(d2) >= Math.abs(d1)) {
                        result.add(new Violation(i + 1, voice, "skip not smaller", Arrays.asList(
                                new Violation.StepVoice(i - 1, voice),
                                new Violation.StepVoice(i,     voice))));
                    }
                    // (b) span must not be dissonant
                    int spanIc = Math.abs(notes[i] - notes[i-2]) % 12;
                    if (DISSONANT.contains(spanIc)) {
                        result.add(new Violation(i + 1, voice, "dissonant skip span", Arrays.asList(
                                new Violation.StepVoice(i - 1, voice),
                                new Violation.StepVoice(i,     voice))));
                    }
                    // (c) span must not exceed octave
                    if (Math.abs(notes[i] - notes[i-2]) > 12) {
                        result.add(new Violation(i + 1, voice, "skip span > 8ve", Arrays.asList(
                                new Violation.StepVoice(i - 1, voice),
                                new Violation.StepVoice(i,     voice))));
                    }
                }

                // (d) three or more consecutive same-direction skips (any size ≥ 3)
                if (i >= 3 && notes[i-3] > 0) {
                    int d0   = notes[i-2] - notes[i-3];
                    boolean allDir = (d0 > 0 && d1 > 0 && d2 > 0) || (d0 < 0 && d1 < 0 && d2 < 0);
                    if (allDir && Math.abs(d0) >= 3 && Math.abs(d1) >= 3 && Math.abs(d2) >= 3) {
                        result.add(new Violation(i + 1, voice, "3+ same-dir skips", Arrays.asList(
                                new Violation.StepVoice(i - 2, voice),
                                new Violation.StepVoice(i - 1, voice),
                                new Violation.StepVoice(i,     voice))));
                    }
                }
            }
        }
    }
}
