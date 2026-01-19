# Sync Component Patterns

Fetch fresh component schemas from gringotts-strapi-cms and update the patterns documentation.

## Your Task

1. **Fetch current components from GitHub main branch:**
   ```bash
   # List all component directories
   gh api repos/Promova/gringotts-strapi-cms/contents/src/components --jq '.[].name'
   ```

2. **For each relevant component category, fetch schema files:**
   - `fb-screens` - Onboarding screens
   - `fb-sales-sections` - Sales page sections
   - `fb-thank-you-screens` - Thank you page sections
   - `checkout-sections` - Checkout components
   - `fb-upsells` - Upsell components
   - `fb-loader-screens` - Loader screens
   - `fb-start-screens` - Start screens

3. **Extract enum values from each schema:**
   ```bash
   gh api repos/Promova/gringotts-strapi-cms/contents/src/components/[category]/[file].json --jq '.content' | base64 -d
   ```

4. **Compare with documented patterns in `docs/component-patterns.md`**

5. **Report findings:**

   **Format for new components:**
   ```markdown
   ## New Components Found

   ### fb-screens
   - `new-component.json` - [brief description based on schema]

   ### fb-sales-sections
   - `new-section.json` - [brief description]
   ```

   **Format for new enum values:**
   ```markdown
   ## New Enum Values Found

   ### amethyst-static-screen
   - `new-enum-value` (not in docs)

   ### static-section
   - `new-section-type` (not in docs)
   ```

6. **Update documentation:**
   - Add new components to appropriate sections in `docs/component-patterns.md`
   - Update the "Last updated" date
   - Add changelog entry

7. **Summary output:**
   ```markdown
   ## Sync Summary

   - Components scanned: X
   - New components found: Y
   - New enum values found: Z
   - Documentation updated: Yes/No

   ### Action Required
   - [List any components that need frontend implementation]
   - [List any patterns that need further documentation]
   ```

## Important Notes

- Always fetch from **main branch** of gringotts-strapi-cms
- Focus on components that affect agent analysis (screens, sections, etc.)
- Skip internal/utility components (shared, modules, etc.)
- Update the changelog with date and changes made