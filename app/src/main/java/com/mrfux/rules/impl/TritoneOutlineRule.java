package com.mrfux.rules.impl;

import com.mrfux.model.Violation;
import com.mrfux.rules.Rule;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Three consecutive notes where the span from first to third (mod 12)
 * is a tritone (6), or a seventh (10 or 11).
 */
public class TritoneOutlineRule implements Rule {

    private static final Map<Integer, String> BAD = new HashMap<>();
    static {
        BAD.put(6,  "tritone outline");
        BAD.put(10, "7th outline");
        BAD.put(11, "7th outline");
    }

    @Override public String name() { return "tritone-outline"; }
    @Override public String type() { return "melodic"; }

    @Override
    public List<Violation> check(int[] cf, int[] cp, int length) {
        List<Violation> result = new ArrayList<>();
        checkVoice(cf, 1, length, result);
        checkVoice(cp, 2, length, result);
        return result;
    }

    private void checkVoice(int[] notes, int voice, int length, List<Violation> result) {
        for (int i = 2; i < length; i++) {
            if (notes[i] > 0 && notes[i-1] > 0 && notes[i-2] > 0) {
                int span = Math.abs(notes[i] - notes[i-2]) % 12;
                String name = BAD.get(span);
                if (name != null) {
                    result.add(new Violation(i + 1, voice, name, Arrays.asList(
                            new Violation.StepVoice(i - 1, voice),
                            new Violation.StepVoice(i,     voice))));
                }
            }
        }
    }
}
