# Fred1210 iOS — Design Spec

Living document driving Phase 4 UX work (v2.4.0). Anything in `Core/Theme/Theme.swift` is authoritative for tokens; anything here overrides only if we decide to change the Theme itself.

## Design principles

1. **Headline-first hierarchy.** Every screen answers "what changed?" in one glance. Details are one tap away.
2. **Actions where data is.** If a number matters, tapping it shows the underlying list. Navigation that isn't obvious isn't there.
3. **Graceful degradation.** Every screen renders a useful placeholder when offline, when a subsystem failed, or when data is empty. Never show "error".
4. **Familiar iOS.** Pull-to-refresh, swipe-actions, long-press, system search bars. Don't invent gestures.
5. **Dark by default.** The existing palette is dark-mode only — ship iteration 1 as dark, add light support later if needed.

## Token audit (Theme.swift)

Current tokens are good. Confirming scope:

- **Brand**: `primary` (#6c5ce7), `primaryLight`, `primaryDark`
- **Surfaces**: `bgDark` (page), `bgCard` (cards), `bgCardHover`, `bgInput`
- **Text**: `textPrimary`, `textSecondary`, `textMuted`
- **Semantic**: `success`, `warning`, `error`, `info`
- **Border**: `border`, `borderLight`
- **Spacing**: `xs` 4, `sm` 8, `md` 12, `lg` 16, `xl` 24, `xxl` 32
- **Font**: `xs` 11, `sm` 13, `md` 15, `lg` 18, `xl` 22, `xxl` 28
- **Radius**: `sm` 6, `md` 10, `lg` 14, `xl` 20

**Add in Phase 4:** `Spacing.xxxl = 48` (hero spacing between cards); `Font.hero = 36` (dashboard stat headlines).

## Component library (new)

Components needed in `Core/UI/`. Each is a pure SwiftUI view with no business logic.

### `Card`
The primary surface container. Replaces ad-hoc `VStack { … }.background(Theme.bgCard)` scattered across views.

```
Card {
  CardHeader(title: "Tasks", subtitle: "You have 3 urgent")
  CardBody { … }
  CardFooter { Text("Tap to view").foregroundStyle(Theme.textMuted) }
}
```

- Padding: `Spacing.lg` all sides.
- Background: `Theme.bgCard`.
- Radius: `Theme.Radius.lg`.
- Border: 1pt `Theme.border` (visible on `bgDark` only, invisible when nested).
- Tap action optional (passed via `.onTapGesture`). Tappable cards highlight to `bgCardHover` with a `.default` animation.

### `StatCard`
Specialization of Card for dashboard headline metrics.

```
StatCard(
  icon: "checklist",
  iconTint: Theme.primary,
  stat: "14",
  label: "open tasks",
  hint: "3 urgent · 2 overdue"
)
```

- Icon at top-left, 24pt.
- Stat uses `Font.hero` weight `.bold` `.rounded`.
- Label uses `Font.xs` uppercase tracking-wide.
- Hint uses `Font.xs` color `textMuted`.

### `InlineLoader`
Compact loading state for refreshing an individual card.

```
InlineLoader("Refreshing…")
```

- 16pt progress indicator + small label, inline horizontal.

### `EmptyState`
Consistent empty/first-run render.

```
EmptyState(
  systemImage: "checkmark.seal",
  title: "No tasks",
  detail: "Pull down to refresh, or tap + to add one."
)
```

- Centered SF Symbol 40pt `textMuted`.
- Title `Font.md` `.semibold` `textPrimary`.
- Detail `Font.sm` `textMuted`.

### `SectionHeader`
Replaces repeated `Text("FOO").font(.xs)...` patterns.

```
SectionHeader("Today", trailing: { Button("See all") { … } })
```

## Dashboard redesign (P4.1)

The current dashboard is a data wall. New layout:

```
┌─────────────────────────────────┐
│ Good afternoon · 2:14 PM        │  ← PageHeader (time-of-day + refresh spinner inline)
├─────────────────────────────────┤
│ ┌─────────────┐ ┌─────────────┐ │
│ │ TODAY       │ │ TASKS       │ │  ← Top row: two compact StatCards
│ │ 12 events   │ │ 14 open     │ │
│ │ 3 meetings  │ │ 3 urgent    │ │
│ └─────────────┘ └─────────────┘ │
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ TEAM STATUS                 │ │  ← Full-width card with list of services
│ │ ● OpenRouter    active      │ │
│ │ ● Ollama        active      │ │
│ │ ⚠ Telegram       degraded    │ │
│ └─────────────────────────────┘ │
├─────────────────────────────────┤
│ ┌─────────────┐ ┌─────────────┐ │
│ │ MEMORY      │ │ PIPELINES   │ │  ← Stat row again for secondary data
│ │ 3,214 facts │ │ 2 running   │ │
│ │ +42 today   │ │ 1 completed │ │
│ └─────────────┘ └─────────────┘ │
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ RECENT RESEARCH             │ │  ← Full-width, 3 most recent items
│ │ • Kyndryl partnership       │ │
│ │ • OpenClaw release notes    │ │
│ │ • Shannon upstream sync     │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

Behavior:
- Top greeting greets by time of day + Fred's name.
- StatCards tap-through to their respective tab or a filtered view (Tasks → Tasks tab, Today → system Calendar, Team → detail sheet, Memory → detail sheet, Research → Chat with research context).
- Refresh spinner appears in the header area only during manual refresh. Background fetches are silent.

## Task gestures (P4.2)

- **Leading swipe (short)** → toggle status (current → next in cycle). Green accent.
- **Leading swipe (full)** → mark Done. Green accent with checkmark.
- **Trailing swipe (short)** → open detail sheet (inline peek, not modal).
- **Trailing swipe (full)** → delete. Red with trash.
- **Long press** → context menu with:
  - Set priority → submenu (Urgent / High / Medium / Low / None)
  - Set status → submenu (Inbox / Todo / In Progress / Review / Done)
  - Copy title
  - Share (for links in descriptions)
  - Delete (destructive, at bottom)

Animation: 250ms ease for status changes; optimistic update + revert on server error.

## Chat threading (P4.3)

- `DateDivider` view: "Today", "Yesterday", or `Monday, Apr 14`. Styled like iOS Messages.
- Groups consecutive messages from the same role under a single role label (not one per bubble).
- Search field in toolbar — collapses when inactive, expands to full-width when tapped (`.searchable(text:)` attached to the NavigationStack). On-device string match, highlights matches in the rendered bubble text.
- "Load older" button at the top of the list; fetches with a query param (`?before=<oldest_id>`) once the server supports pagination. Until then, it's a no-op stub.

## Tool-call streaming (P4.4)

Server adds `POST /api/agent/chat?stream=sse`. Response: `text/event-stream` with events:

```
event: tool_start
data: {"name":"web_search","args":{"query":"Kyndryl"},"id":"call_01"}

event: tool_end
data: {"id":"call_01","durationMs":3182,"ok":true}

event: content_delta
data: {"text":"Based on my research, "}

event: done
data: {"totalMs":18432}
```

Client renders:

```
YOU
  Research Kyndryl's recent announcements

FRED
  ┌─────────────────────────────────┐
  │ 🔧 web_search("Kyndryl")  3.2s  │  ← inline tool-call chip, status live
  │ 🔧 web_fetch(...)          1.1s │
  │ 🔧 web_search("partnerships") … │  ← "…" = currently running
  └─────────────────────────────────┘
  Based on my research, Kyndryl recently…
```

Chips use `Card` at small size, monospaced name, duration right-aligned. Failed tool calls flash red briefly.

## Notifications preferences (P4.5)

Settings → Notifications adds a toggle group:

```
Notifications            [ON]
─────────────────────────────
Daily digest             [✓]  (Research synthesis + calendar brief)
Urgent tasks             [✓]  (Overdue or priority=urgent)
Research findings        [ ]  (From watch-topic / proactive research)
Transport alerts         [✓]  (Slack/Telegram outages)
```

Server stores `{digest, urgent_tasks, research_findings, transport_alerts}` keyed by device token; `PushDelivery.send` reads the array of `{token, preferences}` and fans out only to opted-in devices.

## Motion

- Card entry: fade + 4pt translate-up over 200ms, staggered 40ms between cards.
- Pull-to-refresh: default iOS spinner.
- Error banner: slide in from top 200ms, auto-fade after 10s unless the user interacts.
- Tab switch: default iOS tab behavior. No custom transitions.

## Accessibility

- All StatCards support Dynamic Type up to XXL.
- Voiceover reads stat + label + hint in that order.
- Error banner uses `accessibilityRepresentation` to announce as a single text blob.
- Minimum contrast 4.5:1 against backgrounds; the current palette already passes.

## What's NOT in Phase 4

- Light-mode theme — explicit decision; revisit after user testing.
- iPad layout — ship as-is (iPhone-only `TARGETED_DEVICE_FAMILY: "1"`).
- Onboarding flow — host URL lives in Settings, that's enough until external testing.
- Deep links from push → specific screens — out of scope, Phase 5.

## Open questions

1. **Today card data source.** The server's `/api/agent/dashboard` doesn't include calendar events today. Either (a) plumb calendar through dashboard, (b) fetch from a new `/api/agent/calendar/today`, or (c) fall back to showing "Open Calendar app".
2. **Research items endpoint.** Dashboard response has `upstream` info but no "recent research" field. Server work needed to surface the research store.
3. **Pipelines vs automations.** Dashboard has `pipelines` already — is this the right metric or should it be running agent loops? Product call.

---

**Review checklist** before P4.1 codes any dashboard:
- [ ] Cards agreed
- [ ] Stat semantics agreed (e.g., is "urgent" the same as "overdue"?)
- [ ] Open questions resolved or explicitly deferred
