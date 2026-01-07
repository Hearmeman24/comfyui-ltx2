#!/bin/bash
# Hook: Block orchestrator from using implementation tools directly
# Triggers: PreToolCall for Edit, Write, NotebookEdit
# Note: This hook provides warnings rather than hard blocks

TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
AGENT_NAME="${CLAUDE_AGENT_NAME:-}"

# If running as a subagent, allow all tools
if [[ -n "$AGENT_NAME" ]]; then
    exit 0
fi

# For orchestrator, warn about implementation tools
case "$TOOL_NAME" in
    Edit|Write|NotebookEdit)
        echo "WARNING: Orchestrator is using implementation tool: $TOOL_NAME"
        echo "Consider delegating to a supervisor agent instead."
        echo ""
        echo "Allowed uses:"
        echo "  - Creating/updating orchestration files"
        echo "  - Quick config changes"
        echo "  - User-requested direct edits"
        ;;
esac

exit 0
