package com.mrfux.rules.impl;

import com.mrfux.model.Violation;
import com.mrfux.rules.Rule;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * The same vertical interval class must not occur more than three times in a row.
 */
public class RepeatedIntervalRule implements Rule {

    @Override public String name() { return "repeated-interval"; }
    @Override public String type() { return "counterpoint"; }

    @Override
    public List<Violation> check(int[] cf, int[] cp, int length) {
        List<Violation> result = new ArrayList<>();
        int streak  = 0;
        int prevIc  = -1;
        for (int i = 0; i < length; i++) {
            if (cf[i] > 0 && cp[i] > 0) {
                int ic = Math.abs(cf[i] - cp[i]) % 12;
                if (ic == prevIc) {
                    streak++;
                } else {
                    streak = 1;
                    prevIc = ic;
                }
                if (streak > 3) {
                    result.add(new Violation(i + 1, 2, "interval 4+ in row",
                            Collections.singletonList(new Violation.StepVoice(i + 1, 1))));
                }
            } else {
                streak = 0;
                prevIc = -1;
            }
        }
        return result;
    }
}
