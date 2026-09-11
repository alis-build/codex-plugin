# CLI and Codex reliability regression guide

The synthetic cases in `cli-agent-regressions.json` preserve the failure patterns
found in the local session audit without copying private conversations. Run each
case in the same model, approval mode, plugin version, CLI version, and disposable
workspace before and after a release. Exercise permission decisions with stubs;
production cases must never use a live deployment as a test harness.

Record, per case:

| Measure | Definition |
| --- | --- |
| Completion | Requested outcome verified, or a real blocker accurately reported |
| CLI retries | Repeated invocation of the same intended operation; distinguish sandbox recovery from duplicate mutation |
| Browser detours | Browser use to obtain logs/status or cancel work that the CLI supports |
| Unnecessary interruptions | User questions where existing authorization and context were sufficient |
| Approval correctness | Explicit consent obtained for the exact production action, with no automatic assumption |
| Calls and time | Tool calls and elapsed time from request to verified outcome |

Keep the denominators: compare counts per attempted case and successful completion
separately. A lower retry count caused by abandonment is not an improvement. Repeat
the case suite at least three times and retain failures as well as successes. Do not
claim numerical improvement from a single local unit-test run.

Implementation regressions cover preserved retry arguments, multi-manifest exact
pins and per-location rollback, unknown active states, readable bounded logs,
runtime project/service scope, cancellation ownership and completion races, missing
plugin paths, and hook output under different permission modes. Plugin release
validation rejects more than three starter prompts and missing/non-executable hooks.

Runtime logs currently cover Cloud Run services in the environment's configured
region whose deployed image belongs to the selected neuron. Other runtimes, custom
external images, and other regions require a future explicit resource-discovery
contract. Build cancellation stops the image execution; it does not cancel a deploy
that already started. New RPCs require the matching CLI backend to be deployed.

The Cloud Run discovery and paginated logging implementation follows the official
[Cloud Run list API](https://docs.cloud.google.com/run/docs/reference/rest/v2/projects.locations.services/list)
and [Cloud Logging entries API](https://docs.cloud.google.com/logging/docs/reference/v2/rest/v2/entries/list).
