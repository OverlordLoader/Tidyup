# Magic Pour review — 2026-09-30

## Defect and correction

The previous `magicPour()` replaced every segment of one mixed tube with four copies of its top color. That deletes other colors and creates new target-colored segments, breaking the per-color multiples of four necessary for a solved board. The button also debited inventory before engine success.

The new planner calls the actual legal pour/apply rules and requires a complete solution witness. It applies only the prefix through the first new completed tube. Every move preserves color counts and capacities; the remaining witness certifies solvability. It never uses a partial search. Maximum 2,000 expanded canonical states and depth 128; unchanged board result cached. Busy, won, malformed, unsolvable or budget-exhausted boards reject before authorization. A solvable board may be unavailable within the bound. Actual device latency/coverage still requires measurement; bounded does not mean measured fast.

Inventory debit is a synchronous authorization callback after planning and before board mutation, with no suspension between them. Failed authorization leaves board/moves/history unchanged. Undo restores the pre-booster board and move count and does not refund inventory. A newly earned ad reward is persisted first, then uses the same debit path, retaining the reward if it cannot run. Existing completion/win event behavior is reused; input is relocked after synchronous state restoration before completion animation.

## Evidence

- `git diff --check`: PASS (only existing Windows LF/CRLF conversion warning).
- Independent BFS reference oracle in `.ai/tmp/magic-pour/reference-check.py`: all 68 distinct mixed full-tube arrangements of two four-segment colors evaluated with one spare tube; 66 solvable, 2 unsolvable. Every successful prefix preserves per-color counts/capacity and has a solution suffix. Original overwrite corrupts counts for all 66 solvable fixtures. **This does not execute the Swift implementation.**
- `python scripts/test-magic-pour.py`: BLOCKED with exit 2 on Windows, explicitly requires macOS Swift/Combine. No native pass claimed.
- Native harness compiles actual `Models.swift`, `LevelGenerator.swift`, `GameEngine.swift`; isolated sound/haptics/progress stubs. Assertions cover malformed/solved/blocked/zero-budget boards, all 50 generated levels' returned solution witnesses, tutorial availability, exact first-completion prefix, no charge when busy, no mutation on failed debit, one debit per success and undo without inventory recreation. The Swift harness has not yet compiled or run.
- Existing unsigned simulator workflow now runs harness before app compilation/startup. No workflow dispatch or push occurred.

## Required next acceptance

1. Root review, then macOS `python3 scripts/test-magic-pour.py`; inspect bounded no-op coverage and timing for all 50 levels. A failure is a blocker; do not call the source fix accepted yet.
2. Compile full iOS target, boot simulator, use Magic Pour after ordinary moves, verify completion animation/input lock, undo/restart, and eventual win.
3. Device test latency, accessibility/disabled-state clarity, reward ad return when busy/unavailable, persistence after relaunch, consumable purchase/restore behavior as applicable. Existing inventory is local preferences, not a newly certified account-bound purchase ledger.
4. Other T8 games, saves/audio/haptics/ads/IAP and Emberfall restrictions remain unchanged. No store or launch readiness claim.

## File scope

`Models.swift`, `GameEngine.swift`, `GameView.swift`, `StoreManager.swift`, Swift harness and Python launcher, existing unsigned simulator workflow, VISION/CHANGELOG and `.ai` continuity. No other project edited. No package installs, paid requests, secrets, heavy builds, PR/default merges or publication.
