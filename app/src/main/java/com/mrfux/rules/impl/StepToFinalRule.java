package com.mrfux.rules.impl;

import com.mrfux.model.Violation;
import com.mrfux.rules.Rule;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/** The final note of each voice must be approached by step (≤ 2 semitones). */
public class StepToFinalRule implements Rule {

    @Override public String name() { return "step-to-final"; }
    @Override public String type() { return "melodic"; }

    @Override
    public List<Violation> check(int[] cf, int[] cp, int length) {
        List<Violation> result = new ArrayList<>();
        int i = length - 1; // 0-indexed last step
        if (cf[i] > 0 && cf[i-1] > 0 && Math.abs(cf[i] - cf[i-1]) > 2) {
            result.add(new Violation(length, 1, "leap to final",
                    Collections.singletonList(new Violation.StepVoice(length - 1, 1))));
        }
        if (cp[i] > 0 && cp[i-1] > 0 && Math.abs(cp[i] - cp[i-1]) > 2) {
            result.add(new Violation(length, 2, "leap to final",
                    Collections.singletonList(new Violation.StepVoice(length - 1, 2))));
        }
        return result;
    }
}
