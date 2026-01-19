#!/bin/bash
# Task Quality Reviewer
# Runs the task-quality-reviewer agent to review a Jira task
#
# Usage: ./review-task.sh PRMV-XXXXX

set -e

# Check argument
if [ -z "$1" ]; then
    echo "Usage: ./review-task.sh PRMV-XXXXX"
    echo "Example: ./review-task.sh PRMV-14443"
    exit 1
fi

TASK_KEY="$1"

# Environment
export HOME="/Users/uvarovalexandr"
export PATH="/Users/uvarovalexandr/.local/bin:$PATH"
# FIGMA_ACCESS_TOKEN should be set in your environment or ~/.bashrc
# export FIGMA_ACCESS_TOKEN="your-token-here"

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
LOG_FILE="$LOG_DIR/task-review-$(date '+%Y-%m-%d').log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "========================================="
log "Starting Task Quality Review: $TASK_KEY"
log "========================================="

# Check if claude is available
if ! command -v claude &> /dev/null; then
    log "ERROR: claude CLI not found. Please install Claude Code."
    exit 1
fi

cd "$PROJECT_DIR"

# Run Claude Code with the task-quality-reviewer agent
log "Launching task-quality-reviewer agent..."

claude -p \
    --dangerously-skip-permissions \
    --agent "task-quality-reviewer" \
    "Review Jira task $TASK_KEY for clarity and completeness.

cloudId: ca314ded-0f85-4d46-b78d-a2f99a2a3394

MANDATORY WORKFLOW (do ALL steps!):

STEP 1: Get task from Jira
mcp__atlassian__getJiraIssue(cloudId, issueIdOrKey)

STEP 2: Check Figma design (if link exists)
mcp__figma__get_design_context(fileKey, nodeId)

STEP 3: MANDATORY - Check existing code via GitHub API
Use gh api to search and read code from main branch:
gh api -X GET search/code -f q='keyword repo:AppSci/promova.com_monorepo'
gh api -X GET search/code -f q='keyword repo:Promova/gringotts-strapi-cms'
gh api repos/Promova/gringotts-strapi-cms/contents/src/components/fb-sales-sections --jq '.[].name'

STEP 4: Write NON-TECHNICAL review
No code paths, no technical jargon - write for Product/Marketing!

STEP 5: Post comment to Jira
mcp__atlassian__addCommentToJiraIssue(cloudId, issueIdOrKey, commentBody)

DO NOT skip step 3! Use GitHub API to check existing code.
DO NOT ask questions - work autonomously!" \
    2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -eq 0 ]; then
    log "Task review completed successfully"
else
    log "ERROR: Task review failed with exit code $EXIT_CODE"
fi

log "========================================="
log "Task Quality Review Finished: $TASK_KEY"
log "========================================="

exit $EXIT_CODE