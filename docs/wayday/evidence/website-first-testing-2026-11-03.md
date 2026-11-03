# Website-first official-app testing — 2026-11-03

The owner reported trying Wayday Test but explicitly had not tried the official APK. They requested using the actual website Download app button, so they can test website delivery too. This supersedes the prior D77 publication-order hold for the owner-approved development-preview profile. No specific Gemini/navigation/data-retention success is inferred from the general test-app report.

The selected 103401 candidates are the same permanent-signed binaries previously built from main 5992ced220e27c7dc8332e41815f98a43da6b291 and independently verified. The authorization pins run 41585787187, artifact 13208589928, its ZIP SHA-256, exact per-APK hashes, current contract/features, channel configuration fingerprints and certificate. The old physical qualification record remains unchanged. Preview metadata explicitly says qualified false and official-phone-pending; website copy must not call it physically qualified.

Red regressions reproduced rejection of explicitly authorized preview metadata; green checks validate acceptance only with explicit owner approval, exact profile/configuration/certificate and honest pending status. Selected-artifact tests reject mismatched provenance, failed source verification, changed ZIP bytes and unexpected archive paths. Browser checks verify the ordinary button, pending status and absence of qualification claims alongside existing qualified/incomplete states.

Delivery evidence is appended after the main-only selected-artifact action completes. No phone operation, paid provider request, credential/billing change or qualification attestation is part of this work.
