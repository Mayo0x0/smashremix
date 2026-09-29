# Smash Remix — Canonical Current Parent Full Source Tree

**Parent promotion date:** 2026-09-29  
**Current-parent ROM SHA-256:** `9a96131bc01d50020180646caa4e3d93f386e29d4f4c10e8ed563b9d4d628062`

This is the **full master-style Smash Remix source tree** with the owner-tested Battle Royale R4 Random/Results state promoted into the immutable current-parent boundary.

The exact R4 RC1 ROM that was owner tested was promoted **without changing its bytes**. The clean project layer now emits no bytes, so future work starts directly from that tested state.

## Build the current parent

### Windows
Run `patch.bat` or `python build_current_parent.py`.

### Linux x86-64
Run `./patch.sh` or `python3 build_current_parent.py`.

A clean unmodified tree must finish with:

- upstream master build SHA-256 `e04f0e05c3f6888a3f7bea50343953d7e22b4c60b1e4344ba4fe03e59178cf19`;
- canonical parent SHA-256 `9a96131bc01d50020180646caa4e3d93f386e29d4f4c10e8ed563b9d4d628062`;
- `ssb64asm.z64` SHA-256 `9a96131bc01d50020180646caa4e3d93f386e29d4f4c10e8ed563b9d4d628062`;
- **0 differing bytes** between canonical parent, default project build, and packaged current-parent ROM.

## Source layers

- `main_upstream.asm` — preserved upstream-master entrypoint.
- `main_canonical.asm` + `src/CurrentParent/` — frozen exact 2026-09-29 parent. This now includes `src/CurrentParent/BattleRoyale/` for the promoted R4 source.
- `main.asm` + `src/Project/` — clean development entrypoint for all future work.

`src/Project/CurrentProject.asm` intentionally emits no bytes. Future P6, WANTED, Draft King, or other development should be added under `src/Project/` and included there.

See `docs/CurrentParent/SOURCE-TREE-AUTHORITY.md`, `docs/CurrentParent/BUILD-AND-VERIFY.md`, and `docs/CurrentParent/RELEASE-NOTES.md`.

The original upstream readme is preserved as `readme-upstream.md`.
