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

import org.junit.Test;

import java.util.List;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

/**
 * Unit tests for all 18 counterpoint rules, derived from the Lua test suite.
 */
public class RulesTest {

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /** Build an int[] of length 24 from given values (rest = 0). */
    private static int[] seq(int... vals) {
        int[] arr = new int[24];
        System.arraycopy(vals, 0, arr, 0, vals.length);
        return arr;
    }

    private static int[] zeros() { return new int[24]; }

    private static List<Violation> filter(List<Violation> v, String summary) {
        return v.stream()
                .filter(x -> summary.equals(x.summary))
                .collect(java.util.stream.Collectors.toList());
    }

    // ---------------------------------------------------------------
    // large-leap
    // ---------------------------------------------------------------

    @Test public void largeLeap_octaveOk() {
        Rule rule = new LargeLeapRule();
        int[] cf = seq(60, 72); // exactly 12 — not > 12
        assertTrue(rule.check(cf, zeros(), 2).isEmpty());
    }

    @Test public void largeLeap_overOctaveFlagged() {
        Rule rule = new LargeLeapRule();
        int[] cf = seq(60, 73);
        List<Violation> v = rule.check(cf, zeros(), 2);
        assertEquals(1, v.size());
        assertEquals("leap > 8ve", v.get(0).summary);
        assertEquals(2, v.get(0).step);
        assertEquals(1, v.get(0).voice);
    }

    @Test public void largeLeap_cpFlagged() {
        Rule rule = new LargeLeapRule();
        int[] cp = seq(60, 74);
        List<Violation> v = rule.check(zeros(), cp, 2);
        assertEquals(1, v.size());
        assertEquals(2, v.get(0).voice);
    }

    // ---------------------------------------------------------------
    // forbidden-interval
    // ---------------------------------------------------------------

    @Test public void forbiddenInterval_tritone() {
        Rule rule = new ForbiddenIntervalRule();
        int[] cf = seq(60, 66);
        List<Violation> v = rule.check(cf, zeros(), 2);
        assertEquals(1, v.size());
        assertEquals("tritone leap", v.get(0).summary);
    }

    @Test public void forbiddenInterval_maj6th() {
        Rule rule = new ForbiddenIntervalRule();
        int[] cf = seq(60, 69);
        List<Violation> v = rule.check(cf, zeros(), 2);
        assertEquals(1, v.size());
        assertEquals("maj 6th leap", v.get(0).summary);
    }

    @Test public void forbiddenInterval_perfectFifthOk() {
        Rule rule = new ForbiddenIntervalRule();
        int[] cf = seq(60, 67);
        assertTrue(rule.check(cf, zeros(), 2).isEmpty());
    }

    // ---------------------------------------------------------------
    // step-to-final
    // ---------------------------------------------------------------

    @Test public void stepToFinal_stepOk() {
        Rule rule = new StepToFinalRule();
        int[] cf = seq(62, 60);
        assertTrue(rule.check(cf, zeros(), 2).isEmpty());
    }

    @Test public void stepToFinal_leapFlagged() {
        Rule rule = new StepToFinalRule();
        int[] cf = seq(65, 60);
        List<Violation> v = rule.check(cf, zeros(), 2);
        assertEquals(1, v.size());
        assertEquals("leap to final", v.get(0).summary);
        assertEquals(2, v.get(0).step);
    }

    // ---------------------------------------------------------------
    // tritone-outline
    // ---------------------------------------------------------------

    @Test public void tritoneOutline_flagged() {
        Rule rule = new TritoneOutlineRule();
        // F(65) A(69) B(71): 65→71 = 6 semitones mod 12 = 6
        int[] cf = seq(65, 69, 71);
        List<Violation> v = rule.check(cf, zeros(), 3);
        assertEquals(1, v.size());
        assertEquals("tritone outline", v.get(0).summary);
        assertEquals(3, v.get(0).step);
    }

    @Test public void tritoneOutline_seventhOutline() {
        Rule rule = new TritoneOutlineRule();
        // span of 10 semitones mod 12
        int[] cf = seq(60, 65, 70); // 70-60=10
        List<Violation> v = rule.check(cf, zeros(), 3);
        assertEquals(1, filter(v, "7th outline").size());
    }

    // ---------------------------------------------------------------
    // dissonance
    // ---------------------------------------------------------------

    @Test public void dissonance_tritone() {
        Rule rule = new DissonanceRule();
        int[] cf = seq(60);
        int[] cp = seq(66); // IC=6
        List<Violation> v = rule.check(cf, cp, 1);
        assertEquals(1, v.size());
        assertEquals("dissonance", v.get(0).summary);
    }

    @Test public void dissonance_perfectFifthOk() {
        Rule rule = new DissonanceRule();
        int[] cf = seq(60);
        int[] cp = seq(67); // IC=7
        assertTrue(rule.check(cf, cp, 1).isEmpty());
    }

    @Test public void dissonance_second() {
        Rule rule = new DissonanceRule();
        int[] cf = seq(60);
        int[] cp = seq(62); // IC=2
        assertEquals(1, rule.check(cf, cp, 1).size());
    }

    // ---------------------------------------------------------------
    // parallel-fifths
    // ---------------------------------------------------------------

    @Test public void parallelFifths_similarMotion() {
        Rule rule = new ParallelFifthsRule();
        // C4-G4 → D4-A4: both move up, both IC=7
        int[] cf = seq(60, 62);
        int[] cp = seq(67, 69);
        List<Violation> v = rule.check(cf, cp, 2);
        assertEquals(1, v.size());
        assertEquals("parallel 5th", v.get(0).summary);
    }

    @Test public void parallelFifths_contraryOk() {
        Rule rule = new ParallelFifthsRule();
        // C4-G4 → D4-G3 (contrary motion)
        int[] cf = seq(60, 62);
        int[] cp = seq(67, 55);
        assertTrue(rule.check(cf, cp, 2).isEmpty());
    }

    // ---------------------------------------------------------------
    // parallel-octaves
    // ---------------------------------------------------------------

    @Test public void parallelOctaves_flagged() {
        Rule rule = new ParallelOctavesRule();
        int[] cf = seq(60, 62);
        int[] cp = seq(72, 74); // IC=0 both steps, same direction
        List<Violation> v = rule.check(cf, cp, 2);
        assertEquals(1, v.size());
        assertEquals("parallel 8ve", v.get(0).summary);
    }

    @Test public void parallelOctaves_contraryOk() {
        Rule rule = new ParallelOctavesRule();
        int[] cf = seq(60, 62);
        int[] cp = seq(72, 62); // contrary
        assertTrue(rule.check(cf, cp, 2).isEmpty());
    }

    // ---------------------------------------------------------------
    // endpoints
    // ---------------------------------------------------------------

    @Test public void endpoints_unisonOk() {
        Rule rule = new EndpointsRule();
        int[] cf = seq(60, 60, 60, 60, 60, 60, 60, 60);
        int[] cp = seq(60, 0,  0,  0,  0,  0,  0,  60);
        assertTrue(rule.check(cf, cp, 8).isEmpty());
    }

    @Test public void endpoints_fifthCpAboveOk() {
        Rule rule = new EndpointsRule();
        int[] cf = seq(60, 0, 0, 0, 0, 0, 0, 60);
        int[] cp = seq(67, 0, 0, 0, 0, 0, 0, 67);
        assertTrue(rule.check(cf, cp, 8).isEmpty());
    }

    @Test public void endpoints_fifthCpBelowBad() {
        Rule rule = new EndpointsRule();
        int[] cf = seq(67, 0, 0, 0, 0, 0, 0, 67);
        int[] cp = seq(60, 0, 0, 0, 0, 0, 0, 60);
        // CF above CP: IC=7, CP below → violation
        List<Violation> v = rule.check(cf, cp, 8);
        assertEquals(2, v.size()); // both endpoints
        assertEquals("imperfect end", v.get(0).summary);
    }

    // ---------------------------------------------------------------
    // no-interior-unison
    // ---------------------------------------------------------------

    @Test public void noInteriorUnison_middleFlagged() {
        Rule rule = new NoInteriorUnisonRule();
        int[] cf = seq(60, 60, 60, 60, 60, 60, 60, 60);
        int[] cp = seq(67, 60, 60, 60, 60, 60, 60, 67);
        List<Violation> v = rule.check(cf, cp, 8);
        // Steps 2–7 (indices 1–6) should all be flagged
        assertEquals(6, v.size());
        assertEquals("interior unison", v.get(0).summary);
    }

    @Test public void noInteriorUnison_endpointsOk() {
        Rule rule = new NoInteriorUnisonRule();
        int[] cf = seq(60, 62, 60);
        int[] cp = seq(60, 67, 60);
        // Only step 2 (index 1) needs checking; CF=62, CP=67 → no unison
        assertTrue(rule.check(cf, cp, 3).isEmpty());
    }

    // ---------------------------------------------------------------
    // wide-spacing
    // ---------------------------------------------------------------

    @Test public void wideSpacing_17semitonesFlag() {
        Rule rule = new WideSpacingRule();
        int[] cf = seq(60);
        int[] cp = seq(77); // 17 semitones
        List<Violation> v = rule.check(cf, cp, 1);
        assertEquals(1, v.size());
        assertEquals("spacing > 10th", v.get(0).summary);
    }

    @Test public void wideSpacing_16semitonesOk() {
        Rule rule = new WideSpacingRule();
        int[] cf = seq(60);
        int[] cp = seq(76);
        assertTrue(rule.check(cf, cp, 1).isEmpty());
    }

    // ---------------------------------------------------------------
    // hidden-parallel
    // ---------------------------------------------------------------

    @Test public void hiddenParallel_similarToOctave() {
        Rule rule = new HiddenParallelRule();
        // Both rise to octave (IC=0) via similar motion
        int[] cf = seq(60, 62);
        int[] cp = seq(65, 74); // both rise, landing on IC=0
        List<Violation> v = rule.check(cf, cp, 2);
        assertEquals(1, v.size());
        assertEquals("hidden 8ve", v.get(0).summary);
    }

    @Test public void hiddenParallel_contraryToFifthOk() {
        Rule rule = new HiddenParallelRule();
        int[] cf = seq(60, 62);
        int[] cp = seq(72, 69); // CF rises, CP falls → contrary → no violation
        assertTrue(rule.check(cf, cp, 2).isEmpty());
    }

    // ---------------------------------------------------------------
    // similar-skip
    // ---------------------------------------------------------------

    @Test public void similarSkip_bothSkipSameDir() {
        Rule rule = new SimilarSkipRule();
        int[] cf = seq(60, 65);
        int[] cp = seq(67, 74);
        List<Violation> v = rule.check(cf, cp, 2);
        assertEquals(1, v.size());
        assertEquals("similar skip", v.get(0).summary);
    }

    @Test public void similarSkip_oneStepOk() {
        Rule rule = new SimilarSkipRule();
        int[] cf = seq(60, 62); // step, not skip
        int[] cp = seq(67, 74);
        assertTrue(rule.check(cf, cp, 2).isEmpty());
    }

    // ---------------------------------------------------------------
    // minor-sixth-resolve
    // ---------------------------------------------------------------

    @Test public void minorSixthResolve_unresolvedFlagged() {
        Rule rule = new MinorSixthResolveRule();
        // Ascending m6 (+8) then same or higher
        int[] cf = seq(60, 68, 69);
        List<Violation> v = rule.check(cf, zeros(), 3);
        assertEquals(1, v.size());
        assertEquals("min 6th unresolved", v.get(0).summary);
        assertEquals(3, v.get(0).step);
    }

    @Test public void minorSixthResolve_resolvedOk() {
        Rule rule = new MinorSixthResolveRule();
        int[] cf = seq(60, 68, 67); // rises m6 then falls
        assertTrue(rule.check(cf, zeros(), 3).isEmpty());
    }

    // ---------------------------------------------------------------
    // skip-order
    // ---------------------------------------------------------------

    @Test public void skipOrder_equalSkipsFlagged() {
        Rule rule = new SkipOrderRule();
        int[] cf = seq(60, 63, 66); // +3 then +3, both skips, same dir
        List<Violation> v = filter(rule.check(cf, zeros(), 3), "skip not smaller");
        assertEquals(1, v.size());
    }

    @Test public void skipOrder_smallerSecondOk() {
        Rule rule = new SkipOrderRule();
        int[] cf = seq(60, 64, 67); // +4 then +3
        List<Violation> v = filter(rule.check(cf, zeros(), 3), "skip not smaller");
        assertTrue(v.isEmpty());
    }

    @Test public void skipOrder_threeConsecutiveSkips() {
        Rule rule = new SkipOrderRule();
        int[] cf = seq(60, 63, 66, 69); // three +3 skips
        List<Violation> v = filter(rule.check(cf, zeros(), 4), "3+ same-dir skips");
        assertEquals(1, v.size());
        assertEquals(4, v.get(0).step);
    }

    // ---------------------------------------------------------------
    // repeated-interval
    // ---------------------------------------------------------------

    @Test public void repeatedInterval_fourInRowFlagged() {
        Rule rule = new RepeatedIntervalRule();
        // IC=7 (fifth) four times in a row
        int[] cf = seq(60, 60, 60, 60);
        int[] cp = seq(67, 67, 67, 67);
        List<Violation> v = rule.check(cf, cp, 4);
        assertEquals(1, v.size());
        assertEquals("interval 4+ in row", v.get(0).summary);
        assertEquals(4, v.get(0).step);
    }

    @Test public void repeatedInterval_threeInRowOk() {
        Rule rule = new RepeatedIntervalRule();
        int[] cf = seq(60, 60, 60);
        int[] cp = seq(67, 67, 67);
        assertTrue(rule.check(cf, cp, 3).isEmpty());
    }

    // ---------------------------------------------------------------
    // post-skip-step (advisory)
    // ---------------------------------------------------------------

    @Test public void postSkipStep_noStepBackFlagged() {
        Rule rule = new PostSkipStepRule();
        // Skip up (+5) then continue up (+2): no step-back
        int[] cf = seq(60, 65, 67);
        List<Violation> v = rule.check(cf, zeros(), 3);
        assertEquals(1, v.size());
        assertEquals("* no step-back", v.get(0).summary);
    }

    @Test public void postSkipStep_stepBackOk() {
        Rule rule = new PostSkipStepRule();
        // Skip up (+5) then step down (-2): resolves
        int[] cf = seq(60, 65, 63);
        assertTrue(rule.check(cf, zeros(), 3).isEmpty());
    }

    // ---------------------------------------------------------------
    // seventh-run (advisory)
    // ---------------------------------------------------------------

    @Test public void seventhRun_tenSemitoneRunFlagged() {
        Rule rule = new SeventhRunRule();
        // C4 D4 E4 F4 G4 A4: span from C4(60) to A4(69) = 9... need ≥10
        // C4 D4 E4 F4 G4 A4 B4: span 60→71=11
        int[] cf = seq(60, 62, 64, 65, 67, 69, 71);
        List<Violation> v = rule.check(cf, zeros(), 7);
        assertFalse(v.isEmpty());
        assertEquals("* 7th in run", v.get(0).summary);
    }

    @Test public void seventhRun_shortRunOk() {
        Rule rule = new SeventhRunRule();
        int[] cf = seq(60, 62, 64, 65, 67);
        assertTrue(rule.check(cf, zeros(), 5).isEmpty());
    }

    private static void assertFalse(boolean b) { assertTrue(!b); }

    // ---------------------------------------------------------------
    // no-parallel-imperfect (advisory)
    // ---------------------------------------------------------------

    @Test public void noParallelImperfect_allFifths() {
        Rule rule = new NoParallelImperfectRule();
        int[] cf = seq(60, 62, 64, 65, 67, 65, 64, 62);
        int[] cp = seq(67, 69, 71, 72, 74, 72, 71, 69);
        List<Violation> v = rule.check(cf, cp, 8);
        assertEquals(1, v.size());
        assertEquals("* no 3rds/6ths", v.get(0).summary);
    }

    @Test public void noParallelImperfect_hasThirds() {
        Rule rule = new NoParallelImperfectRule();
        // Include a pair of thirds (IC=3 or IC=4)
        int[] cf = seq(60, 62);
        int[] cp = seq(64, 66); // IC=4 (major third) at each step
        assertTrue(rule.check(cf, cp, 2).isEmpty());
    }
}
