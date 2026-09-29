// main_canonical.asm
// Immutable reconstruction of the exact owner-tested 2026-09-29 current parent.
// The 2026-09-28 reconstructed base overlay is followed by the promoted,
// owner-tested Battle Royale R4 source. Do not add new features here.
// Add future work under src/Project/.
arch    n64.cpu
endian  msb
include "assembler/N64.inc"
origin  0x0
insert  "build/upstream-master.z64"
include "src/CurrentParent/CanonicalParentOverlay.asm"
include "src/CurrentParent/BattleRoyale/RandomResultsFix.asm"
include "src/CurrentParent/BattleRoyale/ResultsTitleFix.asm"
