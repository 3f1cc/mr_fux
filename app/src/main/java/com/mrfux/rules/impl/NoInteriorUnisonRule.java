package com.mrfux.rules.impl;

import com.mrfux.model.Violation;
import com.mrfux.rules.Rule;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Unisons (same MIDI note) are only permitted at the first and last step.
 */
public class NoInteriorUnisonRule implements Rule {

    @Override public String name() { return "no-interior-unison"; }
    @Override public String type() { return "counterpoint"; }

    @Override
    public List<Violation> check(int[] cf, int[] cp, int length) {
        List<Violation> result = new ArrayList<>();
        for (int i = 1; i < length - 1; i++) { // steps 2..(length-1), 0-indexed 1..(length-2)
            if (cf[i] > 0 && cp[i] > 0 && cf[i] == cp[i]) {
                result.add(new Violation(i + 1, 2, "interior unison",
                        Collections.singletonList(new Violation.StepVoice(i + 1, 1))));
            }
        }
        return result;
    }
}
