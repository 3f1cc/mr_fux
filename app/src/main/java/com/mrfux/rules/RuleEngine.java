package com.mrfux.rules;

import com.mrfux.model.Violation;
import com.mrfux.rules.impl.DissonanceRule;
import com.mrfux.rules.impl.EndpointsRule;
import com.mrfux.rules.impl.ForbiddenIntervalRule;
import com.mrfux.rules.impl.HiddenParallelRule;
import com.mrfux.rules.impl.LargeLeapRule;
import com.mrfux.rules.impl.MinorSixthResolveRule;
import com.mrfux.rules.impl.NoInteriorUnisonRule;
import com.mrfux.rules.impl.NoParallelImperfectRule;
import com.mrfux.rules.impl.ParallelFifthsRule;
import com.mrfux.rules.impl.ParallelOctavesRule;
import com.mrfux.rules.impl.PostSkipStepRule;
import com.mrfux.rules.impl.RepeatedIntervalRule;
import com.mrfux.rules.impl.SeventhRunRule;
import com.mrfux.rules.impl.SimilarSkipRule;
import com.mrfux.rules.impl.SkipOrderRule;
import com.mrfux.rules.impl.StepToFinalRule;
import com.mrfux.rules.impl.TritoneOutlineRule;
import com.mrfux.rules.impl.WideSpacingRule;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Collects all Rule implementations and runs them against a note sequence.
 *
 * The arrays passed to {@link #check} are 0-indexed and of length MAX_LENGTH;
 * only indices 0..(length-1) are considered.
 */
public class RuleEngine {

    private final List<Rule> rules = Arrays.asList(
            new LargeLeapRule(),
            new ForbiddenIntervalRule(),
            new StepToFinalRule(),
            new TritoneOutlineRule(),
            new DissonanceRule(),
            new ParallelFifthsRule(),
            new ParallelOctavesRule(),
            new EndpointsRule(),
            new NoInteriorUnisonRule(),
            new WideSpacingRule(),
            new HiddenParallelRule(),
            new SimilarSkipRule(),
            new MinorSixthResolveRule(),
            new SkipOrderRule(),
            new RepeatedIntervalRule(),
            new PostSkipStepRule(),
            new SeventhRunRule(),
            new NoParallelImperfectRule()
    );

    /**
     * Run all rules and return a flat list of violations.
     *
     * @param cf     cantus firmus array (0-indexed, values are MIDI notes or 0)
     * @param cp     counterpoint array (0-indexed, values are MIDI notes or 0)
     * @param length number of active steps
     */
    public List<Violation> check(int[] cf, int[] cp, int length) {
        List<Violation> all = new ArrayList<>();
        for (Rule rule : rules) {
            all.addAll(rule.check(cf, cp, length));
        }
        return all;
    }

    public List<Rule> getRules() { return rules; }
}
