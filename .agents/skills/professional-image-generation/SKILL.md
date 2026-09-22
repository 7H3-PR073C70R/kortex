---
name: professional-image-generation
description: Professional image generation and asset creation using Gemini's native generate_image tool. Use for high-quality, photorealistic, or polished graphic assets that avoid generic "AI-generated" looks.
---

# Professional Image Generation

Use this skill whenever you need to generate images, textures, backgrounds, or UI placeholder assets using the built-in `generate_image` tool.

## Best Practices for Professional Assets
1. **Avoid "AI Looks":** AI images often look overly smooth, plasticky, or artificially hyper-detailed. Counteract this by adding terms like `film grain, 35mm photography, natural lighting, subtle imperfections, authentic, editorial`.
2. **Aspect Ratios:** Always consider where the image will be used and specify the `AspectRatio` parameter appropriately (e.g. `16:9` for hero banners, `1:1` for avatars/thumbnails, `9:16` for mobile screens).
3. **UI/Web Design Assets:** When generating UI mockups, icons, or components, explicitly prompt for `flat design, clean vector style, monochromatic, solid background` to make them easier to integrate or trace into real UI components.
4. **Iterative Prompting:** If a generated image looks generic, refine the prompt by specifying camera lenses (e.g., `50mm lens, f/1.8`), specific art mediums (e.g., `screenprint, matte vector`), or lighting styles (e.g., `soft studio lighting, chiaroscuro`).

## Usage
- Trigger this skill when the user asks for illustrations, placeholder photos, backgrounds, or UI assets.
- Use the built-in `generate_image` tool. Do NOT attempt to call external MCP tools for image generation.
