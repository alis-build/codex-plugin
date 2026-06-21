# Alis Build — Define, Build, Deploy (DBD)

The core workflow on the Alis Build platform is **Define, Build, Deploy (DBD)**. Most
development flows touch one or more of these steps — use this framing when helping with any
Alis Build task, and walk the user through DBD rather than handing over a disconnected checklist.

> **How this fits with the tools.** This primer is the shared mental model — *what*
> DBD is and *where* things live on disk. The precise rules for *calling* the Alis
> Build tools (which arguments to pass, what never to do) live in the tools
> themselves — their MCP server instructions and each tool's description. When a
> tool instruction is more specific than this primer, follow the tool instruction.

## Define — lock the API / platform contract

- Edit protobuf files in the landing zone `define` repo: `~/alis.build/<organisation-id>/define`.
- Commit and push, then run Define against a specific, reviewed commit — the
  contract pins to that exact commit, so it has to be deliberate (the tools enforce
  how the commit is supplied).
- Define pins the definition to that commit and generates consumable language packages
  (Go, JavaScript, Python, Dart, .NET, public ECMAScript when configured) and may sync platform
  artifacts such as Spanner protobundles or Pub/Sub topics.
- This is the source-of-truth step: it makes the contract reviewable, repeatable, and consumable.

## Build — implement the service and produce a deployable artifact

- Work in the product build repo: `~/alis.build/<organisation-id>/build/<product-id>`.
- Install/update the generated packages from Define, then write or edit the business logic
  (usually Go).
- Build a container image from a product repo commit. Docker build paths are relative to the
  neuron folder (e.g. a top-level Dockerfile uses `.`, not `demo/v1`); derive paths from the
  filesystem when you have repo access.
- This connects the locked contract to real behavior.

## Deploy — provision and update the runtime

- Review the neuron's Terraform under its `infra/` folder.
- Deploy the successful build version to a real environment (e.g. DEV). The
  environment comes from the product context, not a guess (the tools resolve it).
- Deploy makes the service reachable infrastructure (commonly Cloud Run plus supporting resources).
- Validate end-to-end via the generated playground, usually `<neuron>/.playground/main_test.go`.

## Getting deeper

For onboarding or the full step-by-step Simple API quickstart, load the `getting-started` skill
via LoadSkill. For an ambiguous "build it" / "fix it" request, route through skill discovery
(SearchSkills) before executing any DBD step.
