# Vision QA Rules

## The Eyeball+Ruler Pattern

Visual QA has two layers: the eyeball (does it look right?) and the ruler (do the numbers match?). The eyeball alone is unreliable — humans rationalize, compress diffs, and call "close enough" a pass. The ruler catches what the eye misses: a 14px gap rendered at 16px, a color at 95% opacity passing as full, a mobile layout that visually looks fine but measures 12px off.

This rule was battle-tested across 28 Shopify components in ai-shopify-plan. Every row below maps to a real failure mode caught during that process.

**Rule:** Never pass a visual comparison without measured computed values. Always run both layers.

---

## Anti-Rationalization Table

| You might think... | Why it's wrong | Do this instead |
|---|---|---|
| You might think: "It looks right, I don't need to measure it" | The eyeball compresses small diffs. A 2px spacing error looks identical at a glance but breaks design precision. This is rubber-stamping. | Capture computed values for every focus area. Compare numbers, not impressions. |
| You might think: "It's close enough — only a few pixels off" | 'Close enough' is not a pass criterion. Diffs compound across components and breakpoints. What looks minor in isolation is a systemic error at scale. | Record the exact delta. If it exceeds tolerance, mark it as a diff and apply a fix. |
| You might think: "I don't need to check computed values, the layout looks correct" | Visual rendering can hide computed mismatches. A box can look the right size while its padding, margin, or gap values are wrong. | Always read `getComputedStyle` or inspector data for every property in the spec. |
| You might think: "I can trust my visual comparison — the screenshot looks identical" | Screenshots compress color depth, hide sub-pixel differences, and can't surface invisible spacing. Visual-only comparison misses real fidelity issues. | Pair every visual pass with a numeric comparison of at least font-size, color, and spacing values. |
| You might think: "Mobile breakpoint looks fine, I'll skip the measurement" | Mobile layouts diverge from desktop in non-obvious ways. Font scaling, padding resets, and gap collapses are common and invisible without measurement. | Run measurements at every breakpoint defined in the spec. Never mark mobile as pass based on desktop data. |
| You might think: "The diff is only 0.5px — I'll round it away" | Rounding hides real errors. A 0.5px diff on a 1px border is a 50% deviation. Sub-pixel diffs matter for retina screens and design handoff accuracy. | Log the exact computed value. Let the tolerance threshold decide pass/fail — never round manually. |
| You might think: "I've verified visually, I'll mark this as pass" | A pass without evidence is not a pass. Future comparisons have no baseline and no audit trail. | Every pass must include: computed values captured, delta calculated, breakpoints covered, and result written to vision-spec.json. |
| You might think: "The reference image is old, I'll just trust the build" | A stale reference means no comparison baseline. Without a known-good ref, you are not doing QA — you are doing wishful thinking. | Flag the stale reference. Request an updated ref from design or regenerate from the last known-good build before proceeding. |
