---
name: lottiefiles-animation
description: Create and edit professional, fluid vector animations using the LottieFiles Creator MCP. Use for polished UI micro-interactions, loading states, and vector graphics.
---

# LottieFiles Animation

Use this skill whenever you need to design or animate vector graphics, UI micro-interactions (like buttons, loaders, icons), or complex SVG motion using the LottieFiles Creator MCP.

## Best Practices for Professional Animations
1. **Easing is Essential:** Never use linear animation unless strictly required (like a continuous spinning loader). Always use custom easing curves (e.g., ease-in-out, cubic-bezier) or motion presets like `apply_bounce` and `apply_squash` to make animations feel physical, fluid, and natural.
2. **Subtlety over Complexity:** Avoid overly busy animations. A professional UI animation focuses on one or two key properties (e.g., opacity and scale) rather than animating every possible element.
3. **Clean Vector Structure:** Group shapes logically before animating using `group_layers`. Keep layer counts as minimal as possible for performance. Ensure colors align with the project's existing design system or use standard professional palettes.
4. **Staggering:** When animating multiple items (e.g., a list appearing, or multiple dots in a loader), use `stagger_layers` to offset their start times. This creates a highly polished, professional cascade effect.

## Usage
- Trigger this skill when the user asks for Lottie animations, animated icons, loaders, or vector interactions.
- Utilize MCP tools like `create_shape`, `animate_property`, `apply_keyframes`, `stagger_layers`, and motion presets.
