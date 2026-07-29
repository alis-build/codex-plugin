---
name: build-it
description: Route build it and fix it requests to the right Alis Build skill through skill discovery.
---
# Build It

Use this skill when the user says `build it`, `fix it`, or asks to build or fix something on the Alis Build Platform without naming a specific workflow.

## Protocol

1. Use the user's request, visible errors, repository context, and any available Alis Build context to determine what needs to be built or fixed.
2. If the goal is still ambiguous, ask one concise question: "What exactly should Alis build?"
3. Once the goal is clear, run `alis skills search "<clarified goal>" --json`. The search must be the first discovery step.
4. Present the matching skills in a concise table with number, skill id, description, and when to choose it.
5. Ask the user which skill to use before loading or executing any specialized workflow.
6. Load the chosen skill with `alis skills load <id>` and follow its instructions — the loaded skill owns execution.
7. If the search returns nothing, say so and offer `alis skills request` (it proposes a new skill to the Alis Build team for review) — do not fall back to listing the whole catalogue.

Do not trigger builds, defines, deploys, commits, or code edits from this router step.
