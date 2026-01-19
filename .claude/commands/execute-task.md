# Execute Task After Pre-Refinement

<!-- Usage: /execute-task PRMV-14733 -->

Execute Jira task: **$ARGUMENTS**

## Workflow

### Step 1: Fetch Task Details from Jira

1. Use `mcp__atlassian__getJiraIssue` with cloudId `ca314ded-0f85-4d46-b78d-a2f99a2a3394` to get the task
2. Read the task description and ALL comments to find the pre-refinement analysis from Claude
3. The pre-refinement comment contains:
   - Implementation plan with steps
   - File paths to modify
   - Technical details and context
   - Figma links (if any)

### Step 2: Extract and Process Information

From the pre-refinement comment, identify:
- **Which repositories are needed** (one or BOTH: promova.com_monorepo and/or gringotts-strapi-cms)
- Implementation steps for each repository
- Files to create/modify in each repo
- Figma design links
- Order of implementation (usually CMS first, then frontend)

### Step 3: Check Figma Designs (if present)

If Figma links exist in task or comments:
1. Use `mcp__figma__get_file` or `mcp__figma__get_file_nodes` to fetch design specs
2. Extract: colors, spacing, typography, component structure
3. Keep these specs handy during implementation

### Step 4: Prepare Git Branches

Analyze the pre-refinement plan to determine which repositories are needed.
**Create branches in ALL required repositories** - often tasks need changes in both!

**Common scenarios:**
- **Frontend only** → promova.com_monorepo
- **CMS only** → gringotts-strapi-cms
- **Full-stack** → BOTH repositories (e.g., new content type + frontend display)

**For promova.com_monorepo:**
```bash
cd /Users/uvarovalexandr/myProject/promova.com_monorepo
git fetch origin
git checkout main
git pull origin main
git checkout -b {TASK_KEY}-{short-description}
```

**For gringotts-strapi-cms:**
```bash
cd /Users/uvarovalexandr/myProject/gringotts-strapi-cms
git fetch origin
git checkout main
git pull origin main
git checkout -b {TASK_KEY}-{short-description}
```

**Use the SAME branch name** in both repos for easy tracking!

Branch naming convention:
- Use task key (e.g., PRMV-1234)
- Add 2-4 word kebab-case description from task summary
- Example: `PRMV-1234-add-pricing-section`

### Step 5: Read Repository Guidelines (CLAUDE.md)

**BEFORE implementing**, read the CLAUDE.md file in each repository you'll work with:

**For promova.com_monorepo:**
```
/Users/uvarovalexandr/myProject/promova.com_monorepo/CLAUDE.md
```

**For gringotts-strapi-cms:**
```
/Users/uvarovalexandr/myProject/gringotts-strapi-cms/CLAUDE.md
```

These files contain:
- Project-specific coding patterns and conventions
- Styling rules (CSS naming, imports, variables)
- Architecture guidelines
- Common utilities and hooks to use
- What NOT to do (anti-patterns)

**Follow these guidelines strictly during implementation!**

### Step 6: Execute Implementation

Follow the implementation plan from pre-refinement comment step by step.

**If working in BOTH repositories:**
1. **Start with CMS (gringotts-strapi-cms)** - create content types, fields, API endpoints
2. **Then frontend (promova.com_monorepo)** - consume the CMS data, build UI

**For each repository:**
1. Read existing files mentioned in the plan
2. Implement changes according to the plan
3. **Follow CLAUDE.md guidelines** for patterns, naming, styling
4. Match Figma designs exactly (colors, spacing, typography)
5. Run linting/type checks: `npm run lint`, `npm run type-check`
6. Test the changes if applicable

### Step 7: Summary

After completing:
1. List all files created/modified **per repository**
2. Summarize what was implemented
3. Note any deviations from the plan
4. **List PRs to create** (one per repo if both were modified)

## Repository Paths

- **Promova monorepo**: `/Users/uvarovalexandr/myProject/promova.com_monorepo`
- **Gringotts CMS**: `/Users/uvarovalexandr/myProject/gringotts-strapi-cms`

## Styling Guidelines (Quick Reference)

> **Note:** Full styling guidelines are in each repository's CLAUDE.md. This is a quick reference.

When working with styles in promova.com_monorepo:

### Global Styles Location
- **Path**: `/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/ui/styles`
- ALWAYS check this folder for existing variables, mixins, and shared styles
- Import and use variables from there instead of hardcoding values

### CSS Rules
1. **Only use `.module.scss` files** - never plain `.css` or `.scss` without module
2. **Class naming convention: snake_case with `_`** - NOT camelCase
   - ✅ Correct: `section_wrapper`, `title_block`, `cta_button`
   - ❌ Wrong: `sectionWrapper`, `titleBlock`, `ctaButton`
3. **Import global variables** at the top of your module file:
   ```scss
   @import '@promova/ui/styles/variables';
   @import '@promova/ui/styles/mixins';
   ```
4. Use existing color, spacing, and typography variables - don't hardcode values

## Important Notes

- ALWAYS read existing code before modifying
- Follow existing code patterns in the repository
- Match Figma designs precisely for UI tasks
- Create minimal, focused changes
- Don't over-engineer or add unnecessary abstractions

## Atlassian CloudId

Use cloudId: `ca314ded-0f85-4d46-b78d-a2f99a2a3394` for all Jira operations.