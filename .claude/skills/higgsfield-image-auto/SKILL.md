---
name: higgsfield-image-auto
description: Automatically generate an AI image on Higgsfield using Playwright browser automation. Use when the user has an image prompt and wants to generate it on Higgsfield Soul 2.0 or Nano Banana Pro. Triggers on requests like "generate image on higgsfield", "create image", "auto-generate image", "make the image on higgsfield", or any request to submit an image generation job. Requires Playwright MCP tools.
---

# Higgsfield Image Auto-Generate via Playwright

This skill automates the full Higgsfield image generation flow using Playwright browser automation. It navigates to the image generation page, enters a prompt, configures settings, and clicks Generate — hands-free.

---

## Prerequisites

- User must be **logged in** to higgsfield.ai in the Playwright browser session
- **Playwright MCP** plugin must be enabled
- Load each Playwright tool with `ToolSearch` before first use

## Input Requirements

The user provides:
1. **A text prompt** for the image (or invoke `/ugc-hot-girl` first to generate one)

Optional overrides (defaults shown):
- **Model**: `Soul 2.0` (options: Soul 2.0, Soul Cinema, Nano Banana Pro, Nano Banana 2, Seedream 5.0 lite, GPT Image 1.5, Grok Imagine, FLUX.2, Reve, Z-Image)
- **Aspect Ratio**: `3:4` (options: 1:1, 3:4, 4:3, 9:16, 16:9, 2:3, 3:2)
- **Resolution**: `2k` (options: 1k, 2k, 4k)
- **Image Count**: `1` (options: 1-4)

---

## Model URL Map

Each model is loaded via `?model=<slug>` on `/ai/image`:

| Model | URL |
|---|---|
| Soul 2.0 | `/ai/image?model=soul-v2` |
| Soul Cinema | `/ai/image?model=soul-cinematic` |
| Nano Banana Pro | `/ai/image?model=nano-banana-pro` |
| Nano Banana 2 | `/ai/image?model=nano-banana-2` |
| Seedream 5.0 lite | `/ai/image?model=seedream_v5_lite` |
| GPT Image 1.5 | `/ai/image?model=openai_hazel` |
| Grok Imagine | `/ai/image?model=grok_image` |
| FLUX.2 | `/ai/image?model=flux_2` |
| Reve | `/ai/image?model=reve` |
| Z-Image | `/ai/image?model=z-image` |

**Default**: Soul 2.0 (`/ai/image?model=soul-v2`) — best for photorealistic portraits and UGC characters.

> **Stale URL gotcha (verified 2026-04-22):** the old `/image/<slug>` pattern in Higgsfield's nav redirects to the marketing landing page (`/ai-image`) regardless of login state. Always use `/ai/image?model=<slug>` — that's what the site itself navigates to once you're inside the tool.

---

## Automation Flow

### Step 1: Navigate to the image generation page

```
browser_navigate → url: "https://higgsfield.ai/image/soul-v2"
```

Replace `soul-v2` with the appropriate model path from the table above if the user requests a different model.

Wait for the page to load, then take a snapshot to confirm:
- The page title contains the model name
- The prompt textbox is visible

### Step 2: Find and click the prompt textbox

Take a snapshot. Look for:
```
textbox [ref=eXX]
```
It's inside `group [ref=eXX]` at the bottom of the page. The placeholder text is "Describe the scene you imagine".

The textbox has a Playwright ID: `[id="hf:tour-image-prompt"]` — Playwright may use this selector automatically.

```
browser_click → ref: <textbox_ref>, element: "Image prompt textbox"
```

### Step 3: Type the prompt

```
browser_type → ref: <textbox_ref>, text: "<the image prompt>"
```

**Important**: Use the `fill` method (default), NOT `slowly: true`. The textbox is a standard input, not a Lexical editor.

### Step 4: Adjust settings (optional)

If the user wants non-default settings, click the corresponding buttons:

**Aspect Ratio** — Find the button showing current ratio (e.g., "3:4"):
```
browser_click → ref: <ratio_button_ref>, element: "Aspect ratio selector"
```
Then select from the dropdown options.

**Resolution** — Find the button showing current resolution (e.g., "2k"):
```
browser_click → ref: <resolution_button_ref>, element: "Resolution selector"
```

**Image Count** — Find the increment/decrement buttons (shows "1/4"):
- Click the "Increment" button to increase count (max 4)
- Click the "Decrement" button to decrease

**Character/Moodboard** — The right side panel shows "CHARACTER" with a "General" moodboard. Click "Change" to switch.

### Step 5: Generate

Take a screenshot to show the user the form state.

**ASK THE USER FOR CONFIRMATION** before clicking Generate — this uses credits/free generations.

Find and click the Generate button:
```
browser_click → ref: <generate_button_ref>, element: "Generate button"
```

The Generate button shows remaining free generations (e.g., "Generate 4915 free gens left").

### Step 6: Wait for generation

```
browser_wait_for → time: 15   # Soul 2.0
browser_wait_for → time: 40   # Nano Banana Pro
```

Soul 2.0 finishes in 10-20 s. **Nano Banana Pro is slower** — wait 30-45 s; at 20 s it's still showing the "Generating" badge in the top-left of the History grid.

### Step 7: Verify the result

Take a screenshot. The newly generated image appears as the **first item** in the History grid at the top of the page.

To view the full image, click on the first grid item. This opens an "Asset showcase" dialog with:
- Full-size image preview
- Prompt details
- Action buttons: Overview, Upscale, Enhancer, Relight, Inpaint, Angles
- Bottom actions: Animate, Publish, Open in, Reference, Download

### Step 7b: Downloading the result (when the UI dialog is flaky)

The Asset Showcase dialog's "Download" button sometimes closes before a second
click lands. Robust fallback: grab the CDN URL directly from the DOM and fetch
via `curl`, bypassing the UI entirely.

```js
// browser_evaluate
() => {
  const all = Array.from(document.querySelectorAll('img'));
  const mine = all
    .filter(i => i.alt === 'image generation' && i.getBoundingClientRect().y < 500)
    .map(i => i.src);
  return mine[0];
}
```

The returned URL is the Higgsfield image-proxy with `_min.webp` in the query
string. To get the full-resolution original:

1. Decode the `url=` query parameter — it points at the CloudFront asset,
   e.g. `https://d8j0ntlcm91z4.cloudfront.net/user_XXX/hf_YYYYMMDD_*.webp`.
2. Strip the `_min` suffix and swap `.webp` for `.png`. The full PNG is
   publicly fetchable with `curl -sSL` (no auth headers needed).
3. If `.png` 404s, try the original `.webp` URL without `_min`.

The full PNG matches the generated resolution (e.g. 2048×2048 at 2K). For iOS
icon use, post-process with `Pillow` to resize to 1024×1024 and strip alpha
— `sips` on macOS cannot flatten alpha in a single step:

```sh
python3 -c "from PIL import Image; \
  Image.open('in.png').convert('RGB').resize((1024,1024), Image.LANCZOS).save('out.png', 'PNG')"
sips -g hasAlpha -g space out.png   # verify hasAlpha:no, space:RGB
```

### Step 8: Report to user

Tell the user the image was generated successfully. If this is part of the UGC pipeline, remind them they can now use `/seedance-auto-generate` to create a video from this image.

---

## Key Element Patterns

These patterns help navigate the page. Refs change between sessions — always take a fresh snapshot.

| Element | How to find it |
|---|---|
| Prompt textbox | `textbox` with Playwright ID `hf:tour-image-prompt` |
| Model selector | `button` inside `group` containing model name (e.g., "Soul 2.0") |
| Aspect ratio | `button` showing ratio text (e.g., "3:4") with dropdown arrow |
| Resolution | `button` showing resolution (e.g., "2k") with dropdown arrow |
| Image count | `button "Decrement/Increment"` with counter showing "X/4" |
| Color Transfer | `button "Color Transfer New"` |
| Character panel | `complementary` section on the right with "CHARACTER" label |
| Generate button | `button "Generate ..."` with free gen count |
| History grid | `generic` container with multiple `img "image generation"` children |
| First generated image | First `generic` child inside the History grid container |

---

## Error Handling

- **Not logged in**: If the page shows a login prompt, ask user to log in (`! open https://higgsfield.ai`)
- **Prompt textbox not found**: The input bar occasionally doesn't render. Refresh the page and retry.
- **Model not available**: Some models require a subscription. Check for upgrade prompts.
- **Generation failed**: The image will show "Failed" status in the grid. Suggest retrying or simplifying the prompt.

---

## Pipeline Integration

This skill is step 2 of the UGC pipeline:

1. **`/ugc-hot-girl`** — Generates the character image prompt
2. **`/higgsfield-image-auto`** ← You are here — automates image generation on Higgsfield
3. **`/seedance-auto-generate`** — Takes the generated image to Seedance 2.0 video page

### How the image flows to video

After generating an image here, it's automatically available in the Seedance 2.0 video creation page:

1. Navigate to `/create/video?model=seedance_2_0`
2. Click the upload area → opens media dialog
3. Click **"Image Generations"** tab
4. The most recently generated image appears as the **first item**
5. Click it to select (it changes from "Check eligibility" button to a selected state with green checkmark)
6. Press Escape to close dialog — the image is now loaded into the video form
