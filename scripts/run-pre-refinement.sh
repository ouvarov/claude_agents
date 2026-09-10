#!/bin/bash
# Pre-Refinement Task Analyzer - Daily Scheduled Job
# Runs at 10:00 AM every day

# Set up environment
export PATH="/Users/uvarovalexandr/.local/bin:$PATH"

# Log file
LOG_DIR="/Users/uvarovalexandr/myProject/claude-agents/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/pre-refinement-$(date '+%Y-%m-%d').log"

# Start logging
echo "[$(date '+%Y-%m-%d %H:%M:%S')] =========================================" >> "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Daily Pre-Refinement Analysis" >> "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] =========================================" >> "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Launching pre-refinement-task-analyzer agent..." >> "$LOG_FILE"

# Change to project directory
cd /Users/uvarovalexandr/myProject/claude-agents

# Run the Claude agent with the pre-refinement task analyzer
/Users/uvarovalexandr/.local/bin/claude \
    -p \
    --dangerously-skip-permissions \
    --agent "pre-refinement-task-analyzer" \
    "Start pre-refinement analysis" \
    >> "$LOG_FILE" 2>&1

# Log completion
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Pre-refinement analysis completed successfully" >> "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] =========================================" >> "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Daily Pre-Refinement Analysis Finished" >> "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] =========================================" >> "$LOG_FILE"

exit 0