# tidyup

## September 30, 2026 - Magic Pour conservation repair (review only)

Magic Pour must help complete a tube without inventing or deleting liquid. Replaced the destructive tube overwrite with a bounded search for a full legal solution, applying only the prefix through the first newly completed tube. The unused suffix proves the remaining board remains solvable. Search stops at 2,000 expanded states / 128 moves, caches the unchanged board, and declines safely without charging when no solution is found within those limits. Some solvable boards can therefore have Magic Pour unavailable; no promise of universal solver coverage is made.

Owned boosters are debited only after a valid result exists. Earned ad rewards are banked before application so a busy/unavailable board does not discard the reward. Undo restores the exact prior board and move count, but does not refund a spent consumable. Existing art, prices and ordinary pour rules remain unchanged.

Verification: independent reference oracle covered 66 solvable two-color mixed boards and two unsolvable boards; the old overwrite breaks color counts on all 66 solvable fixtures. This is mathematical/reference evidence, not Swift execution. Added a macOS Swift harness compiling the actual rules, generator and engine; wired it before the existing unsigned simulator smoke test. Windows cannot execute the Swift/Combine harness. Native compilation, all-50-level availability/timing, simulator gameplay, earned-ad callbacks and physical-device/StoreKit acceptance remain OPEN. No workflow dispatched, code published or store submission performed by this repair.


## September 30, 2026 - Independent source verification

Declared the app-scoped UserDefaults required-reason API (CA92.1), based on the app's actual preferences and local save calls. This does not certify App Store privacy answers or third-party SDK behavior. Final signed archive privacy reports and actual-device/network behavior remain release gates.
Imported Muse's regenerated icon catalog; verify actual supplied image count and pixel sizes rather than assuming nine PNG files.

Latest-main reconciliation: main now contains the approved icon set from merged PR2 (2d0385d). Preserved its exact master, generator and all nine opaque PNG catalog entries, instead of superseding approved artwork with the older Muse bundle. The downloaded bundle remains backed up locally. All nine sizes and pixel comparisons to the approved master pass. This merges main into the review branch only; no default/release branch was changed.

## October 2, 2026 - Review PR #1 merged

- 2026-10-02: PR #1 "Fix Magic Pour conservation and guard native release verification" merged to main - Magic Pour conservation repair and native release verification guard. Merge commit 3b426b8a5e6192bc763a50c10e60d6a9ec87eb5c.