# Battle Royale — promoted current-parent source

These modules are part of the frozen 2026-09-29 current parent.

They were promoted from the owner-tested R4 RC1 project layer without changing the resulting ROM bytes. The canonical parent build includes them after the exact reconstructed 2026-09-28 base overlay.

Included parent behavior:

- Battle Royale exact-character uniqueness for automatic P1-P5 selections;
- context-aware P1-P4 uniqueness both while opening/changing ports and when `?` resolves at match start;
- native R3 six-pick recent-history behavior for P1-P4, unchanged in its original implementation;
- a BR-private fifth six-pick history bucket for P5;
- P5 full Remix Random roster and playable-file resource rebinding;
- 70% Battle Royale Results Place numerals;
- Battle Royale Results / No Contest title using the established CSS lettering at native Results coordinates.

This directory is now immutable parent-owned source. Future changes belong under `src/Project/`.
