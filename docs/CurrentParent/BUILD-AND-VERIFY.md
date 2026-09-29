# Build and Verify

## Default build

Windows: `patch.bat` or `python build_current_parent.py`

Linux x86-64: `./patch.sh` or `python3 build_current_parent.py`

The final ROM is written to `ssb64asm.z64`.

## Expected clean hashes

Clean upstream master build:

`e04f0e05c3f6888a3f7bea50343953d7e22b4c60b1e4344ba4fe03e59178cf19`

Canonical/default-project/current release:

`9a96131bc01d50020180646caa4e3d93f386e29d4f4c10e8ed563b9d4d628062`

A clean build must report zero canonical-vs-project and canonical-vs-release differing bytes.

## Future development

After adding intentional source under `src/Project/`, use:

`python build_current_parent.py --allow-project-diff`

The canonical build remains pinned to the frozen 2026-09-29 parent while the project output may differ. Do not use `--allow-project-diff` to excuse canonical drift.
