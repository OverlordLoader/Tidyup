# T8 Magic Pour repair — 2026-09-30

IN_SCOPE: Tidy Up Magic Pour rules, engine, booster consumption/reward handling, regression harness, review-only verification wiring and continuity documentation. Preserve artwork, gameplay, prices and existing changes. No default/release merge, store submission, paid activation or build dispatch. Heavy-build hold: local lightweight checks only until coordinator clears it.

Acceptance: every successful booster conserves every color and tube capacity, newly completes a tube and leaves a provably solvable board. Busy/won/unsolved-search/no-inventory failure is a no-op without spending inventory. Undo restores exactly the pre-booster board and move count; it does not refund/recreate a consumed booster. An earned ad reward remains available if it cannot be applied. Bounded search must never apply a partial unproved solution. Native Swift harness, simulator and device timing/gameplay remain required; reference-language tests do not certify Swift.
