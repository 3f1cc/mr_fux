package com.mrfux.rules.impl;

import com.mrfux.model.Violation;
import com.mrfux.rules.Rule;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Advisory: after any skip (≥ 3 semitones), the next motion should be
 * a step (≤ 2 semitones) in the opposite direction.
 */
public class PostSkipStepRule implements Rule {

    @Override public String name() { return "post-skip-step"; }
    @Override public String type() { return "melodic"; }

    @Override
    public List<Violation> check(int[] cf, int[] cp, int length) {
        List<Violation> result = new ArrayList<>();
        checkVoice(cf, 1, length, result);
        checkVoice(cp, 2, length, result);
        return result;
    }

    private void checkVoice(int[] notes, int voice, int length, List<Violation> result) {
        for (int i = 1; i < length - 1; i++) {
            if (notes[i] > 0 && notes[i-1] > 0 && notes[i+1] > 0) {
                int d1 = notes[i]   - notes[i-1];
                int d2 = notes[i+1] - notes[i];
                if (Math.abs(d1) >= 3) {
                    boolean resolves = (d1 > 0 && d2 < 0 && Math.abs(d2) <= 2)
                                    || (d1 < 0 && d2 > 0 && Math.abs(d2) <= 2);
                    if (!resolves) {
                        result.add(new Violation(i + 2, voice, "* no step-back", Arrays.asList(
                                new Violation.StepVoice(i,     voice),
                                new Violation.StepVoice(i + 1, voice))));
                    }
                }
            }
        }
    }
}
