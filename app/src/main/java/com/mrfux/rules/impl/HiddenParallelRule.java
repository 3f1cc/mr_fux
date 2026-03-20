package com.mrfux.rules.impl;

import com.mrfux.model.Violation;
import com.mrfux.rules.Rule;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Approaching a perfect consonance (IC 0 or 7) by similar motion is forbidden.
 */
public class HiddenParallelRule implements Rule {

    @Override public String name() { return "hidden-parallel"; }
    @Override public String type() { return "counterpoint"; }

    @Override
    public List<Violation> check(int[] cf, int[] cp, int length) {
        List<Violation> result = new ArrayList<>();
        for (int i = 1; i < length; i++) {
            if (cf[i] > 0 && cp[i] > 0 && cf[i-1] > 0 && cp[i-1] > 0) {
                int icCurr = Math.abs(cf[i] - cp[i]) % 12;
                if (icCurr == 0 || icCurr == 7) {
                    int cfD = cf[i] - cf[i-1];
                    int cpD = cp[i] - cp[i-1];
                    boolean similar = (cfD > 0 && cpD > 0) || (cfD < 0 && cpD < 0);
                    if (similar) {
                        String summary = icCurr == 0 ? "hidden 8ve" : "hidden 5th";
                        result.add(new Violation(i + 1, 2, summary, Arrays.asList(
                                new Violation.StepVoice(i,     1),
                                new Violation.StepVoice(i,     2),
                                new Violation.StepVoice(i + 1, 1))));
                    }
                }
            }
        }
        return result;
    }
}
