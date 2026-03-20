package com.mrfux.rules.impl;

import com.mrfux.model.Violation;
import com.mrfux.rules.Rule;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Flag parallel octaves/unisons (IC=0 at both steps) unless contrary motion.
 */
public class ParallelOctavesRule implements Rule {

    @Override public String name() { return "parallel-octaves"; }
    @Override public String type() { return "counterpoint"; }

    @Override
    public List<Violation> check(int[] cf, int[] cp, int length) {
        List<Violation> result = new ArrayList<>();
        for (int i = 1; i < length; i++) {
            if (cf[i] > 0 && cp[i] > 0 && cf[i-1] > 0 && cp[i-1] > 0) {
                int icPrev = Math.abs(cf[i-1] - cp[i-1]) % 12;
                int icCurr = Math.abs(cf[i]   - cp[i]  ) % 12;
                if (icPrev == 0 && icCurr == 0) {
                    int cfD = cf[i] - cf[i-1];
                    int cpD = cp[i] - cp[i-1];
                    boolean contrary = (cfD > 0 && cpD < 0) || (cfD < 0 && cpD > 0);
                    if (!contrary) {
                        result.add(new Violation(i + 1, 2, "parallel 8ve", Arrays.asList(
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
