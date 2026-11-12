# UI design rules

- The interface is TWRP XML (`ui.xml` + pages), PNG images and TTF fonts only. No separate app, no framework, no unsupported element types. Check every element/attribute against `bootable/recovery/gui/*.cpp` at the pinned revision before using it.
- Theme install path: `TW_CUSTOM_THEME` copies only the one XML file; NOVA images and fonts are copied into `/twres/` by the device makefile.
- Colour tokens (only these): background `#101114`, surface `#191B20`, surface elevated `#22252C`, text primary `#F5F6F8`, text secondary `#989DA8`, accent `#75A9FF`, success `#57C98A`, warning `#EAB96B`, danger `#E66C76`, border `#30343D`. Source of truth: `nova/config/tokens.json`.
- Canvas 1080×2340. Respect notch offset (`TW_Y_OFFSET`) once verified. Minimum touch target 132 px (≈ 48 dp at 440 dpi).
- No gradients, no long animations (boot indicator only), no gaming look, nothing that copies the stock TWRP layout.
- Every button triggers a real TWRP action. Unsupported features show an explanation, not a fake success.
- Destructive actions use the danger colour and a confirmation step (see recovery-safety.md).
