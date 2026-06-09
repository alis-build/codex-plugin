---
name: build-it
description: Route build it and fix it requests to the right Alis Build skill through MCP skill discovery.
---
# Build It

Use this skill when the user says `build it`, `fix it`, or asks to build or fix something on the Alis Build Platform without naming a specific workflow.

## Protocol

1. Use the user's request, repository context, and any available Alis Build context to determine what needs to be built or fixed.
2. If the goal is still ambiguous, ask one concise question: "What exactly should Alis build?"
3. Once the goal is clear, call the Alis Build MCP `SearchSkills` tool with the clarified goal as the query. `SearchSkills` must be the first SkillTools discovery call.
4. Present the returned `queried_skills` in a concise table with number, skill id, description, and when to choose it.
5. Ask the user which skill to use before loading or executing any specialized workflow.
6. If `SearchSkills` returns no results, call `ListSkills` as the backup and present the available skills.
7. If no listed skill fits, ask whether the user wants to request a new skill. If they agree, call `RequestSkill` with `display_name`, `description`, `use_case`, and `notes`. The current implementation emails the Alis Build team for review.
8. After the user chooses a skill, load that skill and follow its instructions.

Do not trigger builds, defines, deploys, commits, or code edits from this router step.
