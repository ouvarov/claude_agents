#!/bin/bash
# Daily Pre-Refinement Task Analyzer
# Runs the pre-refinement-task-analyzer agent to analyze Jira tasks in Refinement status
# Uses MCP Atlassian for authentication (OAuth)
#
# Usage: ./daily-pre-refinement.sh

set -e

# Environment
export HOME="/Users/uvarovalexandr"
export PATH="/usr/local/bin:/Users/uvarovalexandr/.local/bin:$PATH"
# Secrets live outside the repo: a token in a tracked file is rejected by
# GitHub push protection, and rightly. Put FIGMA_ACCESS_TOKEN in
# claude-agents/.env.local (gitignored) and this picks it up.
FIGMA_ENV="/Users/uvarovalexandr/myProject/claude-agents/.env.local"
[ -f "$FIGMA_ENV" ] && . "$FIGMA_ENV"
: "${FIGMA_ACCESS_TOKEN:?FIGMA_ACCESS_TOKEN is not set — add it to $FIGMA_ENV}"

# Jira Configuration
CLOUD_ID="ca314ded-0f85-4d46-b78d-a2f99a2a3394"
SIGNATURE="Pre-Refinement Technical Review"

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
LOG_FILE="$LOG_DIR/pre-refinement-$(date '+%Y-%m-%d').log"
FILTER_OUTPUT="$LOG_DIR/filter-output.txt"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "========================================="
log "Starting Daily Pre-Refinement Analysis"
log "========================================="

# Check if claude is available
if ! command -v claude &> /dev/null; then
    log "ERROR: claude CLI not found. Please install Claude Code."
    exit 1
fi

cd "$PROJECT_DIR"

# Step 1: Use Claude to filter tasks (uses MCP Atlassian OAuth)
log "Filtering tasks via MCP Atlassian..."

claude -p \
    --dangerously-skip-permissions \
    --model sonnet \
    "TASK: Filter Jira tasks. Output ONLY task keys or status codes.

STEP 1: Search Jira using mcp__atlassian__searchJiraIssuesUsingJql
- cloudId: $CLOUD_ID
- jql: assignee = 'Alexandr Uvarov' AND status = 'Refinement'

STEP 2: For EACH task found, call mcp__atlassian__getJiraIssue to get comments.
Search for the EXACT signature text: '$SIGNATURE'
WARNING: 'Task Quality Review' is NOT the same as 'Pre-Refinement Technical Review' - they are DIFFERENT signatures!

STEP 3: Output results
- For each task that does NOT contain the EXACT text '$SIGNATURE': output just the task key (e.g. PRMV-12345)
- If ALL tasks contain the EXACT signature text: output only NO_TASKS_TO_ANALYZE
- If no tasks in Refinement: output only NO_TASKS_FOUND

CRITICAL: You must find the EXACT string '$SIGNATURE'. Similar text like 'Task Quality Review' or 'Technical Review' does NOT count.
Output NOTHING except task keys or status codes. No explanations." \
    2>/dev/null > "$FILTER_OUTPUT"

FILTER_RESULT=$(cat "$FILTER_OUTPUT" | grep -E "^(PRMV-[0-9]+|NO_TASKS)" | head -20)

log "Filter result: $FILTER_RESULT"

if [ -z "$FILTER_RESULT" ] || [ "$FILTER_RESULT" = "NO_TASKS_FOUND" ]; then
    log "No tasks found in Refinement status."
    log "========================================="
    log "Daily Pre-Refinement Analysis Finished"
    log "========================================="
    exit 0
fi

if [ "$FILTER_RESULT" = "NO_TASKS_TO_ANALYZE" ]; then
    log "All tasks already have pre-refinement analysis. Nothing to do."
    log "========================================="
    log "Daily Pre-Refinement Analysis Finished"
    log "========================================="
    exit 0
fi

# Convert newlines to space-separated list
TASKS_TO_ANALYZE=$(echo "$FILTER_RESULT" | tr '\n' ' ' | xargs)

log "Tasks to analyze: $TASKS_TO_ANALYZE"
log "Launching pre-refinement-task-analyzer agent..."

# Step 2: Run full analysis on filtered tasks
claude -p \
    --dangerously-skip-permissions \
    --agent "pre-refinement-task-analyzer" \
    "Analyze the following Jira tasks for pre-refinement: $TASKS_TO_ANALYZE

IMPORTANT: These tasks have been pre-filtered and verified to NOT have existing analysis. Analyze ALL of them.

REPOSITORIES TO USE:
- promova.com_monorepo: https://github.com/AppSci/promova.com_monorepo.git
- gringotts-strapi-cms: https://github.com/Promova/gringotts-strapi-cms.git

JIRA CONFIG:
- cloudId: $CLOUD_ID

FOR EACH TASK:
1. Get task details from Jira (use getJiraIssue)
2. Extract and analyze Figma designs using MCP tools
3. Use GitHub API (gh api) to analyze relevant code - DO NOT clone repos!
4. Post comprehensive technical analysis as Jira comment
5. End comment with signature: '$SIGNATURE - Pre-Refinement Technical Review'

DO NOT ask questions - work autonomously" \
    2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -eq 0 ]; then
    log "Pre-refinement analysis completed successfully"
else
    log "ERROR: Pre-refinement analysis failed with exit code $EXIT_CODE"
fi

log "========================================="
log "Daily Pre-Refinement Analysis Finished"
log "========================================="

exit $EXIT_CODE