# Runtime setup

Use an absolute script path derived from this skill's installed directory. Do not rely on a system imagegen skill or a particular user's cache location.

## Dependencies

Preferred: `uv run --script <skill-directory>/scripts/image_gen.py <command> ...`. The script declares Python >=3.10, OpenAI SDK >=3.42.1,<4, and Pillow >=13,<14 through inline metadata; uv maintains its own environment.

Without uv, create a virtual environment in the user's workspace and install the package's `requirements.txt`, or install those two dependency ranges into an existing project environment. Do not write a virtual environment into the installed plugin cache. For parameter previews, `python3 <script> ... --dry-run` uses only the standard library.

## Credentials and endpoint

- Prefer `OPENAI_API_KEY`; otherwise accept `OPENAI_KEY`.
- Use a nonempty configured key for the user's image request without asking again whether to use it. Never print it or place it in prompts, files, or command arguments.
- If missing, ask the user to set it locally in the environment inherited by Codex. This plugin does not automatically load `.env` files.
- Honor `OPENAI_BASE_URL` if configured; otherwise use the SDK's platform default. The package contains no personal endpoint.
- Existing runtime permissions still apply. Explain an actual environment blocker if one occurs; do not add routine API-key reconfirmation.
- Authentication, quota, model-access, or parameter errors do not authorize switching models or endpoints. Keep the user's choices and report the error.
