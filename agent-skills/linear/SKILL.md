---
name: linear
description: Manage issues, projects & team workflows in Linear. Use when the user wants to read, create or update tickets in Linear.
metadata:
  short-description: Manage Linear issues
---

# Linear

## Overview

This skill provides a structured workflow for managing issues, projects & team workflows in Linear via the official Linear MCP server. It supports any AI coding agent that can connect to MCP servers.

**MCP Server URL:** `https://mcp.linear.app/mcp` (Streamable HTTP, recommended)
**Fallback URL:** `https://mcp.linear.app/sse` (SSE transport)

Both endpoints use OAuth 2.1 with dynamic client registration.

## Prerequisites
- Linear MCP server must be connected and authenticated
- Access to the relevant Linear workspace, teams, and projects

## Setup

### Step 0: Connect Linear MCP (if not already configured)

If any MCP call fails because Linear MCP is not connected, pause and help the user set it up using the instructions below.

#### Claude Code (CLI)
```sh
claude mcp add --transport http linear-server https://mcp.linear.app/mcp
```
Then run `/mcp` in a Claude Code session to authenticate via OAuth.

#### Claude Desktop
- **Team & Enterprise (claude.ai):** Settings → Integrations → Add more → Name: "Linear", URL: `https://mcp.linear.app/mcp`
- **Free & Pro:** Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "linear": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.linear.app/mcp"]
    }
  }
}
```

#### Codex CLI
```sh
codex mcp add linear --url https://mcp.linear.app/mcp
```
Enable remote MCP: set `[features] rmcp_client = true` in `config.toml` or run `codex --enable rmcp_client`. Then authenticate with `codex mcp login linear`.

#### Cursor
Use the direct installation link from Cursor's MCP tools page, or search for "Linear".

#### VS Code
Command palette (Ctrl/Cmd+P) → "MCP: Add Server" → Command (stdio) → enter: `npx mcp-remote https://mcp.linear.app/mcp`

#### Windsurf
Settings (Ctrl/Cmd+,) → Cascade → MCP servers → Add custom server:
```json
{
  "mcpServers": {
    "linear": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.linear.app/mcp"]
    }
  }
}
```

#### Zed
Cmd+, and add to settings:
```json
{
  "context_servers": {
    "linear": {
      "source": "custom",
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.linear.app/mcp"],
      "env": {}
    }
  }
}
```

#### Other Agents
Use these universal settings:
- **Command:** `npx`
- **Arguments:** `-y mcp-remote https://mcp.linear.app/mcp`

**Windows/WSL note:** If you see connection errors on Windows, use SSE transport instead:
```json
{
  "mcpServers": {
    "linear": {
      "command": "wsl",
      "args": ["npx", "-y", "mcp-remote", "https://mcp.linear.app/sse", "--transport", "sse-only"]
    }
  }
}
```

After setup, the user may need to restart their agent/editor for the MCP server to become available.

## Required Workflow

**Follow these steps in order. Do not skip steps.**

### Step 1: Clarify Goal
Clarify the user's goal and scope (e.g., issue triage, sprint planning, documentation audit, workload balance). Confirm team/project, priority, labels, cycle, and due dates as needed.

### Step 2: Plan
Select the appropriate workflow (see Practical Workflows below) and identify the Linear MCP tools you will need. Confirm required identifiers (issue ID, project ID, team key) before calling tools.

### Step 3: Execute
Execute Linear MCP tool calls in logical batches:
- Read first (list/get/search) to build context.
- Create or update next (issues, projects, labels, comments) with all required fields.
- For bulk operations, explain the grouping logic before applying changes.

### Step 4: Summarize
Summarize results, call out remaining gaps or blockers, and propose next actions (additional issues, label changes, assignments, or follow-up comments).

## Available Tools (22)

### Issues
| Tool | Description | Key Parameters |
|------|-------------|----------------|
| `list_issues` | List issues in workspace | `query`, `teamId`, `stateId`, `assigneeId`, `projectId`, `limit` |
| `get_issue` | Get issue details by ID (includes attachments) | `id` |
| `create_issue` | Create a new issue | `title`, `teamId`, `description`, `priority`, `projectId`, `assigneeId`, `labelIds`, `dueDate` |
| `update_issue` | Update an existing issue | `id`, `title`, `description`, `priority`, `stateId`, `assigneeId`, `estimate` |
| `list_my_issues` | List issues assigned to current user | `limit`, `orderBy` |
| `list_issue_statuses` | List statuses for a team | `teamId` |
| `get_issue_status` | Get a status by name or ID | `query`, `teamId` |
| `list_issue_labels` | List labels for a team | `teamId` |
| `get_issue_git_branch_name` | Get git branch name for an issue | `id` |

### Projects
| Tool | Description | Key Parameters |
|------|-------------|----------------|
| `list_projects` | List projects in workspace | `teamId`, `limit`, `includeArchived` |
| `get_project` | Get project details | `query` |
| `create_project` | Create a new project | `name`, `teamId`, `summary`, `description`, `startDate`, `targetDate` |
| `update_project` | Update a project | `id`, `name`, `summary`, `description`, `startDate`, `targetDate` |

### Teams & Users
| Tool | Description | Key Parameters |
|------|-------------|----------------|
| `list_teams` | List teams in workspace | `limit`, `query`, `includeArchived` |
| `get_team` | Get team details | `query` |
| `list_users` | List workspace users | — |
| `get_user` | Get user details | `query` |

### Documents & Comments
| Tool | Description | Key Parameters |
|------|-------------|----------------|
| `list_documents` | List workspace documents | `projectId`, `query`, `limit` |
| `get_document` | Get document by ID or slug | `id` |
| `search_documentation` | Search Linear's documentation | `query`, `page` |
| `list_comments` | List comments on an issue | `issueId` |
| `create_comment` | Add a comment to an issue | `issueId`, `body` |

## Practical Workflows

- **Sprint Planning:** Review open issues for a target team, pick top items by priority, and create a new cycle with assignments.
- **Bug Triage:** List critical/high-priority bugs, rank by user impact, and move top items to "In Progress."
- **Documentation Audit:** Search documentation, then open labeled "documentation" issues for gaps or outdated sections.
- **Team Workload Balance:** Group active issues by assignee, flag anyone with high load, and suggest redistributions.
- **Release Planning:** Create a project with milestones (feature freeze, beta, docs, launch) and generate issues with estimates.
- **Cross-Project Dependencies:** Find all "blocked" issues, identify blockers, and create linked issues if missing.
- **Status Updates:** Find issues with stale updates and add status comments based on current state/blockers.
- **Smart Labeling:** Analyze unlabeled issues, suggest/apply labels, and create missing label categories.
- **Sprint Retrospectives:** Generate a report for the last completed cycle, note completed vs. pushed work, and open discussion issues.

## Tips

- Batch operations for related changes; use templates for recurring issue structures.
- Use natural queries when possible ("Show me what John is working on this week").
- Leverage context: reference prior issues in new requests.
- Break large updates into smaller batches to avoid rate limits.

## Troubleshooting

- **Connection errors:** Clear cached auth with `rm -rf ~/.mcp-auth`, then retry. Update Node.js if needed.
- **Authentication:** Clear browser cookies, re-run OAuth, verify workspace permissions, ensure API access is enabled.
- **Missing data:** Refresh token, verify workspace access, check for archived projects, confirm correct team selection.
- **Rate limits:** Batch bulk operations, use specific filters, and cache frequent queries.
