package com.mrfux.rules.impl;

import com.mrfux.model.Violation;
import com.mrfux.rules.Rule;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * First and last steps must be perfect consonances.
 * IC 0 or 7 when CP is above CF; IC 0 only when CP is below CF.
 */
public class EndpointsRule implements Rule {

    @Override public String name() { return "endpoints"; }
    @Override public String type() { return "counterpoint"; }

    @Override
    public List<Violation> check(int[] cf, int[] cp, int length) {
        List<Violation> result = new ArrayList<>();
        for (int idx : new int[]{0, length - 1}) {
            int step = idx + 1; // 1-indexed
            if (cf[idx] > 0 && cp[idx] > 0) {
                int ic      = Math.abs(cf[idx] - cp[idx]) % 12;
                boolean cpBelow = cp[idx] < cf[idx];
                boolean ok  = (ic == 0) || (ic == 7 && !cpBelow);
                if (!ok) {
                    result.add(new Violation(step, 2, "imperfect end",
                            Collections.singletonList(new Violation.StepVoice(step, 1))));
                }
            }
        }
        return result;
    }
}
