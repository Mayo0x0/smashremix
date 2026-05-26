// ComboPressure.asm
if !{defined __COMBO_PRESSURE__} {
define __COMBO_PRESSURE__()
print "included ComboPressure.asm\n"

// @ Description
// Combo Pressure — a "use it or lose it" damage rule.
//
// When enabled, a player whose accumulated damage has not changed for the
// configured Pressure Window (5/10/15/20/30 seconds) has their damage
// instantly snapped back to 0 %. The intended effect is to keep matches
// aggressive: as long as you're chaining hits, your opponent's percent
// stays parked. The moment you let them breathe for too long, all the
// pain you inflicted evaporates.
//
// Toggles (defined in Toggles.asm):
//   entry_combo_pressure   — master on/off (default OFF)
//   entry_pressure_window  — 0..4 ⇒ 5/10/15/20/30 seconds (default 1 = 10s)
//
// Scope rules: only fires during an active VS match, skipped in Stamina
// mode (resetting HP would effectively revive the player).
//
// Hook design: piggy-backs on Poison.poison_hook, which the engine
// already calls once per player per frame as part of the heal/damage
// pipeline. apply_pressure_tick_ is invoked from there with a2 holding
// the player struct — same calling convention as the surrounding poison
// code, so no new GObj routine is needed.

scope ComboPressure {

    // @ Description
    // Per-port elapsed-time stamp of the most recent damage increase.
    // Updated whenever player.0x002C grows between frames. Used to
    // compute "seconds since last hit" for the reset gate.
    // Reset to 0 at match start (clear_state_).
    OS.align(4)
    last_damage_frame:
    dw 0, 0, 0, 0

    // @ Description
    // Per-port snapshot of player.0x002C as of the previous frame.
    // The damage-increase edge is detected by current > previous_damage[port].
    // Reset to 0 at match start (clear_state_).
    OS.align(4)
    previous_damage:
    dw 0, 0, 0, 0

    // @ Description
    // Per-port live timer value, split into tens and ones digits so the
    // overlay can render a fixed "NN" two-digit countdown (with a leading
    // zero on values < 10, e.g. 06). Render.draw_number has no zero-pad
    // mode of its own, but it does happily render a single-digit value
    // with no padding, so the trick is just two adjacent draw_number
    // objects bound to these tables.
    //
    // Updated every frame from apply_pressure_tick_ and read by the on-
    // screen overlay via Render.update_live_string_ — keeping the renderer
    // pull-driven means we don't have to invalidate textures or rewrite
    // the display list when the value changes.
    //
    // Invariants maintained by apply_pressure_tick_:
    //   • 0 ≤ display_tens[port]  ≤ 3  (max threshold is 30 s)
    //   • 0 ≤ display_ones[port]  ≤ 9
    OS.align(4)
    display_tens:
    dw 0, 0, 0, 0
    display_ones:
    dw 0, 0, 0, 0

    // @ Description
    // Pressure Window value (toggle index 0..4) → threshold in *seconds*.
    // Lets the overlay show "10 → 9 → 8 → … → 0" without recomputing the
    // division off the frames table every visible-frame.
    OS.align(4)
    threshold_seconds_table:
    dw 5            // index 0
    dw 10           // index 1 (default)
    dw 15           // index 2
    dw 20           // index 3
    dw 30           // index 4

    // @ Description
    // Pressure Window value (toggle index 0..4) → threshold in frames.
    // 5 / 10 / 15 / 20 / 30 seconds × 60 fps. The lookup keeps the toggle
    // labels independent of the actual gate length, so we can tweak the
    // table without touching the menu strings.
    OS.align(4)
    threshold_frames_table:
    dw 5 * 60       // index 0 = "5"
    dw 10 * 60      // index 1 = "10" (default)
    dw 15 * 60      // index 2 = "15"
    dw 20 * 60      // index 3 = "20"
    dw 30 * 60      // index 4 = "30"

    // @ Description
    // Wipes the per-port state arrays. Called from
    // Item.clear_active_custom_items_ (which fires on CSS / VS / Training /
    // VS Results entry), so each new match starts with both arrays at 0.
    // No 0xFFFFFFFF sentinel needed — see apply_pressure_tick_ for the
    // first-hit detection logic.
    scope clear_state_: {
        li      at, last_damage_frame
        sw      r0, 0x0000(at)
        sw      r0, 0x0004(at)
        sw      r0, 0x0008(at)
        sw      r0, 0x000C(at)

        li      at, previous_damage
        sw      r0, 0x0000(at)
        sw      r0, 0x0004(at)
        sw      r0, 0x0008(at)
        sw      r0, 0x000C(at)

        // Reset the overlay's live values so the timer reads as 00 between
        // matches (or before the first hit of a match). apply_pressure_tick_
        // overwrites these with the current threshold the moment it sees
        // damage > 0, so the visible window is correct from the very first
        // tick onwards.
        li      at, display_tens
        sw      r0, 0x0000(at)
        sw      r0, 0x0004(at)
        sw      r0, 0x0008(at)
        sw      r0, 0x000C(at)

        li      at, display_ones
        sw      r0, 0x0000(at)
        sw      r0, 0x0004(at)
        sw      r0, 0x0008(at)
        sw      r0, 0x000C(at)

        jr      ra
        nop
    }

    // @ Description
    // Per-player per-frame tick. Hooked from Poison.poison_hook (which
    // the engine drives via its heal/damage pipeline). Detects when the
    // player has taken damage (current > previous_damage) and updates
    // last_damage_frame; if enough idle time has elapsed since the last
    // hit, snaps player.0x002C back to 0.
    //
    // @ Arguments
    // a2 - player struct
    //
    // @ Returns
    // Nothing — purely side-effect on player.0x002C and internal state.
    //
    // Register usage: stack-saves everything it touches so the caller
    // (which is mid-game-code on a hot path) is unaffected. All branches
    // funnel through _end to keep teardown in one place.
    scope apply_pressure_tick_: {
        addiu   sp, sp, -0x0030
        sw      ra, 0x0004(sp)
        sw      t0, 0x0008(sp)
        sw      t1, 0x000C(sp)
        sw      t2, 0x0010(sp)
        sw      t3, 0x0014(sp)
        sw      t4, 0x0018(sp)
        sw      t5, 0x001C(sp)
        sw      t6, 0x0020(sp)
        sw      at, 0x0024(sp)

        // ── Master toggle ────────────────────────────────────────────────────
        Toggles.read(entry_combo_pressure, t0)
        beqz    t0, _end
        nop

        // ── Scope: only inside an active VS match ───────────────────────────
        // Outside of VS the heal/damage hook still runs (e.g. on Results),
        // so we filter by current screen here rather than rely on the
        // caller. 0x16 = VS match screen, same constant the existing
        // PoisonDmg.apply_damage uses.
        li      t0, Global.current_screen
        lbu     t0, 0x0000(t0)
        addiu   t1, r0, 0x0016
        bne     t0, t1, _end
        nop

        // ── Skip in Stamina mode ────────────────────────────────────────────
        // Resetting HP in Stamina would effectively revive the player —
        // very different mechanic than the user signed up for, so just
        // bail out. Consistent with how Tag Team Heal handles Stamina.
        li      t0, Stamina.VS_MODE
        lbu     t0, 0x0000(t0)
        addiu   t1, r0, Stamina.STAMINA_MODE
        beq     t0, t1, _end
        nop

        // ── Resolve port + read current state ───────────────────────────────
        lbu     t0, 0x000D(a2)              // t0 = port (0..3)
        sll     t1, t0, 0x0002              // t1 = port * 4
        li      t2, last_damage_frame
        addu    t2, t2, t1                  // t2 = &last_damage_frame[port]
        li      t3, previous_damage
        addu    t3, t3, t1                  // t3 = &previous_damage[port]

        lw      t4, 0x002C(a2)              // t4 = current damage (raw int)

        // ── Elapsed time (engine-driven match timer word) ───────────────────
        // We use the exact same source as PoisonDmg.apply_damage and our
        // own TagTeam.apply_stock_heal_tick_, so cadences stay consistent
        // and the gate fires reliably during any active match (1P, VS,
        // Tag Team — though here we already filtered to VS above).
        li      t5, Global.match_info
        lw      t5, 0x0000(t5)              // t5 = match_info struct ptr
        beqz    t5, _end                    // no match → bail (safety)
        nop
        lw      t5, 0x0018(t5)              // t5 = elapsed frames (since match start)

        // ── Damage-increase edge detection ──────────────────────────────────
        // If current > previous, the player just took damage this frame
        // (or some recent frame since our last visit). Stamp last_damage_frame
        // with NOW so the reset timer restarts.
        lw      t6, 0x0000(t3)              // t6 = previous_damage[port]
        sltu    at, t6, t4                  // at = 1 if previous < current
        beqz    at, _check_reset            // no damage taken → skip stamp
        nop
        sw      t5, 0x0000(t2)              // last_damage_frame[port] = elapsed

        _check_reset:
        // ── Reset gate ──────────────────────────────────────────────────────
        // Only meaningful if the player actually has damage to reset, and
        // only if last_damage_frame has been set at least once this match
        // (last_damage_frame == 0 means "no hit yet" — clear_state_ zeroed
        // the array at match start, and elapsed is monotonically increasing
        // and starts ≥ 1, so 0 is a safe "uninitialised" sentinel).
        beqz    t4, _update_previous        // damage already 0 → nothing to reset
        nop
        lw      t6, 0x0000(t2)              // t6 = last_damage_frame[port]
        beqz    t6, _update_previous        // never been hit → don't fire
        nop

        // delta = elapsed - last_damage_frame[port]
        subu    t6, t5, t6                  // t6 = idle frames since last hit

        // ── Look up threshold for current Pressure Window value ─────────────
        Toggles.read(entry_pressure_window, t0)
        sll     t0, t0, 0x0002              // t0 = index * 4 (word stride)
        li      t1, threshold_frames_table
        addu    t1, t1, t0
        lw      t1, 0x0000(t1)              // t1 = threshold in frames

        // delta < threshold → still inside the window, no reset yet
        sltu    at, t6, t1
        bnez    at, _update_previous
        nop

        // ── Reset fires ─────────────────────────────────────────────────────
        // Route the reset through the engine's add_percent_ (= 0x800EA248)
        // instead of writing player.0x002C directly. The HUD's damage
        // readout caches the on-screen number and is only refreshed by the
        // engine's own damage-update pipeline; a raw sw to 0x002C leaves the
        // displayed % stale until the next genuine hit, even though the
        // logic value (and knockback math, etc.) is already 0. add_percent_
        // is the same call the engine uses for every hit, so this also
        // exercises the proper HUD invalidation path.
        //
        // We can't go below 0 (the engine will crash per the comment in
        // Character.add_percent_), so we subtract exactly the current value.
        // a0 = player struct, a1 = delta. Stack-save the bookkeeping regs
        // we still need after the call; add_percent_ wraps the underlying
        // engine routine in OS.save_registers, so caller-saved temporaries
        // round-trip safely, but we keep our own pointers (t2/t5) on the
        // stack just to make the post-call updates self-evident.
        sw      t2, 0x0028(sp)               // &last_damage_frame[port]
        sw      t5, 0x002C(sp)               // elapsed (also re-used as the
                                              //          new last-hit stamp)

        // Audio cue. P-Wing End (FGM 0x55A) plays whenever a "powerup
        // expires" elsewhere in the game; reusing it for the damage reset
        // gives the same "something valuable just slipped away" feel
        // without authoring a new sound asset.
        //
        // CAREFUL: the FGM.play(...) *macro* expands to a bare
        // `jal 0x800269C0; addiu a0, r0, {sfx}` with NO register
        // bookkeeping — it nukes every caller-saved reg including a2
        // (player struct) and t4 (current damage). Use FGM.play_ (the
        // underscore version) which wraps the call in
        // OS.save_registers / OS.restore_registers, so our locals
        // survive the audio dispatch.
        //
        // Sub-toggle: skip the SFX when the user disabled it. The reset
        // gameplay itself still fires — only the audio cue is silenced.
        Toggles.read(entry_combo_pressure_sound, t6)
        beqz    t6, _skip_sfx
        nop
        addiu   a0, r0, 0x55A                // sfx id
        jal     FGM.play_
        nop
        _skip_sfx:

        or      a0, a2, r0                   // a0 = player struct
        subu    a1, r0, t4                   // a1 = -current_damage
        jal     Character.add_percent_       // applies the delta + refreshes HUD
        nop
        lw      t2, 0x0028(sp)
        lw      t5, 0x002C(sp)
        sw      t5, 0x0000(t2)               // last_damage_frame[port] = elapsed
        or      t4, r0, r0                   // local t4 mirror = 0 for the
                                              // upcoming previous_damage store

        _update_previous:
        // ── IMPORTANT: this block is reached from two paths ─────────────────
        //   • normal: no reset, locals (t1..t6, at) still valid
        //   • reset:  came through FGM.play(0x55A) AND
        //             jal Character.add_percent_ — both clobber every
        //             caller-saved register. Only a2 (player struct) and
        //             sp survive.
        //
        // Earliest version of this code assumed the normal-path locals
        // were live here, which crashed the reset path with a TLB store
        // exception at 0x003FFF01 (= garbage t3 from the previous jal).
        // To make the block bullet-proof we re-derive everything we need
        // from a2 every time — three extra instructions vs. trying to
        // thread save/restore through both code paths.

        // ── (1) Snapshot current damage into previous_damage[port] ──────────
        lbu     t0, 0x000D(a2)                    // t0 = port
        sll     t6, t0, 0x0002                    // t6 = port * 4
        li      t3, previous_damage
        addu    t3, t3, t6                        // t3 = &previous_damage[port]
        lw      t4, 0x002C(a2)                    // t4 = current damage
                                                   // (= 0 after a reset, else live %)
        sw      t4, 0x0000(t3)

        // ── (2) Compute & store the on-screen timer value ───────────────────
        // The Render.draw_number pairs set up in setup_timer_display_ are
        // bound to display_tens[port] / display_ones[port] and re-read them
        // every frame via Render.update_live_string_, so we just keep those
        // two words in sync with the gate state. We compute the whole-second
        // countdown first, then split it into tens + ones.
        //
        // Three cases:
        //   • damage == 0 OR last_damage_frame == 0 (never hit yet)
        //         → show the full threshold (= "fresh 10 seconds ready")
        //   • damage > 0, idle_frames < threshold
        //         → countdown: ceil((threshold − idle_frames) / 60) so the
        //           player sees "10, 9, 8, …, 1" before the snap rather
        //           than "9, …, 0, snap" (off-by-one visual)
        //   • damage > 0, idle_frames >= threshold
        //         → 0 (about to snap or just snapped this same frame)

        // Threshold in seconds (lookup table indexed by the toggle value)
        Toggles.read(entry_pressure_window, t1)   // 0..4 toggle index
        sll     t6, t1, 0x0002                    // t6 = index * 4
        li      t1, threshold_seconds_table
        addu    t1, t1, t6
        lw      t1, 0x0000(t1)                    // t1 = threshold in seconds

        // Port stride (re-derived because t6 above was the index*4 not port*4)
        lbu     t0, 0x000D(a2)                    // t0 = port
        sll     t6, t0, 0x0002                    // t6 = port * 4

        // last_damage_frame[port]
        li      t0, last_damage_frame
        addu    t0, t0, t6
        lw      t0, 0x0000(t0)                    // t0 = last_damage_frame[port]

        // Skip the timer math entirely if there's nothing to count down for
        beqz    t4, _show_full                    // damage == 0 → full timer
        nop
        beqz    t0, _show_full                    // never hit yet → full timer
        nop

        // Reload elapsed from match_info — t5 above is gone post-jal
        li      t5, Global.match_info
        lw      t5, 0x0000(t5)
        beqz    t5, _show_full                    // no match struct → safety
        nop
        lw      t5, 0x0018(t5)                    // t5 = elapsed (word)

        // countdown_frames = threshold_seconds * 60 − (elapsed − last_damage_frame)
        //                  = threshold_seconds * 60 + last_damage_frame − elapsed
        // Multiply by 60 as (x << 6) − (x << 2) = 64x − 4x.
        sll     t6, t1, 0x0002                    // t6 = threshold * 4
        sll     t3, t1, 0x0006                    // t3 = threshold * 64
        subu    t3, t3, t6                        // t3 = threshold * 60 = threshold_frames
        subu    t3, t3, t5                        // t3 -= elapsed
        addu    t3, t3, t0                        // t3 += last_damage_frame
        bgez    t3, _round_up_seconds
        nop
        or      t3, r0, r0                        // clamp to 0 if negative

        _round_up_seconds:
        addiu   t3, t3, 59                        // ceil(x/60) = (x + 59) / 60
        lli     t6, 60
        divu    t3, t6
        mflo    t3                                // t3 = remaining seconds (rounded up)
        // Final clamp: never display more than the configured threshold,
        // even on the first frame right after a hit (the +59 ceil could
        // theoretically nudge it one over).
        sltu    t6, t1, t3                        // t6 = 1 if threshold < t3
        beqz    t6, _split_digits                 // result within range → split it
        nop
        or      t3, t1, r0                        // else clamp t3 = threshold
        b       _split_digits
        nop

        _show_full:
        or      t3, t1, r0                        // display the full threshold

        _split_digits:
        // t3 = whole seconds to show. Split into tens (t1) and ones (t2)
        // with one unsigned divide (LO = quotient, HI = remainder), then
        // write each digit to its per-port slot. Re-derive the port offset
        // since the registers above are spent.
        lli     t6, 10
        divu    t3, t6
        mflo    t1                                // t1 = tens digit
        mfhi    t2                                // t2 = ones digit

        lbu     t0, 0x000D(a2)                    // t0 = port
        sll     t6, t0, 0x0002                    // t6 = port * 4

        li      at, display_tens
        addu    at, at, t6
        sw      t1, 0x0000(at)                    // display_tens[port] = tens

        li      at, display_ones
        addu    at, at, t6
        sw      t2, 0x0000(at)                    // display_ones[port] = ones

        _end:
        lw      ra, 0x0004(sp)
        lw      t0, 0x0008(sp)
        lw      t1, 0x000C(sp)
        lw      t2, 0x0010(sp)
        lw      t3, 0x0014(sp)
        lw      t4, 0x0018(sp)
        lw      t5, 0x001C(sp)
        lw      t6, 0x0020(sp)
        lw      at, 0x0024(sp)
        jr      ra
        addiu   sp, sp, 0x0030
    }

    // @ Description
    // Per-port labels for the on-screen timer. Drawn in the player's
    // canonical color (P1=red, P2=blue, P3=yellow, P4=green) so a glance
    // at the corner is enough to tell whose timer is whose.
    label_p1:; String.insert("P1:")
    label_p2:; String.insert("P2:")
    label_p3:; String.insert("P3:")
    label_p4:; String.insert("P4:")
    OS.align(4)

    // @ Description
    // Helper: returns v0 = 1 if the given port (a0 ∈ 0..3) has an
    // active player (HMN or CPU), 0 if NA / no match struct. Used by
    // setup_timer_display_ to suppress timers for ports nobody chose.
    //
    // Reads Global.match_info → struct + (port * 0x74) → player match
    // struct, then byte 0x22 = player_type (0=HMN, 1=CPU, 2=NA). Same
    // approach as ComboMeter.port_check.
    scope port_is_active_: {
        li      t0, Global.match_info
        lw      t0, 0x0000(t0)
        beqz    t0, _inactive
        nop
        lli     t1, 0x0074
        multu   a0, t1
        mflo    t1
        addu    t0, t0, t1                       // t0 = &player_match_struct[port]
        lbu     t1, 0x0022(t0)                   // t1 = player type
        sltiu   v0, t1, 0x0002                   // v0 = 1 if HMN or CPU
        jr      ra
        nop

        _inactive:
        or      v0, r0, r0
        jr      ra
        nop
    }

    // @ Description
    // Wires up the on-screen "seconds-until-reset" overlay for every
    // *active* port. Runs once per match from Render.setup_'s _vs hook.
    //
    // Layout: a single row of "Pn: NN" cells laid out horizontally in
    // the top-left corner, in canonical player colors (P1=red, P2=blue,
    // P3=yellow, P4=green). Ports flagged NA in the match info are
    // skipped entirely so a 1-v-1 only shows two timers (P1 + P2) — no
    // dead "P3: 10 / P4: 10" cells cluttering the HUD.
    //
    // Gated by *two* toggles:
    //   - entry_combo_pressure       — master feature on/off
    //   - entry_combo_pressure_display — overlay sub-toggle (default ON)
    // When either is OFF we never create any render objects, so the
    // overlay-disabled path costs zero rendering per frame.
    //
    // (Mid-match toggle flips don't tear down the existing render
    // objects — same as the gameplay reset itself stops firing the
    // moment the master toggle flips, the visible labels persist until
    // the next match start. Consistent and predictable.)
    scope setup_timer_display_: {
        addiu   sp, sp, -0x0020
        sw      ra, 0x0004(sp)

        // ── Master + display toggles ─────────────────────────────────────────
        Toggles.read(entry_combo_pressure, t0)
        beqz    t0, _end
        nop
        Toggles.read(entry_combo_pressure_display, t0)
        beqz    t0, _end
        nop

        Render.load_font()

        // Room covers from upper-left (10, 20) to lower-right (170, 40).
        // CAREFUL: the last two macro args are *absolute* lrx/lry, not
        // width/height — a previous version of this passed (160, 15) here
        // intending "width 160, height 15" and produced an inverted room
        // (lry < uly), which the renderer clips away entirely. Verify any
        // future tweak with lrx > ulx and lry > uly.
        //   ulx = 10  (0x41200000)
        //   uly = 20  (0x41A00000)
        //   lrx = 170 (0x432A0000) — covers 4 cells of ~40 px width
        //   lry = 40  (0x42200000) — one row, ~20 px tall
        Render.create_room(0x38, 0x18, 0x01, 0x41200000, 0x41A00000, 0x432A0000, 0x42200000)

        // Layout per cell: colored "Pn:" label, then a two-digit white
        // countdown. tens + ones are separate draw_number objects placed
        // ~6 px apart so the leading zero is always rendered (06, not 6).
        // The digits sit a few px right of the label so they don't crowd
        // the colon.
        //   P1: label x=10,  tens x=30,  ones x=36
        //   P2: label x=50,  tens x=70,  ones x=76
        //   P3: label x=90,  tens x=110, ones x=116
        //   P4: label x=130, tens x=150, ones x=156
        // All on row y=20. Numbers use Color.high.WHITE; only the label
        // carries the player color.

        // ── P1 cell: red label, white digits ────────────────────────────────
        // a0 = port for port_is_active_; we don't need to preserve it
        // because each branch sets a0 fresh.
        jal     port_is_active_
        lli     a0, 0
        beqz    v0, _skip_p1
        nop
        Render.draw_string(0x38, 0x19, label_p1, Render.NOOP, 0x41200000, 0x41A00000, Color.tag.RED, 0x3F600000, Render.alignment.LEFT)
        Render.draw_number(0x38, 0x19, display_tens + 0x0, Render.update_live_string_, 0x41F00000, 0x41A00000, Color.high.WHITE, 0x3F600000, Render.alignment.LEFT)
        Render.draw_number(0x38, 0x19, display_ones + 0x0, Render.update_live_string_, 0x42100000, 0x41A00000, Color.high.WHITE, 0x3F600000, Render.alignment.LEFT)
        _skip_p1:

        // ── P2 cell: blue label, white digits ───────────────────────────────
        jal     port_is_active_
        lli     a0, 1
        beqz    v0, _skip_p2
        nop
        Render.draw_string(0x38, 0x19, label_p2, Render.NOOP, 0x42480000, 0x41A00000, Color.tag.BLUE, 0x3F600000, Render.alignment.LEFT)
        Render.draw_number(0x38, 0x19, display_tens + 0x4, Render.update_live_string_, 0x428C0000, 0x41A00000, Color.high.WHITE, 0x3F600000, Render.alignment.LEFT)
        Render.draw_number(0x38, 0x19, display_ones + 0x4, Render.update_live_string_, 0x42980000, 0x41A00000, Color.high.WHITE, 0x3F600000, Render.alignment.LEFT)
        _skip_p2:

        // ── P3 cell: yellow label, white digits ─────────────────────────────
        jal     port_is_active_
        lli     a0, 2
        beqz    v0, _skip_p3
        nop
        Render.draw_string(0x38, 0x19, label_p3, Render.NOOP, 0x42B40000, 0x41A00000, Color.tag.YELLOW, 0x3F600000, Render.alignment.LEFT)
        Render.draw_number(0x38, 0x19, display_tens + 0x8, Render.update_live_string_, 0x42DC0000, 0x41A00000, Color.high.WHITE, 0x3F600000, Render.alignment.LEFT)
        Render.draw_number(0x38, 0x19, display_ones + 0x8, Render.update_live_string_, 0x42E80000, 0x41A00000, Color.high.WHITE, 0x3F600000, Render.alignment.LEFT)
        _skip_p3:

        // ── P4 cell: green label, white digits ──────────────────────────────
        jal     port_is_active_
        lli     a0, 3
        beqz    v0, _skip_p4
        nop
        Render.draw_string(0x38, 0x19, label_p4, Render.NOOP, 0x43020000, 0x41A00000, Color.tag.GREEN, 0x3F600000, Render.alignment.LEFT)
        Render.draw_number(0x38, 0x19, display_tens + 0xC, Render.update_live_string_, 0x43160000, 0x41A00000, Color.high.WHITE, 0x3F600000, Render.alignment.LEFT)
        Render.draw_number(0x38, 0x19, display_ones + 0xC, Render.update_live_string_, 0x431C0000, 0x41A00000, Color.high.WHITE, 0x3F600000, Render.alignment.LEFT)
        _skip_p4:

        _end:
        lw      ra, 0x0004(sp)
        jr      ra
        addiu   sp, sp, 0x0020
    }

}

} // __COMBO_PRESSURE__
