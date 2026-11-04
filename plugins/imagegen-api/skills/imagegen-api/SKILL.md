---
name: imagegen-api
description: Generate or edit raster images through an API key with Flare or Sunburst. Use for ordinary image requests, photos, illustrations, image references, transparent cutouts, and batches. When the user has chosen API image generation as their default, prefer this plugin over the bundled imagegen skill even without an explicit API mention. Prefer existing SVG/vector/code assets for deterministic graphics.
---

# Imagegen API

Generate and edit images using this plugin's packaged `scripts/image_gen.py`. This plugin is self-contained and does not modify or depend on the bundled system imagegen skill.

## Skill selection

- When the user has chosen this plugin as their default image workflow, use it for ordinary generation and editing before the bundled imagegen skill. An ordinary image request does not need to repeat the words API, Flare, or Sunburst.
- An explicit request for built-in or subscription image generation takes precedence; use the bundled workflow for that request.
- Keep the bundled skill intact. Installation or generation alone does not authorize changing the user's global instructions; a persistent default preference requires the user's request to set it.

## Defaults and key use

- API mode is the default for this plugin. Default model: `gpt-image-2.5-flare`; use `gpt-image-2.5-sunburst` when requested. Short model names `flare` and `sunburst` are accepted by the CLI.
- For requested image work, use an existing `OPENAI_API_KEY`, or `OPENAI_KEY` if the canonical variable is absent/empty. Do not ask the user to reconfirm API mode, key use, or API billing for the same request. Never show or copy the key.
- Honor `OPENAI_BASE_URL`; do not substitute a different endpoint.
- If no key exists, ask the user to set one locally, never to paste it in chat.
- This behavior applies to image work the user requested. Installation, inspection, or testing alone is not a request to generate images.
- Preserve explicit model and parameter choices. A failure is not permission to substitute another model or the subscription image tool. An explicit user request to use a different workflow takes precedence.
- Defaults: `size=auto`, `quality=medium`, PNG. Flare and Sunburst support `xhigh` and `max` as well as ordinary quality levels. Do not infer maximum quality or resolution from a model choice.

## Run the packaged CLI

Resolve `scripts/image_gen.py` relative to this skill's directory. Prefer `uv run --script <absolute-script-path> ...`, which uses the script's declared dependencies. If uv is unavailable, use a project Python environment with the dependencies described in [references/setup.md](references/setup.md). Do not hardcode an installation path or write one-off SDK runners.

- Text-only image: `generate`.
- Edit or reference-guided generation: `edit`, with repeated `--image` flags for multiple inputs. State each image's role and what must remain unchanged.
- Distinct prompts/assets: `generate-batch` with one JSONL job per prompt.
- Variants of one prompt: `--n`.
- Parameter preview without API use: `--dry-run`.

Commands and examples: [references/cli.md](references/cli.md). Model-specific validation: [references/image-api.md](references/image-api.md).

## Prompt and output workflow

1. Identify the user's subject, purpose, input images, requested model, and output requirements. Ask only about missing details that block the task, not repeated API-key confirmation.
2. Preserve a detailed prompt's specificity; for a generic prompt, add only useful framing, lighting, and style details. Keep exact image text verbatim. Label each input as a reference, edit target, or supporting insert.
3. For edits, state `change only X; keep Y unchanged`. See [references/prompting.md](references/prompting.md) and [references/sample-prompts.md](references/sample-prompts.md) for prompt guidance.
4. Run the packaged CLI. Pass explicit output paths appropriate to the current workspace. Save all requested batch deliverables, and avoid overwriting existing files unless replacement is authorized.
5. Inspect the image for subject, text, invariants, and relevant output requirements. Preserve original returned bytes. If exact dimensions matter, inspect actual pixels and report any mismatch; do not silently upscale. On transparent requests, use native `background=transparent` with PNG/WebP on either 2.5 model and inspect alpha.
6. Show the final image and absolute output path. Report the requested model and relevant observed properties without claiming an independently verified backend model identity when the response does not establish it.

Use the workspace's scratch area for prompt files and JSONL manifests. The CLI defaults to `output/imagegen/`; pass `--out` or `--out-dir` when the workspace uses another convention.
