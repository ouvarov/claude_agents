# Task Quality Review

Launch the `task-quality-reviewer` agent to analyze Jira task: **$ARGUMENTS**

## What This Agent Does

1. **Fetches** the task from Jira
2. **Identifies** what's unclear or missing (terms, paths, formats, designs)
3. **Searches codebase** to find answers (not just criticize!)
4. **Extracts Figma specs** if design link exists
5. **Posts enrichment comment** to Jira with all findings

## Expected Output

A Jira comment with:
- All internal terms explained with code locations
- File paths for implementation
- Similar existing implementations as references
- Data format examples from actual code
- Design specs from Figma (or BLOCKER if missing)
- Completeness checklist

## Workflow Integration

```
/review-task PRMV-XXX  →  Enriches task with code references
                              ↓
/pre-refinement         →  Creates technical execution plan
                              ↓
Claude executes         →  Implements the task
```

## Instructions

Use `task-quality-reviewer` agent with cloudId: `ca314ded-0f85-4d46-b78d-a2f99a2a3394`

Task to review: **$ARGUMENTS**

**Remember:** Don't just criticize - FIND the missing information in code and Figma!