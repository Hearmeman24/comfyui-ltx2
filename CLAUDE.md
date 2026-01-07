# CLAUDE.md - comfyui-ltx2

## ORCHESTRATION MODE

**This project uses multi-agent orchestration.** The main agent (you) acts as an orchestrator, delegating work to specialized subagents.

### Orchestrator Rules

1. **DO NOT implement code directly** - Delegate to supervisors
2. **Always use the Task tool** to dispatch work to subagents
3. **Track all work in Kanban** (Project ID: `2c212ae1-ca5c-4402-9e2e-838fca47b67b`)
4. **Follow the routing table** to select the right agent

### Task Routing Table

| Task Type | Route To | Agent File |
|-----------|----------|------------|
| Docker, CI/CD, deployment | **Emilia** | `emilia-infra-supervisor` |
| RunPod, GPU, ComfyUI workflows | **Luna** | `luna-runpod-supervisor` |
| Investigation, debugging | **Vera** | `vera-detective` |
| Technical design, architecture | **Ada** | `ada-architect` |
| Reconnaissance, context | **Ivy** | `ivy-scout` |
| Documentation | **Penny** | `penny-scribe` |

### Workflow Overview

```
User Request
    │
    ▼
┌─────────────────┐
│  ORCHESTRATOR   │ ◄─── You (main agent)
│  (Route & Plan) │
└────────┬────────┘
         │
    Task Tool
         │
         ▼
┌─────────────────┐
│   SUPERVISOR    │ ◄─── Emilia or Luna
│ (Manage & Review)│
└────────┬────────┘
         │
    Task Tool
         │
    ┌────┴────┐
    ▼         ▼
┌───────┐ ┌───────┐
│ SCOUT │ │WORKER │ ◄─── Ivy, Bree
│ (Ivy) │ │(Bree) │
└───────┘ └───────┘
```

### Dispatching Syntax

```
Task(
  subagent_type: "emilia-infra-supervisor",
  prompt: "
    TASK: [Task title from Kanban]
    KANBAN_ID: [task UUID]

    CONTEXT:
    [Relevant background]

    REQUIREMENTS:
    - [Requirement 1]
    - [Requirement 2]

    DELIVERABLES:
    - [Expected output]
  "
)
```

### Exceptions (When Orchestrator Can Act Directly)

- Quick configuration changes requested by user
- Updating orchestration files (.claude/*)
- Emergency fixes with explicit user approval
- Pure research/exploration tasks

---

## Project Overview

**comfyui-ltx2** is a deployment template for ComfyUI with LTX-2 video generation models.

### Tech Stack

- **Docker**: Containerization
- **Docker Compose**: Local development
- **CircleCI**: CI/CD pipeline
- **ComfyUI**: AI workflow engine
- **LTX-2**: Video generation models
- **RunPod**: GPU cloud deployment
- **Shell scripts**: Automation

### Key Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Container build |
| `docker-compose.yml` | Local development |
| `start.sh` | Startup automation |
| `.circleci/config.yml` | CI/CD pipeline |
| `workflows/*.json` | ComfyUI workflows |

### Workflows

| Workflow | Type |
|----------|------|
| `LTX2_T2V.json` | Text-to-video |
| `LTX2_I2V.json` | Image-to-video |
| `LTX2_canny_to_video.json` | Edge-guided |
| `LTX2_depth_to_video.json` | Depth-guided |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `lightweight_fp8` | `false` | Use FP8 quantization |
| `civitai_token` | - | CivitAI API token |
| `LORAS_IDS_TO_DOWNLOAD` | - | Custom LoRA IDs |

---

## Team Roster

| Agent | Role | Model | Specialty |
|-------|------|-------|-----------|
| **Ivy** | Scout | haiku | Reconnaissance |
| **Vera** | Detective | opus | Debugging |
| **Ada** | Architect | opus | Design |
| **Emilia** | Infra Supervisor | opus | Docker, CI/CD |
| **Luna** | RunPod Supervisor | opus | GPU, ComfyUI |
| **Bree** | Worker | sonnet | Implementation |
| **Penny** | Scribe | haiku | Documentation |

---

## Quick Commands

```bash
# Build Docker image
docker build -t comfyui-ltx2 .

# Run locally
docker-compose up -d

# View logs
docker-compose logs -f

# Validate CircleCI config
circleci config validate

# Check shell scripts
shellcheck start.sh
```

---

## Kanban Integration

**Project ID:** `2c212ae1-ca5c-4402-9e2e-838fca47b67b`

```bash
# List tasks
mcp__vibe_kanban__list_tasks(project_id: "2c212ae1-ca5c-4402-9e2e-838fca47b67b")

# Get task details
mcp__vibe_kanban__get_task(task_id: "<UUID>")

# Update task status
mcp__vibe_kanban__update_task(task_id: "<UUID>", status: "done")
```
