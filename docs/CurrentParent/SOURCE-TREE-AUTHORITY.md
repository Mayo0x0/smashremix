# Current Parent Source-Tree Authority

## Current parent

The canonical development parent is the owner-tested Battle Royale R4 state promoted on 2026-09-29.

`release/SMASH-REMIX-CURRENT-PARENT-2026-09-29.z64`

SHA-256:

`9a96131bc01d50020180646caa4e3d93f386e29d4f4c10e8ed563b9d4d628062`

This is byte-for-byte the R4 RC1 ROM used for owner runtime testing; promotion changed source ownership and packaging, not ROM behavior or bytes.

## Full-tree lineage

The complete source/assets/tool tree began from the user's Library `smashremix-master.zip`. Its preserved upstream entrypoint is `main_upstream.asm`, which builds SHA-256:

`e04f0e05c3f6888a3f7bea50343953d7e22b4c60b1e4344ba4fe03e59178cf19`

The 2026-09-28 accepted parent was reconstructed exactly under `src/CurrentParent/CanonicalParentOverlay.asm` plus its segment files. R4 was then developed in the project layer and owner tested. On promotion, the R4 high-level modules were moved into `src/CurrentParent/BattleRoyale/` and included by `main_canonical.asm` after the historical base overlay.

## Development rule

Future work belongs in `src/Project/`.

Build sequence:

1. `main_upstream.asm` -> exact clean upstream ROM.
2. `main_canonical.asm` + `src/CurrentParent/` -> exact owner-tested 2026-09-29 parent.
3. `main.asm` + `src/Project/CurrentProject.asm` -> current development ROM.

The clean project layer must produce zero differing bytes from the canonical parent. `build_current_parent.py` enforces this unless `--allow-project-diff` is explicitly used during future development.
