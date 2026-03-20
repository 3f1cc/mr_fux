package com.mrfux.rules;

import com.mrfux.model.Violation;

import java.util.List;

/**
 * Interface for a single counterpoint rule.
 *
 * Arrays are 0-indexed internally (cf[0] = step 1). The {@code length}
 * parameter indicates how many steps are active (1..length).
 */
public interface Rule {
    String name();
    String type(); // "melodic" or "counterpoint"
    List<Violation> check(int[] cf, int[] cp, int length);
}
