---
name: discover
description: >-
  Find and load the right Alis Build skill for platform work. Alis Build is the
  Define-Build-Deploy (DBD) platform: protobuf contracts in the define repo, Go
  services (neurons) in product build repos, deploys to Cloud Run via
  Terraform. Use this skill FIRST — before writing code or running commands —
  whenever the task touches the Alis platform: creating or changing a product,
  neuron, block, or landing zone; editing .proto contracts and running Define;
  building or deploying a service; Spanner schemas or protobundles; Pub/Sub
  topics; Terraform under infra/; generated packages failing to resolve;
  playground tests; migrating legacy proto imports. Trigger on "alis", "hey
  alis", "ask alis to"; on "how do I ... on/in Alis" or any Alis Build platform
  question; on deploy, release, ship, protobuf, proto, Define, neuron, product,
  block, landing zone, Spanner, protobundle, Pub/Sub, Terraform, infra,
  playground, packages, DBD; and on build/fix/add/create requests inside an
  alis.build workspace when no Alis skill is loaded yet. Not for generic coding
  unrelated to the platform, and not when a loaded Alis skill already covers
  the task. It searches the Alis skills registry (thousands of curated skills),
  presents the top matches, and loads the chosen one, which then owns
  execution.
---

# Discover — find and load the right Alis Build skill

You are routing, not executing. Find the best registry skill for the task, load it, and
hand execution over to it.

## Flow

1. **Infer the intended outcome** from the current request and workspace context (current
   directory, visible errors, recent conversation). Ask at most ONE concise clarifying
   question, and only if the goal is genuinely ambiguous — otherwise proceed.

2. **Search the registry**:

   `alis skills search "<intended outcome>" --limit 8`

   Add `--json` when parsing the results programmatically. The search IS the discovery
   mechanism — never list or page through the whole catalogue.

3. **Present the matches**: for each, give the id, what it does, and when to choose it.
   Recommend one and say why.

4. **Load the chosen skill and follow it**:

   `alis skills load <id>`

   From this point the loaded skill owns execution — follow its workflow, not your own
   plan.

## Rules

- For platform-shaped work: do not inspect or edit code, run Define / Build / Deploy, or
  make commits before a skill is loaded. Route first.
- If nothing fits, say so and offer to file it:
  `alis skills request --name "..." --description "..."`. Then plant the capture seed in
  one sentence: "If we end up solving this by hand in this session, say 'capture this as
  a skill' afterwards and I'll save it for your team."
- If `alis skills search` fails or the `alis` CLI is absent, say so plainly and continue
  helping without a skill — never block on discovery.
