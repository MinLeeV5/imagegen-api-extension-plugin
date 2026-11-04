# Image API parameters

This reference describes the API CLI, which is the default execution path for this installation. API flags are not built-in `image_gen` arguments.

## Model support

| Model | Quality | Size | Transparency |
| --- | --- | --- | --- |
| `gpt-image-2.5-flare` (default; alias `flare`) | `low`, `medium`, `high`, `xhigh`, `max`, `auto` | `auto` or constrained custom dimensions | Native PNG/WebP |
| `gpt-image-2.5-sunburst` (alias `sunburst`) | `low`, `medium`, `high`, `xhigh`, `max`, `auto` | `auto` or constrained custom dimensions | Native PNG/WebP |
| `gpt-image-2` (explicit compatibility choice) | `low`, `medium`, `high`, `auto` | `auto` or constrained custom dimensions | The CLI rejects `background=transparent` |
| `gpt-image-1.5`, `gpt-image-1`, `gpt-image-1-mini` (explicit compatibility choices) | `low`, `medium`, `high`, `auto` | `1024x1024`, `1536x1024`, `1024x1536`, `auto` | PNG/WebP |

Defaults are Flare, `size=auto`, `quality=medium`, PNG. Preserve a model or quality explicitly chosen by the user. Do not switch models on an error.

## Custom dimensions

The 2.5 models and the CLI's `gpt-image-2` compatibility path accept `WIDTHxHEIGHT` when:

- Both edges are multiples of 16.
- Neither edge exceeds 3840 pixels.
- The long-to-short aspect ratio is at most 3:1.
- The pixel count is between 655,360 and 8,294,400.

Examples: `1024x1024`, `1536x1024`, `1024x1536`, `2048x2048`, `2048x1152`, `3840x2160`, `2160x3840`. For the 2.5 models, resolutions above `2560x1440` are experimental in the public API documentation. Accepted request parameters do not establish the dimensions actually returned; inspect the image when exact pixels matter. Preserve returned bytes and report a mismatch instead of silently upscaling.

## Requests

- Generation: `client.images.generate(...)`, `POST /v1/images/generations`.
- Editing or reference-guided generation: `client.images.edit(...)`, `POST /v1/images/edits`.
- `model`, `prompt`, `n` (1–10), `size`, and `quality` are shared controls.
- `background`: `transparent`, `opaque`, or `auto`.
- `output_format`: `png`, `jpeg` (`jpg` alias), or `webp`.
- `output_compression`: 0–100, JPEG/WebP only.
- `moderation`: `auto` or `low` where supported.
- Edits take `image` files and an optional `mask`; keep masks aligned with the first image and preserve the intended invariants in the prompt.
- `input_fidelity=low|high` is edit-only for models that accept it. `gpt-image-2` always uses high input fidelity and the CLI rejects this option for that model. Do not add it by default to 2.5 requests.

Transparent output requires PNG or WebP. With Flare or Sunburst, request native alpha directly; do not switch to an older model to obtain transparency. Inspect alpha when transparency is an acceptance criterion.

The CLI decodes `data[].b64_json` and saves the original image bytes. It creates an additional smaller copy only when `--downscale-max-dim` is requested.

## Authentication and endpoint

Use `OPENAI_API_KEY`, or `OPENAI_KEY` when the canonical variable is absent or empty. A configured key is used for the user's image request without repeated confirmation. Never expose the key or copy it into command arguments, prompt files, or skill files. The OpenAI SDK honors `OPENAI_BASE_URL`; otherwise it uses its standard platform endpoint.

Use current official documentation for API behavior beyond this reference: https://developers.openai.com/api/docs/guides/image-generation
