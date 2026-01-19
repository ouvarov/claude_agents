# Promova Component Patterns

> **Auto-generated:** This document is automatically updated by the `sync-patterns` command.
> **Last updated:** 2025-12-29
> **Source:** gringotts-strapi-cms (main branch)

## Overview

This document maps UI patterns to existing Strapi components. Before creating new components, always check if an existing pattern matches your design.

**Priority:** REUSE > EXTEND > CREATE

---

## 1. FB Screens (Onboarding/Funnel)

Location: `src/components/fb-screens/`

### 1.1 Single Choice Screens

**Use when:** User needs to select ONE option from 2-4 choices

| Component | Strapi Schema | Visual Pattern | When to Use |
|-----------|---------------|----------------|-------------|
| `single-choice` | `fb-screens.single-choice` | Title + question + answer buttons | Dynamic content, configurable answers |
| `single-choice-card` | `fb-screens.single-choice-card` | Cards with icons/images | Richer visual answers |
| `single-select` | `fb-screens.single-select` | Dropdown/select style | Many options (5+) |

**Amethyst Static Single Choice variants:**
```
amethyst-single-choice-1 through amethyst-single-choice-6
amethyst-extra-single-choice-1 through amethyst-extra-single-choice-6
```

**Key attributes:**
- `question` - Title component
- `description` - Subtitle text
- `answers` - Array of quiz answers
- `questionKey` - Analytics key
- `designConcept` - concept_1/concept_2, layout_1/layout_2

### 1.2 Multiple Choice Screens

**Use when:** User can select MULTIPLE options

| Component | Strapi Schema | Visual Pattern |
|-----------|---------------|----------------|
| `multiple-choice` | `fb-screens.multiple-choice` | Checkboxes/toggles |
| `multiple-choice-grid` | `fb-screens.multiple-choice-grid` | Grid layout |

**Amethyst Static Multiple Choice variants:**
```
amethyst-multiple-choice-1 through amethyst-multiple-choice-3
```

### 1.3 Static/Info Screens

**Use when:** Display information without user input

| Component | Strapi Schema | Enum Values |
|-----------|---------------|-------------|
| `amethyst-static-screen` | `fb-screens.amethyst-static-screen` | See below |
| `quantum-static-screen` | `fb-screens.quantum-static-screen` | See below |

**Amethyst Static Screen variants:**
```
amethyst-divider-1 through amethyst-divider-7
amethyst-words-picker-1 through amethyst-words-picker-3
```

**Quantum Static Screen variants:**
```
quantum-aspects-to-improve
quantum-current-level
quantum-goal
quantum-reach-level
quantum-source
quantum-style
quantum-time-to-achieve
quantum-time-to-learn
```

### 1.4 Specialized Screens

| Component | Strapi Schema | Use Case |
|-----------|---------------|----------|
| `input` | `fb-screens.input` | Text input (name, email) |
| `range` | `fb-screens.range` | Slider/range selection |
| `time-range` | `fb-screens.time-range` | Time selection |
| `words-picker` | `fb-screens.words-picker` | Word/tag selection |
| `target-language` | `fb-screens.target-language` | Language picker |
| `native-language` | `fb-screens.native-language` | Native language picker |
| `english-level-test` | `fb-screens.english-level-test` | Level assessment |
| `profile-summary-screen` | `fb-screens.profile-summary-screen` | User profile summary |
| `split-screen` | `fb-screens.split-screen` | Two-column layout |

### 1.5 Dividers/Transitions

| Component | Strapi Schema | Use Case |
|-----------|---------------|----------|
| `divider` | `fb-screens.divider` | Simple visual break |
| `divider-v2` | `fb-screens.divider-v2` | Enhanced divider |
| `promocode-divider` | `fb-screens.promocode-divider` | Divider with promocode |

---

## 2. FB Sales Sections (Sales Page)

Location: `src/components/fb-sales-sections/`

### 2.1 Static Sections (Enum-based)

**Use when:** Standard sales page blocks with fixed layout

| Component | Strapi Schema | Enum Values |
|-----------|---------------|-------------|
| `static-section` | `fb-sales-sections.static-section` | social-proof, comparison, hero-human, hero-app-screen, money-back, social-proof-v2 |
| `elysium-static-section` | `fb-sales-sections.elysium-static-section` | elysium-timer, elysium-before-after, elysium-plans, elysium-plan-highlights, elysium-mention, elysium-faq, elysium-reviews, elysium-guarantee, elysium-research |
| `quantum-static-section` | `fb-sales-sections.quantum-static-section` | quantum-timer, quantum-hero, quantum-summary, quantum-plans, quantum-advantages, quantum-mention, quantum-faq, quantum-reviews, quantum-guarantee |

### 2.2 Configurable Sections

| Component | Strapi Schema | Use Case |
|-----------|---------------|----------|
| `plans` | `fb-sales-sections.plans` | Subscription plans display |
| `reviews` | `fb-sales-sections.reviews` | User reviews/testimonials |
| `faq-section` | `fb-sales-sections.faq-section` | FAQ accordion |
| `money-back` | `fb-sales-sections.money-back` | Money-back guarantee |
| `what-you-get` | `fb-sales-sections.what-you-get` | Feature list |
| `personalized-plan` | `fb-sales-sections.personalized-plan` | Personalized recommendation |
| `test-result` | `fb-sales-sections.test-result` | Test/quiz results |
| `graph-section` | `fb-sales-sections.graph-section` | Progress/stats graph |
| `before-after-section` | `fb-sales-sections.before-after-section` | Before/after comparison |
| `communication-section` | `fb-sales-sections.communication-section` | Communication features |
| `recommendation-section` | `fb-sales-sections.recommendation-section` | AI recommendations |
| `user-feedback` | `fb-sales-sections.user-feedback` | User feedback display |
| `awards-section` | `fb-sales-sections.awards-section` | Awards/badges |

### 2.3 Offer Sections

| Component | Strapi Schema | Use Case |
|-----------|---------------|----------|
| `intro-offer` | `fb-sales-sections.intro-offer` | Introductory offer |
| `limited-time-offer` | `fb-sales-sections.limited-time-offer` | Time-limited promotion |
| `cta` | `fb-sales-sections.cta` | Call-to-action button |

### 2.4 Layout/Config Sections

| Component | Strapi Schema | Use Case |
|-----------|---------------|----------|
| `header-config` | `fb-sales-sections.header-config` | Page header |
| `footer-config` | `fb-sales-sections.footer-config` | Page footer |
| `graph-config` | `fb-sales-sections.graph-config` | Graph configuration |
| `before-after-config` | `fb-sales-sections.before-after-config` | Before/after config |
| `list` | `fb-sales-sections.list` | Generic list |

---

## 3. FB Thank You Screens (Post-Purchase)

Location: `src/components/fb-thank-you-screens/`

| Component | Strapi Schema | Use Case |
|-----------|---------------|----------|
| `download-section` | `fb-thank-you-screens.download-section` | App download CTA |
| `text-section` | `fb-thank-you-screens.text-section` | Text/instructions |
| `link-section` | `fb-thank-you-screens.link-section` | Links list |
| `link-items` | `fb-thank-you-screens.link-items` | Individual link items |
| `list-item` | `fb-thank-you-screens.list-item` | List items |
| `create-account` | `fb-thank-you-screens.create-account` | Account creation form |
| `how-to-get` | `fb-thank-you-screens.how-to-get` | Instructions section |
| `how-to-get-with-create-account` | `fb-thank-you-screens.how-to-get-with-create-account` | Instructions + account |
| `graph-sections` | `fb-thank-you-screens.graph-sections` | Progress graph |
| `imagination-section` | `fb-thank-you-screens.imagination-section` | Motivational section |

---

## 4. Checkout Sections

Location: `src/components/checkout-sections/`

| Component | Strapi Schema | Use Case |
|-----------|---------------|----------|
| `header` | `checkout-sections.header` | Checkout header |
| `payment-form` | `checkout-sections.payment-form` | Payment form |

---

## 5. FB Start Screens

Location: `src/components/fb-start-screens/`

| Component | Strapi Schema | Use Case |
|-----------|---------------|----------|
| `start-screen` | `fb-start-screens.start-screen` | Initial funnel screen |
| `start-screen-v2` | `fb-start-screens.start-screen-v2` | Version 2 layout |
| `start-screen-v3` | `fb-start-screens.start-screen-v3` | Version 3 layout |
| `start-screen-grid` | `fb-start-screens.start-screen-grid` | Grid layout start |
| `start-static-screen` | `fb-start-screens.start-static-screen` | Static start screen |

---

## 6. FB Loader Screens

Location: `src/components/fb-loader-screens/`

| Component | Strapi Schema | Use Case |
|-----------|---------------|----------|
| `loader-default` | `fb-loader-screens.loader-default` | Default loader |
| `loader-static` | `fb-loader-screens.loader-static` | Static loader |
| `loader-with-image` | `fb-loader-screens.loader-with-image` | Loader with image |
| `loader-with-reviews` | `fb-loader-screens.loader-with-reviews` | Loader with testimonials |
| `loader-with-text` | `fb-loader-screens.loader-with-text` | Loader with text |

---

## 7. FB Upsells

Location: `src/components/fb-upsells/`

| Component | Strapi Schema | Use Case |
|-----------|---------------|----------|
| `brand-upsell` | `fb-upsells.brand-upsell` | Brand upsell offer |
| `bullet-list` | `fb-upsells.bullet-list` | Benefits list |
| `checkbox-list` | `fb-upsells.checkbox-list` | Selectable options |
| `image-banner` | `fb-upsells.image-banner` | Image banner |
| `list` | `fb-upsells.list` | Generic list |
| `subtitle` | `fb-upsells.subtitle` | Subtitle text |

---

## 8. Design Concepts

Location: `src/components/funnel-builder/design-concept.json`

Available concepts:
- `concept_1` - Default design
- `concept_2` - Alternative design

Available layouts:
- `layout_1` - Default layout
- `layout_2` - Alternative layout

---

## Pattern Matching Guide

### How to Match Figma Design to Component

1. **Identify the screen type:**
   - Onboarding/Funnel → FB Screens
   - Sales/Pricing → FB Sales Sections
   - Post-purchase → FB Thank You Screens
   - Payment → Checkout Sections

2. **Identify the interaction pattern:**
   - Pick ONE option → Single Choice
   - Pick MULTIPLE options → Multiple Choice
   - No interaction (info only) → Static Screen
   - Text input → Input Screen
   - Slider → Range Screen

3. **Check for design system:**
   - Amethyst design → `amethyst-*` components
   - Quantum design → `quantum-*` components
   - Elysium design → `elysium-*` components

4. **Check enum values:**
   - If design matches existing enum → Just add content in CMS
   - If similar but different → Check if new enum value needed
   - If completely new → Consider creating new component

### Decision Tree

```
Is this an onboarding screen?
├── Yes → Does user make a choice?
│   ├── ONE choice → single-choice or amethyst-single-choice-*
│   ├── MULTIPLE choices → multiple-choice or amethyst-multiple-choice-*
│   └── NO choice (info only) → amethyst-static-screen or quantum-static-screen
└── No → Is this a sales page section?
    ├── Yes → Check fb-sales-sections for matching pattern
    │   ├── Timer → elysium-timer or quantum-timer
    │   ├── Plans → plans or elysium-plans or quantum-plans
    │   ├── Reviews → reviews or elysium-reviews or quantum-reviews
    │   ├── FAQ → faq-section or elysium-faq or quantum-faq
    │   ├── Guarantee → money-back or elysium-guarantee or quantum-guarantee
    │   └── Custom → static-section with appropriate enum
    └── No → Is this a thank you page?
        ├── Yes → Check fb-thank-you-screens
        │   ├── Download app → download-section
        │   ├── Instructions → how-to-get
        │   └── Account creation → create-account
        └── No → Check other categories or create new

```

---

## Adding New Patterns

When you need to add a new pattern:

### Option A: Add New Enum Value (Preferred)

If the component type exists but needs a new variant:

1. Update the schema JSON file in gringotts-strapi-cms
2. Add new enum value to the `name` attribute
3. Create corresponding frontend component
4. Update this documentation

**Example:**
```json
// src/components/fb-sales-sections/static-section.json
{
  "attributes": {
    "name": {
      "type": "enumeration",
      "enum": [
        "social-proof",
        "comparison",
        "hero-human",
        "hero-app-screen",
        "money-back",
        "social-proof-v2",
        "family-plans"  // NEW
      ]
    }
  }
}
```

### Option B: Create New Component

If no existing pattern fits:

1. Create new schema JSON in appropriate `src/components/` folder
2. Create frontend component in promova.com_monorepo
3. Add documentation here
4. Run `sync-patterns` command to verify

---

## Changelog

| Date | Change |
|------|--------|
| 2025-12-29 | Initial documentation created |