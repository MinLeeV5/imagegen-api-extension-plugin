# Image API CLI

Use `scripts/image_gen.py` for requested image work. API mode is the default for this installation. If `OPENAI_API_KEY` or `OPENAI_KEY` is already configured, proceed without another key-use or API-mode confirmation. `OPENAI_API_KEY` takes precedence when both are set; `OPENAI_BASE_URL` is honored.

## Defaults

- Model: `gpt-image-2.5-flare`.
- Alternative: `--model gpt-image-2.5-sunburst`, or the alias `--model sunburst`.
- Size: `auto`; quality: `medium`; output: PNG.
- Default output: `output/imagegen/output.png`; pass an explicit workspace-appropriate path when needed.
- No automatic model substitution or switch to subscription generation on failure.

Use the installed skill directory shown when this skill is loaded; set `IMAGE_GEN` to its `scripts/image_gen.py` file. For example, from this package root:

```bash
IMAGE_GEN="$(pwd)/plugins/imagegen-api/skills/imagegen-api/scripts/image_gen.py"
```

Prefer `uv run --script "$IMAGE_GEN" ...`; the script declares its Python dependencies. If uv is unavailable, create a workspace virtual environment and install the package requirements, then use that Python. `python3 "$IMAGE_GEN" ... --dry-run` needs neither the SDK nor a key and sends no request. Do not create a separate runner.

## Generate

Default Flare:

```bash
uv run --script "$IMAGE_GEN" generate \
  --prompt "A small yellow duck in soft daylight" \
  --out output/imagegen/duck.png
```

Sunburst with explicit controls:

```bash
uv run --script "$IMAGE_GEN" generate \
  --model sunburst \
  --prompt "A small yellow duck in soft daylight" \
  --size 1536x1024 --quality xhigh \
  --out output/imagegen/duck-sunburst.png
```

Append `--dry-run` to inspect the normalized model, parameters, and output paths without generating an image. Dry-run output includes prompt text but no API key.

## Edit and reference images

Use the edits endpoint for an existing image or image-guided generation. Describe what each image supplies and what must remain unchanged.

```bash
uv run --script "$IMAGE_GEN" edit \
  --model sunburst \
  --image input.png \
  --prompt "Change only the background to warm sunset light; preserve the duck and its outline" \
  --out output/imagegen/duck-edited.png
```

- Repeat `--image` for multiple inputs; their order matters.
- `--mask` takes a PNG with alpha and applies to the first image. Match the target image dimensions and format. Masking is prompt-guided.
- `--input-fidelity low|high` is edit-only. Do not pass it with `gpt-image-2`; use only where the selected model supports it.
- Native transparency on either 2.5 model: `--background transparent --output-format png` (or `webp`). No older-model fallback is needed.

## Distinct prompts and variants

Use `--n` for variants of one prompt. For distinct assets, create one JSONL job per prompt:

```jsonl
{"prompt":"A yellow duck in soft daylight","model":"flare","out":"duck.png"}
{"prompt":"A ceramic mug on a stone surface","model":"sunburst","quality":"max","out":"mug.png"}
```

```bash
uv run --script "$IMAGE_GEN" generate-batch \
  --input work/imagegen/jobs.jsonl \
  --out-dir output/imagegen/batch \
  --concurrency 2
```

Per-job overrides include `model`, `size`, `quality`, `n`, `background`, `output_format`, `output_compression`, `moderation`, `out`, and prompt fields. Short model aliases work in batch jobs too. In batch mode, `out` is a filename beneath `--out-dir`. The default concurrency is 5 and maximum attempts is 3; keep runs proportionate to the user's request.

## Other controls

- `--prompt-file`: read a UTF-8 prompt instead of `--prompt`.
- `--no-augment`: send prompt text without labeled scaffolding. Structured prompt hints such as `--style`, `--composition`, and `--constraints` remain available when augmentation is enabled.
- `--output-compression`: 0–100, for JPEG/WebP.
- `--force`: overwrite an existing output only when replacement is authorized.
- `--downscale-max-dim`: optional additional smaller copy; the original is preserved. The CLI does not upscale.
- `--max-attempts` and `--fail-fast`: batch retry controls.

For the full command surface, run `uv run --script "$IMAGE_GEN" generate --help` (or `edit --help` / `generate-batch --help`). See [image-api.md](image-api.md) for model-specific validation and [setup.md](setup.md) for setup failures.
