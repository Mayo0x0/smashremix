// Battle Royale Random / Results fixes — promoted R4 current parent
// Frozen parent-owned source as of 2026-09-29. Future changes belong in src/Project/.
//
// Random contract:
// 1) P1-P4 reuse the current parent's proven BR R3 exact-identity validator
//    at 0x805B0758. That validator is context-aware: it checks live CSS panel
//    selections when ports are being opened/changed, and for '?' Random slots
//    it uses already-resolved Global.vs IDs for earlier ports. This preserves
//    uniqueness both while opening ports and during match-start Random resolve.
// 2) P1-P4 apply the current parent's *native R3 recent-Random history* only
//    after same-match uniqueness succeeds. This gives each native port its
//    existing six-pick bucket, including R3's hard immediate-repeat rejection
//    plus its older-pick probabilistic suppression.
// 3) P5 keeps the owner-proven full-roster/finalized-state duplicate exclusion
//    and gets a private fifth six-pick history bucket implementing the same R3
//    policy. P5 never borrows/pollutes P1's history.
// 4) Late-loaded P5 Remix fighters keep the resource-safe playable-file rebind:
//    ftManagerSetupFilesAllKind(kind), ftManagerSetupFilesPlayablesAll(), then
//    ftManagerAllocAnimHeapKind(kind).
// 5) BR Results Place numerals remain exact 0.70 scale (0x3F333333).
//
// Layout rule:
// - 0x805ADD00.. is owned by ResultsTitleFix and MUST NOT be crossed.
// - P1-P4 helper lives at 0x805ADB00.
// - P5 history lives at 0x805ADE00.
// - P5 selection helper lives at 0x805ADF00.
// This deliberately separates all three blocks so future growth cannot silently
// fall through into the Results title helper.

macro BR_patch_start(origin_value, base_value) {
    pushvar origin, base
    origin {origin_value}
    base {base_value}
}

macro BR_patch_end() {
    pullvar base, origin
}

scope BRRandomResultsFix {

    constant RANDOM_PICKER(0x8052C800)
    constant NATIVE_R3_RECENT_LOOKUP(0x8052CA24)
    constant PICKER_PORT(0x8052CB48)
    constant PARENT_BR_UNIQUE_CHECK(0x805B0758)
    constant GLOBAL_RANDOM_SAFE(0x8040025C)

    constant GLOBAL_VS_P1(0x800A4D28)
    constant GLOBAL_VS_STRIDE(0x74)
    constant MATCH_TYPE_OFF(0x02)
    constant MATCH_CHAR_OFF(0x03)

    constant FT_SETUP_ALL_KIND(0x800D786C)
    constant FT_SETUP_PLAYABLES_ALL(0x800D782C)
    constant FT_ALLOC_ANIM_HEAP_KIND(0x800D78B4)

    // Replace only the inherited BR Random wrapper entry. The current parent's
    // validator at 0x805B0758 remains byte-identical and authoritative.
    BR_patch_start(0x02DB0610, 0x805B0610)
    j       p1_p4_exact_unique_history_
    nop
    BR_patch_end()

    // P5 established entry. The helper itself is moved away from the Results
    // title block so adding history cannot overlap/fall through into 0x805ADD00.
    BR_patch_start(0x02DAD700, 0x805AD700)
    j       p5_full_roster_exact_history_
    nop
    BR_patch_end()

    // P5 dynamic resource setup: preserve the owner-proven repeat-match fix.
    BR_patch_start(0x02DAD780, 0x805AD780)
    addiu   sp, sp, -0x18
    sw      ra, 0x0014(sp)
    sw      a0, 0x0010(sp)
    jal     FT_SETUP_ALL_KIND
    nop
    jal     FT_SETUP_PLAYABLES_ALL
    nop
    lw      a0, 0x0010(sp)
    jal     FT_ALLOC_ANIM_HEAP_KIND
    nop
    lw      ra, 0x0014(sp)
    addiu   sp, sp, 0x18
    jr      ra
    nop
    BR_patch_end()

    // BR Results Place scale, native P1-P4 path.
    BR_patch_start(0x02DAE430, 0x805AE430)
    lui     t8, 0x3F33
    ori     t8, t8, 0x3333
    sw      t8, 0x0018(s2)
    sw      t8, 0x001C(s2)
    BR_patch_end()

    // BR Results Place scale, P5/fifth-row path.
    BR_patch_start(0x02DAE4BC, 0x805AE4BC)
    lui     t8, 0x3F33
    ori     t8, t8, 0x3333
    sw      t8, 0x0018(s2)
    sw      t8, 0x001C(s2)
    BR_patch_end()

    // -----------------------------------------------------------------------
    // P1-P4: exact uniqueness in BOTH panel-open and '?' resolve contexts,
    // followed by the current parent's exact R3 recent-history behavior.
    // -----------------------------------------------------------------------
    BR_patch_start(0x02DADB00, 0x805ADB00)

    p1_p4_exact_unique_history_:
    addiu   sp, sp, -0x20
    sw      ra, 0x001C(sp)
    sw      s0, 0x0018(sp)              // native recent lookup clobbers s0
    sw      s2, 0x0014(sp)
    sw      s3, 0x0010(sp)

    or      s3, s1, r0                  // inherited wrapper contract: port 0..3
    sltiu   t0, s3, 0x0004
    beqz    t0, _p14_fallback           // defensive non-port caller fallback
    nop

    _p14_reroll:
    // Suppress CharacterSelect's internal history pass. We admit history only
    // AFTER the BR exact-identity validator accepts the current-match pick.
    lui     t8, 0x8052
    ori     t8, t8, 0xCB48
    addiu   t9, r0, -1
    sw      t9, 0x0000(t8)

    jal     RANDOM_PICKER
    nop
    or      s2, v0, r0                  // candidate exact fighter ID

    // Reuse the parent's R3 context-aware validator instead of recreating it.
    // It handles live panel selections (port opening) and '?' resolution.
    or      a0, s2, r0
    jal     PARENT_BR_UNIQUE_CHECK
    or      a1, s3, r0
    beqz    v1, _p14_reroll
    nop

    // Same-match uniqueness passed. Run the parent's exact R3 recent history
    // for this port. The current R3 implementation hard-rejects the immediately
    // previous pick and probabilistically suppresses older repeats.
    lui     t8, 0x8052
    ori     t8, t8, 0xCB48
    sw      s3, 0x0000(t8)
    or      v0, s2, r0
    jal     NATIVE_R3_RECENT_LOOKUP
    nop
    beqz    a1, _p14_reroll             // R3 history requested a reroll
    nop

    or      v0, s2, r0
    b       _p14_return
    nop

    _p14_fallback:
    // Preserve normal picker behavior if an unexpected caller violates the
    // inherited port-in-s1 contract. Crucially, do not index any history state.
    jal     RANDOM_PICKER
    nop

    _p14_return:
    lw      s3, 0x0010(sp)
    lw      s2, 0x0014(sp)
    lw      s0, 0x0018(sp)
    lw      ra, 0x001C(sp)
    addiu   sp, sp, 0x20
    jr      ra
    nop

    BR_patch_end()

    // -----------------------------------------------------------------------
    // P5 private R3-style six-pick history.
    // -----------------------------------------------------------------------
    // Exact current-parent R3 policy mirrored here:
    // - immediate previous pick: hard reject;
    // - otherwise insert into current ring slot;
    // - k older occurrences: accept with probability 1/(k+1);
    // - advance ring index only on acceptance.
    BR_patch_start(0x02DADE00, 0x805ADE00)

    p5_recent_randoms_table:
    db -1,-1,-1,-1,-1,-1,0,0
    fill 0x08, 0x00                     // helper begins at 0x805ADE10

    // a0 = candidate exact fighter ID
    // returns v0 = 1 accept / 0 reroll
    p5_history_gate_:
    addiu   sp, sp, -0x18
    sw      ra, 0x0014(sp)
    sw      a0, 0x0010(sp)

    lui     t0, 0x805A
    ori     t0, t0, 0xDE00              // private P5 history bucket
    lbu     t1, 0x0007(t0)              // current ring index 0..5

    // R3 immediate-repeat rule: inspect the previous accepted slot first.
    addiu   t2, t1, -1
    bgez    t2, _p5_hist_prev_ready
    nop
    ori     t2, r0, 0x0005
    _p5_hist_prev_ready:
    addu    t3, t0, t2
    lbu     t4, 0x0000(t3)
    beq     t4, a0, _p5_hist_reject
    nop

    // Pending candidate occupies the current slot, matching native R3.
    addu    t3, t0, t1
    sb      a0, 0x0000(t3)

    ori     t5, r0, 0x0006
    or      t6, r0, r0                  // count matches including pending slot
    _p5_hist_count_loop:
    addiu   t5, t5, -1
    bltz    t5, _p5_hist_count_done
    nop
    addu    t7, t0, t5
    lbu     t7, 0x0000(t7)
    bne     t7, a0, _p5_hist_count_loop
    nop
    addiu   t6, t6, 0x1
    b       _p5_hist_count_loop
    nop

    _p5_hist_count_done:
    addiu   t7, t6, -1                 // older occurrences only
    blez    t7, _p5_hist_accept
    nop

    // Native R3 passes total matches including pending candidate. Therefore
    // one older occurrence -> random(2): 50% acceptance; two -> random(3), etc.
    or      a0, t6, r0
    jal     GLOBAL_RANDOM_SAFE
    nop
    bnez    v0, _p5_hist_reject
    nop

    _p5_hist_accept:
    lui     t0, 0x805A
    ori     t0, t0, 0xDE00
    lbu     t1, 0x0007(t0)
    addiu   t1, t1, 0x1
    sltiu   t2, t1, 0x0006
    bnez    t2, _p5_hist_store_index
    nop
    or      t1, r0, r0
    _p5_hist_store_index:
    sb      t1, 0x0007(t0)
    ori     v0, r0, 0x0001
    b       _p5_hist_return
    nop

    _p5_hist_reject:
    or      v0, r0, r0

    _p5_hist_return:
    lw      ra, 0x0014(sp)
    addiu   sp, sp, 0x18
    jr      ra
    nop

    BR_patch_end()

    // -----------------------------------------------------------------------
    // P5 full Remix roster + exact current-match exclusion + fifth history.
    // -----------------------------------------------------------------------
    BR_patch_start(0x02DADF00, 0x805ADF00)

    p5_full_roster_exact_history_:
    addiu   sp, sp, -0x20
    sw      ra, 0x001C(sp)
    sw      s0, 0x0018(sp)
    sw      s1, 0x0014(sp)

    lui     t8, 0x8052
    ori     t8, t8, 0xCB48
    lw      t9, 0x0000(t8)
    sw      t9, 0x0010(sp)              // preserve caller picker-port state
    addiu   t9, r0, -1
    sw      t9, 0x0000(t8)              // P5 must not use P1 native history

    _p5_reroll:
    or      s1, r0, r0                  // owner-proven P1 picker base context
    jal     RANDOM_PICKER
    nop
    or      s0, v0, r0                  // candidate exact fighter ID

    // Owner-tested P5 exclusion source: finalized match-state P1-P4 entries.
    lui     s1, 0x800A
    ori     s1, s1, 0x4D28
    or      t0, r0, r0

    _p5_check_loop:
    lbu     t1, MATCH_TYPE_OFF(s1)
    ori     t2, r0, 0x0002
    beq     t1, t2, _p5_next
    nop
    lbu     t3, MATCH_CHAR_OFF(s1)
    beq     t3, s0, _p5_reroll
    nop

    _p5_next:
    addiu   s1, s1, GLOBAL_VS_STRIDE
    addiu   t0, t0, 0x1
    sltiu   t1, t0, 0x0004
    bnez    t1, _p5_check_loop
    nop

    // Current-match uniqueness passed; now apply P5's private R3-style history.
    jal     p5_history_gate_
    or      a0, s0, r0
    beqz    v0, _p5_reroll
    nop

    sw      s0, 0x0040(sp)              // caller sp+0x20: descriptor kind

    lui     t8, 0x8052
    ori     t8, t8, 0xCB48
    lw      t9, 0x0010(sp)
    sw      t9, 0x0000(t8)              // restore caller picker-port state

    // Preserve the successful candidate in v0 as the pre-history helper did.
    or      v0, s0, r0
    lw      s1, 0x0014(sp)
    lw      s0, 0x0018(sp)
    lw      ra, 0x001C(sp)
    addiu   sp, sp, 0x20
    jr      ra
    nop

    BR_patch_end()
}
