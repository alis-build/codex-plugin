---
name: adk-go-agent-workflows
description: Suggested ADK-Go agent workflow prompts for Alis Build.
---
# ADK-Go Agent Workflows

Use the Alis Build MCP with these workflow prompts when the user asks for the matching ADK-Go agent command.

## Add runtime agent skills

Use the Alis Build MCP and the adk-add-agent-skills skill to add embedded runtime skills to this ADK-Go agent. Bootstrap internal/skills, add the SKILL.md package I describe, wire skilltoolset into llmagent.Config.Toolsets, and verify the agent can load_skill.

## Add AG-UI

Use the Alis Build MCP and the adk-add-agui skill to enable AG-UI for this ADK-Go agent. Wire the AG-UI web sublauncher, update the runtime launcher args, keep the service id aligned with infra, and verify the SSE endpoint is available.

## Add long-running tools

Use the Alis Build MCP and the adk-add-lro skill to add a long-running ADK tool to this agent. Guide me through the proto changes, define step, LRO infra, resumable handler, weblro launcher wiring, and local verification.

## Add scheduler

Use the Alis Build MCP and the adk-add-scheduler skill to add the A2A scheduler extension to this ADK-Go agent. Wire internal/scheduler, Cloud Tasks and Spanner config, the scheduler interceptor, launcher args, and build verification.

## Add a synchronous tool

Use the Alis Build MCP and the adk-add-tool skill to add a synchronous proto-backed tool to this ADK-Go agent. Update tools.proto, wait for define and dependency installation, implement the handler, register MyTools, and run focused verification.
