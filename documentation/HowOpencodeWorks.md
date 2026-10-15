# OpenCode V2 — This Dotfiles Setup

This guide explains both the OpenCode V2 component model and the configuration
tracked in this repository. It targets OpenCode V2, currently tested here with
OpenCode 2.0.30. The upstream V2 documentation linked at the end remains the
source of truth for version-sensitive behavior.

## 1. The Big Picture

OpenCode is an AI coding assistant that can read code, use tools, and modify files when permitted.

Each customization component has a different purpose:

| Component | Purpose | Think of it as… |
|---|---|---|
| Configuration (`opencode.jsonc`) | Set models, permissions, integrations, and defaults | Control panel |
| Instructions (`AGENTS.md`) | Rules that consistently guide the AI | Standing rules |
| Agents (`agents/*.md`) | Specialized AI roles with prompts and permissions | Team members |
| Skills (`skills/*/SKILL.md`) | Reusable instructions loaded when needed | Playbooks |
| Commands (`commands/*.md`) | Prompts you explicitly run using `/name` | Shortcuts |
| Tools | Capabilities to read, edit, run commands, etc. | Hands |
| Plugins (`plugins/`) | Extend or change OpenCode's behavior | Extensions |
| MCP servers | Connect external services and expose their tools | Integrations |
| Models/providers | Decide which AI powers a request | Engine |
| Permissions | Control whether actions are allowed, denied, or require approval | Safety gates |

**Most important distinction:**

- **Agent:** Who handles the task?
- **Skill:** How should the task be performed?
- **Command:** How do I trigger a repeatable request?
- **Tool:** What can the AI actually do?

---

## 2. Directory Structure

Global configuration applies across all projects. Project configuration applies only to a particular project.

### Tracked Global Configuration

The `opencode` GNU Stow package links the following files under
`~/.config/opencode/`:

```text
~/.config/opencode/
├── opencode.jsonc
├── AGENTS.md
├── agents/
│   ├── code-reviewer.md
│   ├── documentation.md
│   ├── teacher.md
│   └── update-tracker.md
├── skills/
│   ├── align-centers/
│   │   └── SKILL.md
│   └── personalized-learning/
│       └── SKILL.md
```

No global commands or plugins are currently tracked. The omitted directories
shown elsewhere in this guide are optional OpenCode features, not part of this
setup.

### Project Configuration

Project-specific components may live in a project's `.opencode/` directory.
Project configuration can use either `opencode.jsonc` or
`.opencode/opencode.jsonc`; normally use one form rather than both. Project
instructions belong in `AGENTS.md`. The tree below shows the available
locations, not a requirement to create every file.

```text
my-project/
├── AGENTS.md
├── opencode.jsonc
├── .opencode/
│   ├── opencode.jsonc
│   ├── agents/
│   ├── skills/
│   ├── commands/
│   └── plugins/
└── src/
```

**Global:** Available across projects.

**Project:** Specific to one repository.

Since you're using GNU Stow, manage these files inside your dotfiles repository and symlink them into the appropriate configuration directory.

You only need to create components you actually use.

---

## 3. Configuration — `opencode.jsonc`

The main configuration file controls how OpenCode operates.

You can configure:

- Default AI models
- Permissions and approval requirements
- MCP servers
- Plugins
- Custom commands
- Other application behavior

The tracked global file currently configures:

- `openai/gpt-5.6-sol` as the default model.
- The built-in `build` agent as the default primary agent.
- The remote Context7 MCP server.
- Explicit shell allows for commands beginning with `git status` and
  `git diff`.
- Disabled session sharing.
- Automatic OpenCode updates.
- Automatic context compaction.

An abbreviated equivalent is:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "model": "openai/gpt-5.6-sol",
  "default_agent": "build",
  "mcp": {
    "servers": {
      "context7": {
        "type": "remote",
        "url": "https://mcp.context7.com/mcp",
      },
    },
  },
  "share": "disabled",
  "update": "auto",
  "compaction": { "auto": true },
}
```

JSONC allows comments, unlike regular JSON.

**When to use it:** Whenever you want to change how OpenCode itself operates rather than how an AI responds to a particular task.

---

## 4. Instructions — `AGENTS.md`

`AGENTS.md` contains persistent instructions for OpenCode.

These instructions establish how the AI should behave regardless of the particular task.

Example:

```markdown
# Global Instructions

- Explain risky changes before making them.
- Prefer the smallest necessary modification.
- Inspect existing configuration before suggesting replacements.
- Preserve existing functionality.
- Report what was tested and what wasn't.
```

### Global vs. Project Instructions

**Global `AGENTS.md`:**
- General coding preferences
- System safety expectations
- Communication preferences

**Project `AGENTS.md`:**
- Project architecture
- Coding conventions
- Repository-specific instructions

**Important:** Keep these files concise because persistent instructions consume context.

Use skills for detailed procedures that are only needed occasionally.

---

## 5. Agents — `agents/`

Agents are specialized AI assistants designed for particular responsibilities.

An agent can have:

- Its own system instructions
- A particular AI model
- Tool restrictions
- Permission settings
- A specific role

### Types of Agents

**Primary Agents**

The main assistant you interact with.

Examples:
- General coding assistant
- Teacher
- Development assistant

**Subagents**

Specialized assistants that can be delegated individual tasks.

Examples:
- Code reviewer
- Debugger
- System inspector

### Example Agent

File: `agents/code-reviewer.md`

```markdown
---
description: Review code for correctness and regressions
mode: subagent
permissions:
  - action: edit
    resource: "*"
    effect: deny
  - action: shell
    resource: "*"
    effect: deny
---

Review code for bugs, security problems, and
potential regressions.

Report findings without modifying files.
```

### How to Use Agents

Ask OpenCode to delegate a task:

```text
Use the code-reviewer subagent to review my changes.
```

Primary agents can be selected directly in the OpenCode interface.

**When to create an agent:** When you need a specialized assistant with a distinct responsibility, behavior, or set of permissions.

### Agents In This Repository

| Agent | Mode | Purpose |
|---|---|---|
| `documentation` | Primary | Writes and maintains documentation; edits and shell commands require approval |
| `teacher` | Primary | Provides guided teaching and can load the personalized-learning skill |
| `code-reviewer` | Subagent | Reviews code without edit, shell, or subagent access |
| `update-tracker` | Subagent | Audits Linux updates and compatibility without intentional mutation |

All four tracked agents use the native V2 `permissions` list and action names.
The update tracker denies edits and asks before shell commands, matching its
read-only auditing role.

---

## 6. Skills — `skills/`

Skills are reusable sets of instructions that teach agents how to perform particular tasks.

Unlike agents, skills do not create separate AI assistants.

Instead, they provide procedures or specialized knowledge that an existing agent can load when needed.

### Example Skill

File: `skills/personalized-learning/SKILL.md`

```markdown
---
name: personalized-learning
description: Teach using active recall and guided problem solving.
---

# Personalized Learning

- Identify what the student already understands.
- Prefer hints before providing solutions.
- Encourage independent problem solving.
- Ask the student to explain their reasoning.
- Focus on understanding rather than memorization.
```

### How to Use Skills

You can request a skill:

```text
Use the personalized-learning skill to teach me recursion.
```

Agents may also discover and load relevant skills automatically.

### Important Characteristics

- Skills are reusable across different agents.
- Skills are loaded when needed instead of being permanently included in every prompt.
- Skills can contain supporting files and references.
- Skills should focus on one particular methodology or capability.

**When to create a skill:** When you have a reusable procedure that multiple agents or tasks could benefit from.

This repository currently provides `personalized-learning` for tutoring and
`align-centers` for optical UI alignment. The path determines each skill ID;
the frontmatter `name` is its display name.

Examples:
- Personalized learning
- Git workflows
- Docker best practices
- Testing strategies

---

## 7. Commands — `commands/`

Commands are reusable prompt templates that you explicitly trigger using slash commands.

They are useful for frequently repeated requests.

This repository does not currently define custom commands. The examples below
show how one could be added; they do not describe an installed `/explain`
command.

### Example Command

File: `commands/explain.md`

```markdown
---
description: Explain a concept step by step
---

Explain $ARGUMENTS clearly.

Include:
- A simple explanation
- One practical example
- Common mistakes
```

### How to Use Commands

Inside OpenCode:

```text
/explain recursion
```

OpenCode substitutes `recursion` for `$ARGUMENTS`.

### Command Arguments

- `$ARGUMENTS`: All provided arguments
- `$1`: First argument
- `$2`: Second argument

Commands may also specify a particular agent or model.

### Commands vs. Skills

**Commands:**
- Manually triggered using `/name`
- Useful for repeatable requests
- Primarily prompt shortcuts

**Skills:**
- Can be loaded automatically when relevant
- Contain reusable procedures
- Can be shared by multiple agents

**When to create a command:** When you repeatedly type the same kind of request and want a shortcut.

---

## 8. Tools

Tools give OpenCode the ability to perform actual operations.

Examples include:

- Reading files
- Searching through code
- Editing files
- Running terminal commands
- Executing tests
- Accessing external resources

### Example

You ask:

```text
Find the bug in my Python script and fix it.
```

OpenCode might:

1. Read the file.
2. Search related code.
3. Identify the problem.
4. Edit the file.
5. Run tests.

Each operation is performed through a tool.

### Custom Tools

You can also create custom tools when the built-in capabilities are insufficient.

For example, a custom tool could gather system information in a consistent format.

**When to create a custom tool:** When an agent needs a capability that requires executing code rather than simply following instructions.

---

## 9. Plugins — `plugins/`

Plugins extend OpenCode itself.

This repository does not currently install an OpenCode plugin.

Unlike skills and agents, plugins contain executable code, typically written in TypeScript or JavaScript.

They can integrate with OpenCode's extension APIs and respond to supported events.

### Example Uses

- Custom notifications
- Additional integrations
- Automated actions triggered by OpenCode events
- New functionality beyond standard prompts

### Plugins vs. Tools

**Tool:** Performs a particular operation.

**Plugin:** Extends OpenCode's behavior and may register tools or other functionality.

### When to Use Plugins

Only create a plugin when Markdown-based instructions or existing functionality cannot accomplish what you need.

Agents, skills, and commands are generally easier to maintain.

---

## 10. MCP Servers

MCP stands for **Model Context Protocol**.

It provides a standardized way for AI applications to connect to external systems and tools.

### Examples

An MCP server might expose:

- Database operations
- Documentation searches
- Browser automation
- External APIs
- Third-party services

### How It Works

```text
OpenCode
    |
    v
MCP Server
    |
    v
External Service
```

The MCP server makes capabilities available to OpenCode, and agents can use them according to their permissions.

### Useful Commands

```bash
opencode mcp list
opencode mcp --help
```

**When to use MCP:** When you want OpenCode to interact with external systems through an existing integration.

Before connecting an MCP server, review its trustworthiness, permissions, and data access.

The tracked global configuration connects the remote Context7 server at
`https://mcp.context7.com/mcp`. On 2026-10-15, `opencode mcp list` reported it
as connected. It is used to retrieve current library and framework
documentation. Remote MCP servers receive the queries sent to their tools, so
do not include credentials or proprietary content in those queries.

---

## 11. Models and Providers

A **provider** supplies access to AI models.

A **model** is the AI that performs reasoning and generates responses.

Examples of providers include companies offering hosted AI models and services exposing locally hosted models.

Different agents can be configured to use different models.

This setup selects `openai/gpt-5.6-sol` globally. None of the tracked custom
agents overrides that model, so they inherit the active session model. Provider
authentication is intentionally stored outside this repository.

### Useful Command

```bash
opencode models
```

### Why Use Different Models?

Some models may be better suited for:

- Complex reasoning
- Fast, simple tasks
- Code generation
- Large-context analysis
- Lower-cost operations

**When to configure models:** When you want to control performance, cost, or which AI handles particular tasks.

---

## 12. Permissions

Permissions determine what OpenCode can do without asking you.

The three general outcomes are:

| Permission | Meaning |
|---|---|
| `allow` | Execute automatically |
| `ask` | Request approval first |
| `deny` | Block the action |

Rules are ordered, and the last matching rule wins. OpenCode V2 also starts
agents with a base policy that generally allows tools while asking for external
directories and sensitive environment files. The two tracked `git status*` and
`git diff*` rules are narrow explicit allows; they are not a general shell
allowlist and do not make every unmatched command ask. The behavioral safety
rules in `AGENTS.md` guide the model, but only permission rules are enforced by
OpenCode itself.

### Why Permissions Matter

An agent's instructions alone do not guarantee safety.

For example, telling an agent not to modify files is not equivalent to denying its editing permissions.

For system-maintenance agents, consider requiring approval before:

- Installing packages
- Removing software
- Deleting files
- Changing system configuration
- Restarting services
- Performing other consequential changes

**When to configure permissions:** Whenever you want to control the actions an agent can perform.

---

## 13. How Everything Works Together

The tracked teaching workflow demonstrates how the components fit together:

**AGENTS.md**

Defines global engineering, Git, Linux, and educational expectations.

```text
For educational tasks, prioritize guided reasoning and understanding.
```

**Agent: `teacher.md`**

Provides a primary tutoring role and permission to load the learning skill.

**Skill: `personalized-learning/SKILL.md`**

Provides active-learning, retrieval-practice, and metacognitive guidance.

**Tools**

Provide reading, search, and other capabilities subject to the selected
agent's permissions.

**Permissions**

Prevent unintended modifications or require explicit approval.

### Example Workflow

```text
You select the teacher agent
 |
 | Loads relevant methodology
 v
Personalized Learning Skill
 |
 | Executes permitted operations
 v
Tools
 |
 | Produces results
 v
Agent summarizes findings
```

Each component handles a different responsibility.

This modular approach avoids creating one enormous instruction file that must handle everything.

---

## 14. Choosing the Right Component

| Goal | Component |
|---|---|
| Always follow certain rules | `AGENTS.md` |
| Create a specialized AI assistant | Agent |
| Define a reusable procedure | Skill |
| Create a shortcut for repeated requests | Command |
| Give an agent a new executable capability | Custom tool |
| Extend OpenCode's underlying behavior | Plugin |
| Connect to external services | MCP server |
| Change application defaults | Configuration |
| Change which AI handles tasks | Models/providers |
| Restrict what an agent can execute | Permissions |

### General Rule

Start with the simplest component that solves your problem.

1. Use `AGENTS.md` for universal rules.
2. Use agents for distinct roles.
3. Use skills for reusable knowledge and procedures.
4. Use commands for frequently repeated prompts.
5. Use tools, plugins, or MCP servers when actual additional functionality is required.

Avoid overengineering your configuration.

---

## 15. Basic Daily Workflow

1. Open your project directory.
2. Launch OpenCode:

```bash
opencode
```

3. Select an appropriate agent or use your default assistant.
4. Ask questions or request modifications.
5. Invoke skills when you want a particular methodology.
6. Use slash commands for repeatable tasks.
7. Delegate specialized work to subagents.
8. Review modifications and test results before accepting consequential changes.

The global `AGENTS.md` and upward-discovered project instructions can update in
a running V2 session. Nested instructions already loaded through exploration
may require a new session to guarantee that edited text applies. Commands are
also reloaded automatically. If broader configuration appears stale, first
start a new session; restart the shared service with
`opencode service restart` only as a troubleshooting step.

---

## 16. Official Documentation

- [OpenCode V2 Documentation](https://opencode.ai/v2/docs/)
- [Configuration](https://opencode.ai/v2/docs/config/)
- [Agents](https://opencode.ai/v2/docs/agents/)
- [Skills](https://opencode.ai/v2/docs/skills/)
- [Commands](https://opencode.ai/v2/docs/commands/)
- [Instructions](https://opencode.ai/v2/docs/instructions/)
- [Tools](https://opencode.ai/v2/docs/tools/)
- [Plugins](https://opencode.ai/v2/docs/build/plugins/)
- [MCP Servers](https://opencode.ai/v2/docs/mcp-servers/)
- [Permissions](https://opencode.ai/v2/docs/permissions/)

---

## Final Summary

Think of your OpenCode setup as a small organization:

- **Configuration:** The organization's settings.
- **AGENTS.md:** Rules everyone follows.
- **Agents:** Specialized employees.
- **Skills:** Training manuals.
- **Commands:** Requests you can launch instantly.
- **Tools:** Equipment employees use.
- **Plugins:** Extensions to the workplace.
- **MCP:** Connections to outside services.
- **Models:** The intelligence powering employees.
- **Permissions:** Access controls.

The goal is not to create as many components as possible. It is to give each component one clear responsibility so the entire configuration remains modular, understandable, and easy to maintain.
