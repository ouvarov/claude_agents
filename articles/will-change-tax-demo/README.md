# will-change tax — view() parallax demo

Live test for the code from `will-change-tax.en.md`. Verifies:

- `animation-timeline: view()` plays parallax tied to scroll position
- `translate` (individual transform property) rides the compositor fast-path
- No `will-change` anywhere
- No JS scroll handlers (main thread stays free)

## Run

Any static server works. From this folder:

```sh
python3 -m http.server 8080
# then open http://localhost:8080
```

Or open `index.html` directly in Chrome / Safari 26+ / Edge.

## What to check in DevTools

1. **Performance panel** — record while scrolling. The animation thread should be doing work; the main thread should be idle (no `scroll` listeners).
2. **Layers panel** (More tools → Layers in Chrome) — the parallax figures are composited layers. Their Memory estimate scales with `width × height × DPR² × 4 bytes`. Wrapper sections should NOT be promoted (no `will-change`, no inline transform, no overlap from `position: fixed`, etc.).
3. **Rendering panel → Paint flashing** — no paint repeats inside the parallax figures while scrolling. Only the composite step runs.

## Browser support snapshot

| Feature                    | Chrome 115+ | Safari 26+ | Firefox |
|----------------------------|-------------|------------|---------|
| `animation-timeline: view()` | ✅          | ✅          | ❌ (flag) |
| `translate` property       | ✅          | ✅          | ✅       |

The header chip in the demo reflects what the current browser supports.

## Notes

- Firefox guard: scroll-driven animations need an explicit `animation-duration`. The CSS sets `1ms` inside `@supports (animation-timeline: view())` so Firefox plays them when enabled via flag.
- `prefers-reduced-motion: reduce` disables all animations for accessibility.
