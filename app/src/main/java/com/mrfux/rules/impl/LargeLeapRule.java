package com.mrfux.rules.impl;

import com.mrfux.model.Violation;
import com.mrfux.rules.Rule;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/** Flag any melodic leap larger than an octave (> 12 semitones). */
public class LargeLeapRule implements Rule {

    @Override public String name() { return "large-leap"; }
    @Override public String type() { return "melodic"; }

    @Override
    public List<Violation> check(int[] cf, int[] cp, int length) {
        List<Violation> result = new ArrayList<>();
        for (int i = 1; i < length; i++) {
            if (cf[i] > 0 && cf[i-1] > 0 && Math.abs(cf[i] - cf[i-1]) > 12) {
                result.add(new Violation(i + 1, 1, "leap > 8ve",
                        Collections.singletonList(new Violation.StepVoice(i, 1))));
            }
            if (cp[i] > 0 && cp[i-1] > 0 && Math.abs(cp[i] - cp[i-1]) > 12) {
                result.add(new Violation(i + 1, 2, "leap > 8ve",
                        Collections.singletonList(new Violation.StepVoice(i, 2))));
            }
        }
        return result;
    }
}
