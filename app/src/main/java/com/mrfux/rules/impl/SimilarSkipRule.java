package com.mrfux.rules.impl;

import com.mrfux.model.Violation;
import com.mrfux.rules.Rule;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Both voices must not skip (≥ 3 semitones) in the same direction simultaneously.
 */
public class SimilarSkipRule implements Rule {

    @Override public String name() { return "similar-skip"; }
    @Override public String type() { return "counterpoint"; }

    @Override
    public List<Violation> check(int[] cf, int[] cp, int length) {
        List<Violation> result = new ArrayList<>();
        for (int i = 1; i < length; i++) {
            if (cf[i] > 0 && cp[i] > 0 && cf[i-1] > 0 && cp[i-1] > 0) {
                int cfD = cf[i] - cf[i-1];
                int cpD = cp[i] - cp[i-1];
                boolean sameDir = (cfD > 0 && cpD > 0) || (cfD < 0 && cpD < 0);
                boolean cfSkip  = Math.abs(cfD) >= 3;
                boolean cpSkip  = Math.abs(cpD) >= 3;
                if (sameDir && cfSkip && cpSkip) {
                    result.add(new Violation(i + 1, 2, "similar skip", Arrays.asList(
                            new Violation.StepVoice(i,     1),
                            new Violation.StepVoice(i,     2),
                            new Violation.StepVoice(i + 1, 1))));
                }
            }
        }
        return result;
    }
}
