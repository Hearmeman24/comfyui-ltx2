#!/bin/bash
# Hook: Append workflow instructions when dispatching to supervisors
# Triggers: PreToolCall for Task

# This hook adds context about the 9-step workflow to supervisor dispatches

SUBAGENT_TYPE="${CLAUDE_TOOL_PARAM_subagent_type:-}"

case "$SUBAGENT_TYPE" in
    *supervisor*)
        echo "9-STEP WORKFLOW REMINDER FOR SUPERVISORS:"
        echo "1. GET TASK     - Read from Kanban"
        echo "2. UPDATE STATUS - Mark as in_progress"
        echo "3. SCOUT        - Dispatch Ivy for context"
        echo "4. DESIGN       - Dispatch Ada if complex"
        echo "5. PLAN         - Create implementation steps"
        echo "6. DELEGATE     - Send to Worker (Bree)"
        echo "7. REVIEW       - Check worker's output"
        echo "8. VERIFY       - Run tests/checks"
        echo "9. COMPLETE     - Mark task done in Kanban"
        echo ""
        ;;
esac

exit 0
