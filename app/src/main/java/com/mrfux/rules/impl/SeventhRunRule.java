package com.mrfux.rules.impl;

import com.mrfux.model.Violation;
import com.mrfux.rules.Rule;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Advisory: a monotonic run must not span ≥ 10 semitones (minor seventh or larger).
 */
public class SeventhRunRule implements Rule {

    @Override public String name() { return "seventh-run"; }
    @Override public String type() { return "melodic"; }

    @Override
    public List<Violation> check(int[] cf, int[] cp, int length) {
        List<Violation> result = new ArrayList<>();
        checkVoice(cf, 1, length, result);
        checkVoice(cp, 2, length, result);
        return result;
    }

    private void checkVoice(int[] notes, int voice, int length, List<Violation> result) {
        int runStart = 0;
        int runDir   = 0;
        for (int i = 1; i < length; i++) {
            if (notes[i] > 0 && notes[i-1] > 0) {
                int d   = notes[i] - notes[i-1];
                int dir = d > 0 ? 1 : (d < 0 ? -1 : 0);
                if (dir == 0 || dir != runDir) {
                    runStart = i - 1;
                    runDir   = dir;
                }
                if (runDir != 0) {
                    int span = Math.abs(notes[i] - notes[runStart]);
                    if (span >= 10) {
                        result.add(new Violation(i + 1, voice, "* 7th in run",
                                Collections.singletonList(new Violation.StepVoice(runStart + 1, voice))));
                        runStart = i; // reset to avoid re-flagging same run
                    }
                }
            } else {
                runStart = i;
                runDir   = 0;
            }
        }
    }
}
