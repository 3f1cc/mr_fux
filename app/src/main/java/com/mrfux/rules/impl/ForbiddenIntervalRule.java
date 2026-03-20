package com.mrfux.rules.impl;

import com.mrfux.model.Violation;
import com.mrfux.rules.Rule;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Flag forbidden melodic intervals: tritone (6), maj 6th (9), min 7th (10), maj 7th (11). */
public class ForbiddenIntervalRule implements Rule {

    private static final Map<Integer, String> NAMES = new HashMap<>();
    static {
        NAMES.put(6,  "tritone leap");
        NAMES.put(9,  "maj 6th leap");
        NAMES.put(10, "min 7th leap");
        NAMES.put(11, "maj 7th leap");
    }

    @Override public String name() { return "forbidden-interval"; }
    @Override public String type() { return "melodic"; }

    @Override
    public List<Violation> check(int[] cf, int[] cp, int length) {
        List<Violation> result = new ArrayList<>();
        checkVoice(cf, 1, length, result);
        checkVoice(cp, 2, length, result);
        return result;
    }

    private void checkVoice(int[] notes, int voice, int length, List<Violation> result) {
        for (int i = 1; i < length; i++) {
            if (notes[i] > 0 && notes[i-1] > 0) {
                int iv = Math.abs(notes[i] - notes[i-1]);
                String name = NAMES.get(iv);
                if (name != null) {
                    result.add(new Violation(i + 1, voice, name,
                            Collections.singletonList(new Violation.StepVoice(i, voice))));
                }
            }
        }
    }
}
