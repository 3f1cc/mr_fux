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
 * Vertical interval class at any step must not be dissonant.
 * Dissonant ICs: 1, 2, 5, 6, 10, 11.
 */
public class DissonanceRule implements Rule {

    private static final Set<Integer> DISSONANT =
            new HashSet<>(Arrays.asList(1, 2, 5, 6, 10, 11));

    @Override public String name() { return "dissonance"; }
    @Override public String type() { return "counterpoint"; }

    @Override
    public List<Violation> check(int[] cf, int[] cp, int length) {
        List<Violation> result = new ArrayList<>();
        for (int i = 0; i < length; i++) {
            if (cf[i] > 0 && cp[i] > 0) {
                int ic = Math.abs(cf[i] - cp[i]) % 12;
                if (DISSONANT.contains(ic)) {
                    result.add(new Violation(i + 1, 2, "dissonance",
                            Collections.singletonList(new Violation.StepVoice(i + 1, 1))));
                }
            }
        }
        return result;
    }
}
