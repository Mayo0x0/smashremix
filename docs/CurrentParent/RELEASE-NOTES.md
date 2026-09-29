# 2026-09-29 Canonical Current Parent — Battle Royale R4 Promotion

This package promotes the owner-tested R4 Random/Results RC1 state into the canonical parent boundary.

## Promotion invariants

- Promoted ROM SHA-256: `9a96131bc01d50020180646caa4e3d93f386e29d4f4c10e8ed563b9d4d628062`.
- The promoted ROM is byte-for-byte identical to the R4 RC1 owner-test ROM.
- R4 source moved from `src/Project/BattleRoyale/` into `src/CurrentParent/BattleRoyale/`.
- `src/Project/CurrentProject.asm` is reset to an intentional zero-byte development layer.
- The original/native R3 Random implementation remains part of the inherited parent and is not globally replaced by BR logic.
- P5 history remains BR-private.
- Full source/assets/tools remain present in the master-style tree.

Future work should branch from this package, not from the superseded 2026-09-28 parent plus R4 overlay.
