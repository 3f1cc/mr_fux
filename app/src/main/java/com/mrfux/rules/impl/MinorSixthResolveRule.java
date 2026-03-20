package com.mrfux.rules.impl;

import com.mrfux.model.Violation;
import com.mrfux.rules.Rule;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * An ascending minor sixth (+8 semitones) must be followed by downward motion.
 */
public class MinorSixthResolveRule implements Rule {

    @Override public String name() { return "minor-sixth-resolve"; }
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
                if (notes[i] - notes[i-1] == 8) { // ascending minor sixth
                    if (notes[i+1] >= notes[i]) { // did not resolve down
                        result.add(new Violation(i + 2, voice, "min 6th unresolved", Arrays.asList(
                                new Violation.StepVoice(i,     voice),
                                new Violation.StepVoice(i + 1, voice))));
                    }
                }
            }
        }
    }
}
