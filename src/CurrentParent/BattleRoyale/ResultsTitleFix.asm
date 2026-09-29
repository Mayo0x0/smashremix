// Battle Royale Results / No Contest title - CSS lettering at native Results position
// Frozen parent-owned source as of 2026-09-29. Future changes belong in src/Project/.
//
// The reconstructed parent already has the established "Battle Royale" CSS title
// payload at ROM 0x02E01000. Native VS Results / No Contest creates its own
// title SObj and normally shows "Free-for-all". This BR-only hook replaces
// that Results title image with the proven CSS "Battle Royale" image.
//
// IMPORTANT positioning detail:
// Native Results loads f4 = 32.0 before the hook, then later stores f4 to
// title SObj +0x58 as the native title X position. The image-swap helper calls
// malloc/ROM-copy routines, which are allowed to clobber caller-saved FPU
// registers. The first CSS-title attempt did not restore f4, so the title was
// drawn on the right side. This version explicitly restores f4 = 32.0 before
// returning. Native code then stores X=32.0 and Y=29.0 exactly as before.

macro BR_title_patch_start(origin_value, base_value) {
    pushvar origin, base
    origin {origin_value}
    base {base_value}
}

macro BR_title_patch_end() {
    pullvar base, origin
}

scope BRResultsTitleFix {

    constant BR_FLAG(0x805B1B00)
    constant MALLOC(0x80004980)
    constant ROM_COPY(0x80002CA0)
    constant TITLE_PAYLOAD_ROM(0x02E01000)
    constant TITLE_PAYLOAD_SIZE(0x0780)

    // Native Results header setup:
    //   801367C4  lui   at,0x4200       // 32.0
    //   801367C8  mtc1  at,f4           // native title X
    //   801367CC  lw    t6,0x0074(v0)  // title SObj
    //   801367D0  lui   at,0x41E8       // 29.0
    //   801367D4  mtc1  at,f6           // native title Y
    //   801367D8  swc1  f4,0x0058(t6)  // X = 32.0
    //   801367E4  swc1  f6,0x005C(t7)  // Y = 29.0
    //
    // Replace only the SObj load with a call. The original 0x41E8 load remains
    // in the JAL delay slot. The helper reloads t6 and restores BOTH the native
    // f4=32.0 X value and at=0x41E8 before returning.
    BR_title_patch_start(0x0015596C, 0x801367CC)
    jal     apply_battle_royale_title_
    lui     at, 0x41E8
    BR_title_patch_end()

    // Continue in project-owned free space immediately after RandomResultsFix.
    BR_title_patch_start(0x02DADD00, 0x805ADD00)

    apply_battle_royale_title_:
    addiu   sp, sp, -0x20
    sw      ra, 0x001C(sp)
    sw      v0, 0x0018(sp)              // preserve Results title GObj

    lw      t6, 0x0074(v0)              // reproduce overwritten original line
    sw      t6, 0x0014(sp)              // preserve title SObj across calls

    lui     t0, 0x805B
    lw      t0, 0x1B00(t0)              // BR flag
    beqz    t0, _finish                 // non-BR: no visual change
    nop

    beqz    t6, _finish                 // defensive: no title SObj
    nop

    // Reuse the exact established Battle Royale CSS title payload.
    ori     a0, r0, TITLE_PAYLOAD_SIZE
    jal     MALLOC
    ori     a1, r0, 0x0010              // 16-byte alignment

    beqz    v0, _finish                 // defensive allocation guard
    nop

    sw      v0, 0x0010(sp)              // copied payload base
    lui     a0, 0x02E0
    ori     a0, a0, 0x1000              // ROM 0x02E01000
    or      a1, v0, r0
    jal     ROM_COPY
    ori     a2, r0, TITLE_PAYLOAD_SIZE

    // Same payload fixups used by the established CSS helper at 0x805B1EAC.
    lw      t0, 0x0010(sp)              // payload base
    sw      t0, 0x0738(t0)              // self/base pointer fixup
    lw      t1, 0x0744(t0)
    lw      t6, 0x0014(sp)              // Results title SObj
    sw      t1, 0x0014(t6)
    addiu   t1, t0, 0x0730
    sw      t1, 0x0044(t6)

    _finish:
    lw      t6, 0x0014(sp)              // preserve original caller state
    lw      v0, 0x0018(sp)
    lw      ra, 0x001C(sp)

    // CRITICAL: malloc/ROM_COPY may clobber f4. Restore the native Results
    // title X value before the original swc1 at 0x801367D8 executes.
    lui     at, 0x4200                  // 32.0f
    mtc1    at, f4
    lui     at, 0x41E8                  // required by original 801367D4
    jr      ra
    addiu   sp, sp, 0x20

    BR_title_patch_end()
}
