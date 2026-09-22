---
name: premium-ui-design
description: >
  Premium UI design skill that MUST be activated for ANY task involving UI generation, design, web components, Flutter widgets,
  styling, animations, or visual polish. Combines Emil Kowalski's design engineering philosophy, his animation decision framework,
  Apple's fluid interface principles (from WWDC), the better-ui polish rules (concentric radius, optical alignment, contextual icon
  animations, surface depth), and a complete Flutter implementation guide mapping every principle to Dart/Flutter equivalents.
  Trigger on: build UI, design a screen, create a component, style something, add animation, make it look better, improve design,
  web app, Flutter app, mobile app, landing page, dashboard, modal, bottom sheet, button, card, form, widget, any visual output.
---

# Premium UI Design

> This skill MUST be read and applied **in full** whenever generating, reviewing, or improving any UI — web, mobile, component, or layout.
> It synthesises three sources: Emil Kowalski's design engineering philosophy, Apple's Designing Fluid Interfaces (WWDC), and the `better-ui` polish rules.

---

## Part 1 — Core Design Philosophy (Emil Kowalski)

### Taste is trained, not innate

Good taste is a trained instinct: the ability to recognise what elevates beyond the obvious. Develop it by surrounding yourself with great work, thinking deeply about *why* something feels right, and practising relentlessly. Study why the best interfaces feel the way they do. Reverse-engineer animations. Inspect interactions. Be curious.

### Unseen details compound

Most details users never consciously notice. That is the point. When a feature works exactly as assumed, users proceed without a second thought.

> "All those unseen details combine to produce something that's just stunning, like a thousand barely audible voices all singing in tune." — Paul Graham

### Beauty is leverage

People select tools based on overall experience, not just functionality. Good defaults and good animations are real differentiators. Beauty is underutilised in software — use it as leverage.

---

## Part 2 — The Animation Decision Framework

Run this sequence **in order** before writing a single line of animation code.

### Step 1 — Should it animate at all?

| Frequency | Decision |
|---|---|
| 100+ times/day (keyboard shortcuts, command palette) | **No animation. Ever. Stop here.** |
| Tens of times/day (hover effects, list navigation) | Near-imperceptible only, or nothing |
| Occasional (modals, drawers, toasts) | Standard animation |
| Rare / first-time (onboarding, celebration) | Delight budget lives here |

**Keyboard-initiated actions are a disqualifier, not a judgment call.** Raycast has no open/close animation — that is correct.

### Step 2 — What is the purpose?

Name it in one word before continuing:

- **Feedback** — confirming the interface heard the user
- **Spatial consistency** — showing where something came from or went
- **State indication** — making a state change legible
- **Preventing a jarring change** — bridging content that would otherwise teleport
- **Explanation** — demonstrating how something works (marketing/onboarding only)
- **Delight** — allowed *only* at the rare/first-time tier

Can't name it? Don't build it. "It looks cool" on a frequently-seen element is a reason to stop.

### Step 3 — Pick the tool (cheapest that works)

| Need | Tool |
|---|---|
| Hover, press, color, class/attribute-toggled state | **CSS transition** |
| Entry animation on mount, no JS state | **CSS `@starting-style`** |
| Predetermined smooth motion while page is busy | **CSS animation** (off main thread) |
| Programmatic control with CSS perf, no library | **WAAPI** (`element.animate()`) |
| Springs, layout animations, exit animations, gestures | **Motion** (`motion.dev`) |

Don't install a motion library for a fade.

### Step 4 — Pick the properties

- **`transform` and `opacity` only** — they skip layout and paint, stay on the GPU compositor.
- Never animate `width`, `height`, `top`, `left`, `margin`, `padding` — they trigger layout.
- Use `will-change: transform` only when profiling shows it helps.

### Step 5 — Pick the easing

Is the element entering or exiting?
  → **ease-out** (starts fast, feels responsive)

Is it moving/morphing on screen?
  → **ease-in-out** (natural acceleration/deceleration)

Is it a hover/color change?
  → **ease**

Is it constant motion (marquee, progress bar)?
  → **linear**

**Critical: use custom easing curves — the built-in CSS easings are too weak.**

```css
--ease-out: cubic-bezier(0.23, 1, 0.32, 1);
--ease-in-out: cubic-bezier(0.77, 0, 0.175, 1);
--ease-drawer: cubic-bezier(0.32, 0.72, 0, 1);
```

**Never use `ease-in` for UI animations.** It starts slow, making the interface feel sluggish. A dropdown with `ease-in` at 300ms *feels* slower than `ease-out` at 300ms, because ease-in delays initial movement — exactly when the user is watching most closely.

Curve resources: [easing.dev](https://easing.dev/) and [easings.co](https://easings.co/).

### Step 6 — Pick the duration

| Element | Duration |
|---|---|
| Button press feedback | 100–160ms |
| Tooltips, small popovers | 125–200ms |
| Dropdowns, selects | 150–250ms |
| Modals, drawers | 200–500ms |
| Marketing/explanatory | Can be longer |

**UI animations should stay under 300ms.** A 180ms dropdown feels more responsive than a 400ms one.

---

## Part 3 — Spring Animations

Springs feel more natural than duration-based animations because they simulate real physics and have no fixed duration — they settle based on physical parameters.

### When to use springs

- Drag interactions with momentum
- Elements that should feel "alive"
- Gestures that can be interrupted mid-animation
- Decorative mouse-tracking interactions

### Spring configuration

**Apple's approach (recommended):**
```js
{ type: "spring", duration: 0.5, bounce: 0.2 }
```

**Traditional physics (more control):**
```js
{ type: "spring", mass: 1, stiffness: 100, damping: 10 }
```

Keep bounce subtle (0.1–0.3) when used. **Avoid bounce in most UI contexts.** Use it for drag-to-dismiss and playful interactions.

### Interruptibility

Springs maintain velocity when interrupted — CSS animations restart from zero. This makes springs ideal for gestures users might reverse mid-motion.

### Spring mouse interactions

Tying visual changes directly to mouse position feels artificial without momentum. Use `useSpring` from Motion:

```jsx
import { useSpring } from 'framer-motion';
// With spring: feels natural, has momentum
const springRotation = useSpring(mouseX * 0.1, { stiffness: 100, damping: 10 });
```

---

## Part 4 — Component Building Rules

### Buttons must feel responsive

```css
.button { transition: transform 160ms ease-out; }
.button:active { transform: scale(0.97); }
```

Applies to any pressable element. Scale should be subtle (0.95–0.98).

### Never animate from `scale(0)`

Nothing in the real world disappears completely. Start from `scale(0.9)` or higher with opacity:

```css
/* Bad */
.entering { transform: scale(0); }

/* Good */
.entering { transform: scale(0.95); opacity: 0; }
```

### Make popovers origin-aware

Popovers should scale in from their trigger, not from center. Default `transform-origin: center` is wrong for almost every popover.

```css
.popover { transform-origin: var(--transform-origin, top left); }
```

### UI Review Format

When reviewing UI code, use a markdown table with Before/After columns:

| Before | After | Why |
|---|---|---|
| `transition: all 300ms` | `transition: transform 200ms ease-out` | Specify exact properties; avoid `all` |
| `transform: scale(0)` | `transform: scale(0.95); opacity: 0` | Nothing appears from nothing |
| `ease-in` on dropdown | `ease-out` with custom curve | `ease-in` feels sluggish |
| No `:active` state | `transform: scale(0.97)` on `:active` | Buttons must feel responsive |

---

## Part 5 — Apple Fluid Interface Principles (WWDC)

> "When we align the interface to the way we think and move, something magical happens — it stops feeling like a computer and starts feeling like a seamless extension of us."

An interface is fluid when things respond instantly, move continuously, carry momentum, resist at boundaries, and can be redirected mid-motion.

### Response — kill latency

- **Respond on pointer-down, not release.** Highlight a button the instant it is pressed.
- **Be vigilant about every latency.** Audit debounces, artificial timers, and the ~300ms tap delay.
- **Feedback must be continuous during the interaction**, not just at the end.

### Direct manipulation — 1:1 tracking

When the user drags something it must stay glued to the finger and respect the grab offset:

```js
el.addEventListener('pointerdown', (e) => {
  el.setPointerCapture(e.pointerId);
  const grabOffset = e.clientY - el.getBoundingClientRect().top;
  // track position + timestamp history for velocity
});
```

### Interruptibility — the most important principle

> "The thought and the gesture happen in parallel."

- **Never lock out input during a transition.**
- **Animate from the current (presentation) value, never the target.** On interrupt, read the live on-screen transform.
- **Avoid CSS transitions for anything gesture-driven** — springs are inherently interruptible.
- **When a gesture reverses, blend velocity — don't hard-cut it.**

### Apple Spring Values

| Interaction | Damping | Response |
|---|---|---|
| Move / reposition (PiP) | `1.0` | `0.4s` |
| Rotation | `0.8` | `0.4s` |
| Drawer / sheet | `0.8` | `0.3s` |

```js
// Critically damped (no overshoot) — default for most UI
animate(el, { y: 0 }, { type: 'spring', bounce: 0, duration: 0.4 });

// Momentum interaction — bounce only when a flick preceded it
animate(el, { y: target }, { type: 'spring', bounce: 0.2, duration: 0.4 });
```

### Velocity handoff

When a gesture ends, the animation must **continue at the finger's exact velocity**:

```
relativeVelocity = gestureVelocity / (targetValue − currentValue)
```

### Momentum projection

```js
function project(initialVelocity /* px/s */, decelerationRate = 0.998) {
  return (initialVelocity / 1000) * decelerationRate / (1 - decelerationRate);
}
const projectedEndpoint = currentPosition + project(releaseVelocity);
const target = nearestSnapPoint(projectedEndpoint);
animateSpringTo(target, { velocity: releaseVelocity });
```

### Spatial consistency

- **Enter and exit along the same path.** A panel that slides in from the right must dismiss to the right.
- **Anchor interactions to their source.** Menus/popovers/sheets should originate from the element that triggered them.

---

## Part 6 — Better-UI Polish Rules

> Polish comes from a pile of small details that compound. Every duration, curve, scale and blur below is a specific value, not a range to approximate.

### Concentric border radius

**Outer radius = inner radius + padding.** Mismatched radii on nested elements is the most common thing that makes an interface feel off.

### Optical over geometric alignment

When geometric centering looks off, align optically. Buttons with icons, play triangles, and asymmetric icons all need a manual nudge.

### Shadows for elevation, borders for structure

Where a border exists only to create depth, prefer layered transparent `box-shadow` values. Keep borders that communicate structure or state: dividers, separators, selected or focus states.

### Interruptible animations

Use CSS transitions for interactive state changes — they can be interrupted mid-animation. Reserve keyframes for staged sequences that run once.

### Split and stagger enter animations

For an infrequent staged entrance, break content into semantic chunks and stagger by ~100ms. Leave high-frequency interactions unstaggered.

### Subtle exit animations

Use a small fixed `translateY` rather than full height. Exits should be softer than enters. Use `ease-out` for both directions.

### Contextual icon animations

Animate icons with `opacity`, `scale`, and `blur` — never toggle visibility. Exact values:
- scale: `0.25` → `1`
- opacity: `0` → `1`
- blur: `4px` → `0px`

**With a motion library** (`motion` or `framer-motion`):
```js
{ type: "spring", duration: 0.3, bounce: 0 }
// bounce is always 0 for icon transitions
```

**Without a motion library** — keep both icons in the DOM with one absolutely positioned, cross-fade with `cubic-bezier(0.2, 0, 0, 1)`.

### Image outlines

Give images a `1px` outline at low opacity for consistent depth:
- Light mode: `outline: 1px solid oklch(0 0 0 / 0.1)` (pure black)
- Dark mode: `outline: 1px solid oklch(1 0 0 / 0.1)` (pure white)

Never use a near-black like slate or zinc. Never a tinted neutral.

---

## Part 7 — Design System Fundamentals (getdesign.md)

A great UI needs a **single visual language** — a DESIGN.md — that specifies colors, typography, spacing, components, and the reasoning behind each. Without it, every new page diverges.

### Color system

- Avoid generic colors (plain red, blue, green). Use curated, harmonious palettes with HSL or OKLCH.
- Always provide both light and dark mode token values.
- Use semantic tokens (`--color-primary`, `--color-surface`, `--color-border`) not raw hex values in components.
- Background depth hierarchy: background → surface → elevated → overlay.

### Typography

- Use a modern typeface from Google Fonts (Inter, Geist, Outfit, Plus Jakarta Sans).
- Apply `font-feature-settings: "ss01"`, optical sizing (`font-optical-sizing: auto`).
- Use tabular numbers (`font-variant-numeric: tabular-nums`) for data.
- Type scale: establish a clear ramp (xs/sm/base/lg/xl/2xl/3xl) and never go off-scale.
- Line heights: `1.2` for headings, `1.5–1.6` for body text.
- Letter spacing: slightly negative (`-0.01em` to `-0.03em`) for large headings, normal for body.

### Spacing

- Use a consistent spacing scale (4px base unit).
- Internal padding should breathe — never cramped.
- Whitespace communicates hierarchy; group related items close, unrelated items far.

### Component consistency

- Every interactive element must have: default, hover, focus, active, disabled states.
- Focus rings must be visible and styled (not the browser default for polished work).
- Border radius must follow the concentric rule throughout.

### Dark mode

- Always implement dark mode from the start using CSS custom properties.
- Never use `filter: invert()` — use proper dark-mode token values.
- Shadows become less visible in dark mode; compensate with surface hierarchy and subtle borders.

---

## Part 8 — Flutter Implementation Guide

> All principles from Parts 1–7 apply to Flutter unchanged. This section maps every web implementation detail to its Dart/Flutter equivalent. When working in Flutter, read this alongside the relevant principle above — never implement the web version.

### Platform detection

Before writing any Flutter animation code, check:
- Is this **gesture-driven** (pan, drag, swipe)? → Use `GestureDetector` + `SpringSimulation` or `flutter_animate`'s `.animate()` chained API.
- Is this **state-driven** (show/hide, toggle)? → Use implicit animated widgets first.
- Is it **one-shot entrance/exit**? → `AnimationController` + `CurvedAnimation` or `flutter_animate`.

---

### 8.1 — Animation Toolchain (Flutter equivalent of Step 3)

Walk down; stop at the first that fits.

| Need | Flutter Tool |
|---|---|
| Simple property change on state change | **Implicit animated widgets** (`AnimatedContainer`, `AnimatedOpacity`, `AnimatedScale`, `AnimatedSlide`, `AnimatedPadding`) |
| Cross-fade between two widgets | **`AnimatedSwitcher`** |
| Hero / shared-element transition | **`Hero`** widget |
| Complex, chainable, readable animations | **`flutter_animate`** package (preferred for most cases) |
| Gesture-driven with momentum / springs | **`AnimationController` + `SpringSimulation`** or `flutter_animate` with custom simulation |
| Page/route transitions | **`PageRouteBuilder`** or `GoRouter`'s `transitionBuilder` |
| Layout size change animations | **`AnimatedSize`** |
| Staggered list entrances | **`flutter_animate`** with `.delay()` chaining, or `TweenSequence` |

**Never use `Timer` or `Future.delayed` to chain animations.** Use `AnimationController.addStatusListener` or `.animate()` sequencing.

**Install `flutter_animate` for almost everything** — it eliminates 80% of `AnimationController` boilerplate:
```yaml
# pubspec.yaml
dependencies:
  flutter_animate: ^4.5.0
```

---

### 8.2 — Easing Curves (Flutter equivalent of Step 5)

Flutter's `Curves` class maps directly to the custom cubic-bezier values from the web skill.

| Web curve | Flutter `Curves` equivalent | Use for |
|---|---|---|
| `cubic-bezier(0.23, 1, 0.32, 1)` | `Curves.easeOutQuint` | **Enters, slide-ins** (strong ease-out) |
| `cubic-bezier(0.77, 0, 0.175, 1)` | `Curves.easeInOutQuart` | **On-screen movement** |
| `cubic-bezier(0.32, 0.72, 0, 1)` | `Curves.easeOutCubic` | **Drawers, bottom sheets** |
| `ease-out` (generic) | `Curves.easeOut` | Quick state changes |
| `linear` | `Curves.linear` | Progress bars, marquees |

**Never use `Curves.easeIn` for UI animations** — same rule as the web. It starts slow and feels sluggish.

**Custom curve when nothing fits:**
```dart
// Equivalent to cubic-bezier(0.23, 1, 0.32, 1)
const strongEaseOut = Cubic(0.23, 1.0, 0.32, 1.0);
```

**With `flutter_animate`:**
```dart
child
  .animate()
  .fadeIn(curve: Curves.easeOutQuint, duration: 200.ms)
  .slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuint);
```

---

### 8.3 — Duration (Flutter equivalent of Step 6)

Same values apply. Use `Duration` extensions from `flutter_animate` (`.ms`) for readability:

| Element | Duration |
|---|---|
| Button press feedback | `100–160.ms` |
| Tooltips, small popovers | `125–200.ms` |
| Bottom sheets, dialogs | `200–350.ms` |
| Page transitions | `250–400.ms` |
| Onboarding / delight | `400–600.ms` |

```dart
// With flutter_animate
child.animate().scale(
  begin: const Offset(0.95, 0.95),
  end: const Offset(1, 1),
  duration: 200.ms,
  curve: Curves.easeOutQuint,
);

// With AnimationController
final _controller = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 200),
);
```

---

### 8.4 — Properties to Animate (Flutter equivalent of Step 4)

Prefer **compositing-layer properties** that skip layout:

| ✅ Animate these | ❌ Never animate these |
|---|---|
| `opacity` (`FadeTransition`, `AnimatedOpacity`) | `width`, `height` via rebuild |
| `scale` (`ScaleTransition`, `AnimatedScale`) | `padding`, `margin` |
| `translation/slide` (`SlideTransition`, `AnimatedSlide`) | `fontSize`, `constraints` |
| `rotation` (`RotationTransition`) | Any property that triggers layout |

**`AnimatedContainer` is the exception** — it is Flutter's implicit animated widget and *is* allowed to animate size/padding because Flutter handles the interpolation efficiently.

---

### 8.5 — Spring Animations in Flutter

**Option A — `SpringSimulation` (low-level, maximum control):**

```dart
final spring = SpringDescription(
  mass: 1,
  stiffness: 180,     // higher = snappier
  damping: 20,        // higher = less bounce
);

final simulation = SpringSimulation(spring, 0, 1, 0);
_controller.animateWith(simulation);
```

**Apple spring values mapped to Flutter:**

| Interaction | stiffness | damping |
|---|---|---|
| Move / reposition | `150` | `25` (critically damped) |
| Rotation | `120` | `18` (slight bounce) |
| Drawer / bottom sheet | `200` | `28` |

**Option B — `flutter_animate` with spring (recommended for most cases):**

```dart
child
  .animate()
  .scale(
    begin: const Offset(0.9, 0.9),
    end: const Offset(1, 1),
    duration: 500.ms,
    curve: Curves.elasticOut, // spring-like feel
  );
```

**Critically damped (no bounce) — use for most UI:**
```dart
// Equivalent to Apple's damping=1.0
const _kSpring = SpringDescription(mass: 1, stiffness: 200, damping: 28.3);
// damping = 2 * sqrt(mass * stiffness) for critical damping
```

**Velocity handoff from gesture (the seam between drag and spring):**

```dart
void _onPanEnd(DragEndDetails details) {
  final velocity = details.velocity.pixelsPerSecond.dy;
  final simulation = SpringSimulation(
    spring,
    _currentOffset,  // current presentation value
    _targetOffset,   // snap target
    velocity / _screenHeight, // normalised velocity
  );
  _controller.animateWith(simulation);
}
```

---

### 8.6 — Buttons Must Feel Responsive

**Never use `InkWell` alone for premium feel** — the ripple splash is a Material affordance, not a press confirmation. Layer a scale effect:

```dart
class PressableButton extends StatefulWidget { ... }

class _PressableButtonState extends State<PressableButton>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    reverseDuration: const Duration(milliseconds: 160),
  );
  late final _scale = Tween(begin: 1.0, end: 0.97).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOut),
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
```

**With `flutter_animate`** (simpler):
```dart
child
  .animate(target: _isPressed ? 1.0 : 0.0)
  .scale(begin: const Offset(1, 1), end: const Offset(0.97, 0.97), duration: 100.ms);
```

Scale range: `0.95–0.98`. Never below `0.93`.

---

### 8.7 — Never Animate from Scale Zero

Same rule. In Flutter, never start `ScaleTransition` from `0`. Use `0.9` minimum:

```dart
// Bad
ScaleTransition(scale: Tween(begin: 0.0, end: 1.0).animate(_controller))

// Good
ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(_controller))

// With flutter_animate (good)
child.animate().scale(begin: const Offset(0.9, 0.9)).fadeIn();
```

---

### 8.8 — Entrance & Exit Animations

**Enter — ease-out, fast, from slightly offset:**
```dart
// flutter_animate
child
  .animate()
  .fadeIn(duration: 200.ms, curve: Curves.easeOut)
  .slideY(begin: 0.04, end: 0, duration: 200.ms, curve: Curves.easeOutQuint);
```

**Exit — softer than enter, small offset:**
```dart
// Use AnimatedSwitcher for toggled widgets
AnimatedSwitcher(
  duration: const Duration(milliseconds: 160),
  reverseDuration: const Duration(milliseconds: 120), // exit faster
  transitionBuilder: (child, animation) => FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.03), // small Y — not full height
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: child,
    ),
  ),
  child: _showChild ? const MyWidget() : const SizedBox.shrink(),
)
```

---

### 8.9 — Staggered List Entrances

```dart
// flutter_animate — stagger each item by 80ms
ListView.builder(
  itemBuilder: (context, index) => MyCard()
    .animate(delay: (index * 80).ms)
    .fadeIn(duration: 200.ms)
    .slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuint),
)
```

Leave high-frequency interactions (search results, typing) unstaggered.

---

### 8.10 — Icon Transitions (Contextual Icon Animations)

Exact values from better-ui, implemented in Flutter:
- scale: `0.25` → `1.0`
- opacity: `0` → `1.0`
- blur: simulate with `ImageFilter.blur` or skip on mobile (blur is expensive)

```dart
// AnimatedSwitcher for icon swaps
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  transitionBuilder: (child, animation) {
    return ScaleTransition(
      scale: Tween(begin: 0.25, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutQuint),
      ),
      child: FadeTransition(opacity: animation, child: child),
    );
  },
  child: Icon(_isFav ? Icons.favorite : Icons.favorite_border,
      key: ValueKey(_isFav)),
)

// With flutter_animate
Icon(_isFav ? Icons.favorite : Icons.favorite_border, key: ValueKey(_isFav))
  .animate()
  .scale(begin: const Offset(0.25, 0.25), duration: 300.ms,
         curve: Curves.easeOutQuint)
  .fadeIn(duration: 300.ms);
```

---

### 8.11 — Bottom Sheets and Drawers (Spatial Consistency)

**Enter from bottom, dismiss to bottom.** Never dismiss upward what entered from below.

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (context) => DraggableScrollableSheet(...),
);
```

For custom bottom sheets with spring physics — use `DraggableScrollableSheet` or the [`sheet`](https://pub.dev/packages/sheet) package, which provides velocity-aware spring snapping out of the box.

**Velocity handoff on drag-to-dismiss:**
```dart
GestureDetector(
  onVerticalDragEnd: (details) {
    if (details.velocity.pixelsPerSecond.dy > 500) {
      Navigator.pop(context); // fast flick — dismiss
    } else {
      _snapBackAnimation(); // spring back
    }
  },
)
```

---

### 8.12 — Page Transitions

Default `MaterialPageRoute` is adequate for Material apps. For premium feel:

```dart
// Slide from right — spatial consistency
PageRouteBuilder(
  pageBuilder: (_, __, ___) => const NextPage(),
  transitionDuration: const Duration(milliseconds: 300),
  reverseTransitionDuration: const Duration(milliseconds: 250),
  transitionsBuilder: (_, animation, __, child) {
    final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(curve),
      child: FadeTransition(opacity: Tween(begin: 0.0, end: 1.0).animate(curve), child: child),
    );
  },
)
```

**With GoRouter:**
```dart
GoRoute(
  path: '/detail',
  pageBuilder: (context, state) => CustomTransitionPage(
    child: const DetailPage(),
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
  ),
)
```

**Hero transitions for shared elements:**
```dart
// Source
Hero(tag: 'card-${item.id}', child: ItemCard(item: item))

// Destination
Hero(tag: 'card-${item.id}', child: ItemDetail(item: item))
```

---

### 8.13 — Concentric Border Radius in Flutter

**Outer `borderRadius` = inner `borderRadius` + `padding`**

```dart
// Card with 16px outer radius, 8px padding → inner content gets 8px radius
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16), // outer
  ),
  padding: const EdgeInsets.all(8),
  child: Container(
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(8), // inner = outer - padding
    ),
    child: const MyContent(),
  ),
)
```

---

### 8.14 — Optical Alignment in Flutter

```dart
// Nudge an asymmetric icon for optical centre
Transform.translate(
  offset: const Offset(1.5, 0), // 1–2px nudge
  child: const Icon(Icons.play_arrow),
)
```

---

### 8.15 — Shadows for Elevation, Borders for Structure

```dart
// Elevation shadow — prefer over a border when showing depth
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.06),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ],
  ),
)

// Structure border — use for dividers, selected state
Container(
  decoration: BoxDecoration(
    border: Border.all(color: Colors.grey.shade200),
    borderRadius: BorderRadius.circular(12),
  ),
)
```

In dark mode, shadows become invisible — switch to a subtle border + surface elevation:
```dart
final isDark = Theme.of(context).brightness == Brightness.dark;
BoxDecoration(
  color: isDark ? Colors.grey.shade900 : Colors.white,
  border: isDark ? Border.all(color: Colors.white.withOpacity(0.08)) : null,
  boxShadow: isDark ? null : [/* shadows */],
)
```

---

### 8.16 — Image Outlines in Flutter

```dart
final isDark = Theme.of(context).brightness == Brightness.dark;

Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: isDark
          ? Colors.white.withOpacity(0.1)   // pure white, 10% opacity
          : Colors.black.withOpacity(0.1),  // pure black, 10% opacity
      width: 1,
    ),
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(7), // inner = outer - border width
    child: Image.network(url),
  ),
)
```

---

### 8.17 — Design System in Flutter

**Colour tokens — use `ThemeExtension`:**
```dart
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.primary,
  });
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color primary;

  @override
  AppColors copyWith({...}) => AppColors(...);

  @override
  AppColors lerp(AppColors? other, double t) => AppColors(
    surface: Color.lerp(surface, other?.surface, t)!,
    // ...
  );

  static const light = AppColors(
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF5F5F5),
    border: Color(0xFFE5E5E5),
    primary: Color(0xFF6366F1),
  );
  static const dark = AppColors(
    surface: Color(0xFF0F0F0F),
    surfaceElevated: Color(0xFF1A1A1A),
    border: Color(0xFF262626),
    primary: Color(0xFF818CF8),
  );
}

// Usage
final colors = Theme.of(context).extension<AppColors>()!;
```

**Typography — use `TextTheme` with custom font:**
```dart
// pubspec.yaml → google_fonts: ^6.0.0
ThemeData(
  textTheme: GoogleFonts.interTextTheme().copyWith(
    displayLarge: GoogleFonts.inter(
      fontSize: 40, fontWeight: FontWeight.w700,
      letterSpacing: -1.2, height: 1.1,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 15, fontWeight: FontWeight.w400,
      letterSpacing: -0.1, height: 1.55,
    ),
  ),
)
```

**Spacing — define a constant scale:**
```dart
abstract class Spacing {
  static const xs  = 4.0;
  static const sm  = 8.0;
  static const md  = 12.0;
  static const lg  = 16.0;
  static const xl  = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}
// Never use magic numbers — always reference Spacing.md etc.
```

**Dark mode — always implement from start:**
```dart
MaterialApp(
  themeMode: ThemeMode.system, // always respect system setting
  theme: ThemeData.light().copyWith(
    extensions: [AppColors.light],
  ),
  darkTheme: ThemeData.dark().copyWith(
    extensions: [AppColors.dark],
  ),
)
```

---

### 8.18 — Direct Manipulation in Flutter

```dart
// 1:1 finger tracking — respect grab offset
GestureDetector(
  onPanStart: (details) {
    _grabOffset = details.localPosition.dy; // where they touched
  },
  onPanUpdate: (details) {
    setState(() {
      _position = details.globalPosition.dy - _grabOffset;
    });
  },
  onPanEnd: (details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    _animateWithVelocity(velocity);
  },
  child: Transform.translate(
    offset: Offset(0, _position),
    child: widget.child,
  ),
)
```

**Interruptibility** — `AnimationController.stop()` reads live position:
```dart
void _onPanStart(_) {
  _controller.stop(); // stops at current value — never jumps
  _currentValue = _controller.value;
}
```

---

### 8.19 — Flutter-Specific Review Format

When reviewing Flutter UI code use the same Before/After table format, but with Flutter:

| Before | After | Why |
|---|---|---|
| `AnimatedContainer(duration: Duration(milliseconds: 500))` | `duration: const Duration(milliseconds: 200)` | 500ms is sluggish for state changes |
| `Curves.easeIn` on slide-in | `Curves.easeOutQuint` | `easeIn` starts slow — feels unresponsive |
| `ScaleTransition(scale: Tween(begin: 0.0, ...))` | `Tween(begin: 0.9, ...)` + `FadeTransition` | Nothing appears from nothing |
| `Timer(300.ms, () => setState(...))` | `AnimationController` status listener | Never use timers to chain animations |
| Hard-coded `Color(0xFF...)` in widget | `Theme.of(context).extension<AppColors>()!.surface` | Tokens, not hex values |
| `BorderRadius.circular(12)` outer, `BorderRadius.circular(12)` inner | Inner = `12 - padding` (e.g. `4` if padding is `8`) | Concentric radius rule |
| `boxShadow` same in dark mode | Remove shadow, add `border: Border.all(color: Colors.white.withOpacity(0.08))` | Shadows invisible in dark mode |
