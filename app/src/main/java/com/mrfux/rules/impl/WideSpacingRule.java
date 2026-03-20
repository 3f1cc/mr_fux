package com.mrfux.rules.impl;

import com.mrfux.model.Violation;
import com.mrfux.rules.Rule;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/** Interval between voices must not exceed a major tenth (16 semitones). */
public class WideSpacingRule implements Rule {

    @Override public String name() { return "wide-spacing"; }
    @Override public String type() { return "counterpoint"; }

    @Override
    public List<Violation> check(int[] cf, int[] cp, int length) {
        List<Violation> result = new ArrayList<>();
        for (int i = 0; i < length; i++) {
            if (cf[i] > 0 && cp[i] > 0 && Math.abs(cf[i] - cp[i]) > 16) {
                result.add(new Violation(i + 1, 2, "spacing > 10th",
                        Collections.singletonList(new Violation.StepVoice(i + 1, 1))));
            }
        }
        return result;
    }
}
