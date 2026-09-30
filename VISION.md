# tidyup


## September 30, 2026 - Independent source verification

Declared the app-scoped UserDefaults required-reason API (CA92.1), based on the app's actual preferences and local save calls. This does not certify App Store privacy answers or third-party SDK behavior. Final signed archive privacy reports and actual-device/network behavior remain release gates.
Imported Muse's regenerated icon catalog; verify actual supplied image count and pixel sizes rather than assuming nine PNG files.

Latest-main reconciliation: main now contains the approved icon set from merged PR2 (2d0385d). Preserved its exact master, generator and all nine opaque PNG catalog entries, instead of superseding approved artwork with the older Muse bundle. The downloaded bundle remains backed up locally. All nine sizes and pixel comparisons to the approved master pass. This merges main into the review branch only; no default/release branch was changed.
