#!/bin/bash

# Sync Component Patterns Script
# Fetches component schemas from gringotts-strapi-cms and generates a report

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_FILE="$PROJECT_DIR/docs/patterns-report.json"
PATTERNS_DOC="$PROJECT_DIR/docs/component-patterns.md"

echo "=== Component Patterns Sync ==="
echo "Date: $(date '+%Y-%m-%d %H:%M')"
echo ""

# Component categories to scan
CATEGORIES=(
  "fb-screens"
  "fb-sales-sections"
  "fb-thank-you-screens"
  "checkout-sections"
  "fb-upsells"
  "fb-loader-screens"
  "fb-start-screens"
)

# Initialize JSON output
echo "{" > "$OUTPUT_FILE"
echo '  "generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",' >> "$OUTPUT_FILE"
echo '  "source": "gringotts-strapi-cms (main)",' >> "$OUTPUT_FILE"
echo '  "categories": {' >> "$OUTPUT_FILE"

first_category=true

for category in "${CATEGORIES[@]}"; do
  echo "Scanning: $category"

  if [ "$first_category" = false ]; then
    echo "," >> "$OUTPUT_FILE"
  fi
  first_category=false

  echo "    \"$category\": {" >> "$OUTPUT_FILE"
  echo '      "components": [' >> "$OUTPUT_FILE"

  # Get list of files in category
  files=$(gh api "repos/Promova/gringotts-strapi-cms/contents/src/components/$category" --jq '.[].name' 2>/dev/null || echo "")

  if [ -z "$files" ]; then
    echo "  - Category not found or empty"
    echo '      ]' >> "$OUTPUT_FILE"
    echo '    }' >> "$OUTPUT_FILE"
    continue
  fi

  first_file=true

  for file in $files; do
    if [[ "$file" == *.json ]]; then
      component_name="${file%.json}"

      if [ "$first_file" = false ]; then
        echo "," >> "$OUTPUT_FILE"
      fi
      first_file=false

      # Fetch and parse schema
      schema=$(gh api "repos/Promova/gringotts-strapi-cms/contents/src/components/$category/$file" --jq '.content' 2>/dev/null | base64 -d 2>/dev/null || echo "{}")

      # Extract enum values if present
      enum_values=$(echo "$schema" | python3 -c "
import sys
import json
try:
    data = json.load(sys.stdin)
    attrs = data.get('attributes', {})
    enums = {}
    for key, val in attrs.items():
        if isinstance(val, dict) and val.get('type') == 'enumeration':
            enums[key] = val.get('enum', [])
    if enums:
        print(json.dumps(enums))
    else:
        print('null')
except:
    print('null')
" 2>/dev/null || echo "null")

      echo "        {" >> "$OUTPUT_FILE"
      echo "          \"name\": \"$component_name\"," >> "$OUTPUT_FILE"
      echo "          \"file\": \"$file\"," >> "$OUTPUT_FILE"
      echo "          \"enums\": $enum_values" >> "$OUTPUT_FILE"
      echo -n "        }" >> "$OUTPUT_FILE"

      echo "  - $component_name"

      # Show enum values if present
      if [ "$enum_values" != "null" ]; then
        enum_count=$(echo "$enum_values" | python3 -c "import sys,json; d=json.load(sys.stdin); print(sum(len(v) for v in d.values()))" 2>/dev/null || echo "0")
        echo "    (${enum_count} enum values)"
      fi
    fi
  done

  echo "" >> "$OUTPUT_FILE"
  echo '      ]' >> "$OUTPUT_FILE"
  echo -n '    }' >> "$OUTPUT_FILE"
done

echo "" >> "$OUTPUT_FILE"
echo '  }' >> "$OUTPUT_FILE"
echo "}" >> "$OUTPUT_FILE"

echo ""
echo "=== Summary ==="
echo "Report saved to: $OUTPUT_FILE"

# Count totals
total_components=$(cat "$OUTPUT_FILE" | python3 -c "
import sys
import json
data = json.load(sys.stdin)
total = 0
for cat in data.get('categories', {}).values():
    total += len(cat.get('components', []))
print(total)
" 2>/dev/null || echo "0")

total_enums=$(cat "$OUTPUT_FILE" | python3 -c "
import sys
import json
data = json.load(sys.stdin)
total = 0
for cat in data.get('categories', {}).values():
    for comp in cat.get('components', []):
        enums = comp.get('enums')
        if enums:
            for enum_list in enums.values():
                total += len(enum_list)
print(total)
" 2>/dev/null || echo "0")

echo "Total components: $total_components"
echo "Total enum values: $total_enums"
echo ""
echo "To update documentation, review $OUTPUT_FILE and update $PATTERNS_DOC"