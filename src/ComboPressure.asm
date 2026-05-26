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
        // Always snapshot current damage for next frame's edge detection.
        // After a reset this stores 0; on the frame the player gets hit
        // we already updated last_damage_frame above, so storing the
        // post-hit damage here keeps the next-frame comparison correct.
        sw      t4, 0x0000(t3)

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

}

} // __COMBO_PRESSURE__
