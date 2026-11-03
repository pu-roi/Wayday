# Official planning update investigation and delivery

## Installed release and observed input

Read-only inspection identified the official package `dev.wayday.wayday`, version code 105502, updated on November 4 at 1:39 AM Manila time. Its installed APK SHA-256 was `e3abf5cfb08839346d42f5280e2106c074d1db3a327f574e6e6f0fdf42ff9a80`, matching the published public release manifest. That artifact's source was `252389fc314ddbbfc59333ccd895d09660d686ac`.

Review displayed November 4, Motorcycle, 6:30 AM departure and 8 PM final deadline. The campus event was at 8:30 AM and the pickup at 3 PM; lunch, bank and groceries were Anytime. All five had 15-minute visit estimates. From was the campus and To was the owner's private destination. Lunch and bank showed unapplied optional-priority suggestions; their current priority remained Required. Raw device captures and private destination details are excluded from maintained evidence.

The installed app displayed the generic scheduler conflict rather than the earlier appointment-hours precheck message. Its source lacked the locally verified D80/D82 and planned-hours changes. Its broad trip-window hours precheck could pass a 9 AM–5 PM campus listing against the 6:30 AM–8 PM trip, while its scheduler still required the 8:30 AM appointment and buffer to fit the campus listing. The known reported-hours mismatch therefore remained a hard rejection in the distributed code. The last retrieved hours were stale by inspection time, and no new provider request was made during that inspection.

Android again refused `run-as` because the official app is not debuggable. No sandbox bypass, direct database extraction, installation or reset was used for diagnosis. Six local user-selected-hours tests passed again on November 4; they did not establish success in release 105502.

## Scoped integration

The owner approved integrating and releasing the missing planning fixes and testing the same plan on the connected phone. An isolated branch starts from the exact current main source above. It transfers editor confirmations, source-bound manual Review persistence, planned-date/time candidate filtering and task-specific advisory hours for user-selected places. Existing sharing behavior from main is retained. Navigation startup work and unrelated workspace changes are excluded.

The saved Review and recommendation draft additions use existing JSON columns and accept legacy payloads. No schema/table migration or provider/model contract changes are needed. Automatic recommendations still enforce reported hours, complete visit durations and buffers. Shared-stop validation and presentation apply the policy per errand. Explicit choices invalidate older calculations.

## Verification and delivery status

The isolated source passed 110 focused Flutter tests, the full 754-test Flutter suite with one existing skip, clean static analysis, 58 release-tool tests and the actual public feature-profile fixture. Generation and road responses were simulated. The five-errand fixture now uses the observed 6:30 AM departure. Historical local test counts in the D80/D82 reports describe their original workspace runs.

Code review covered source/manual/model precedence, legacy JSON and SQLite reopening, failed-save behavior, per-task hours enforcement and stale calculation rejection. Main's existing sharing invalidation on a failed local acceptance was preserved; unrelated navigation and sharing-trial edits were excluded. No blocking finding remained before submitting the scoped PR. Existing required hosted checks remain mandatory before merge.

Reviewed merge, immutable coordinated release, website download identity and the in-place official phone check are pending at this source checkpoint and are recorded separately as they complete.

Physical success requires the actual unchanged five-errand plan to produce all five tasks, both appointments, confirmed visit times and road geometry. No navigation start, task completion or Finish operation is part of this verification. If the departure has elapsed, an explicit replacement date/time is required before another calculation.
