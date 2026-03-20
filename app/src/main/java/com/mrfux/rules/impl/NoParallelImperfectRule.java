package com.mrfux.rules.impl;

import com.mrfux.model.Violation;
import com.mrfux.rules.Rule;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * Advisory: the exercise must contain at least one consecutive pair of
 * imperfect consonances (parallel thirds or sixths; IC ∈ {3,4,8,9}).
 */
public class NoParallelImperfectRule implements Rule {

    private static final Set<Integer> IMPERFECT =
            new HashSet<>(Arrays.asList(3, 4, 8, 9));

    @Override public String name() { return "no-parallel-imperfect"; }
    @Override public String type() { return "counterpoint"; }

    @Override
    public List<Violation> check(int[] cf, int[] cp, int length) {
        int prevIc = -1;
        for (int i = 0; i < length; i++) {
            if (cf[i] > 0 && cp[i] > 0) {
                int ic = Math.abs(cf[i] - cp[i]) % 12;
                if (IMPERFECT.contains(ic) && prevIc >= 0 && IMPERFECT.contains(prevIc)) {
                    return new ArrayList<>(); // found a pair — no violation
                }
                prevIc = ic;
            } else {
                prevIc = -1;
            }
        }
        if (cf[length - 1] > 0 && cp[length - 1] > 0) {
            return Collections.singletonList(new Violation(length, 2, "* no 3rds/6ths",
                    new ArrayList<>()));
        }
        return new ArrayList<>();
    }
}
