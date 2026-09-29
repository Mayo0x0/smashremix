// main.asm
// DEFAULT CURRENT-PARENT DEVELOPMENT ENTRYPOINT.
// build_current_parent.py first reproduces the clean upstream source build,
// then the immutable canonical current parent, then assembles this layer.
// Add all future work through src/Project/CurrentProject.asm.
arch    n64.cpu
endian  msb
include "assembler/N64.inc"
origin  0x0
insert  "build/canonical-parent.z64"
include "src/Project/CurrentProject.asm"
