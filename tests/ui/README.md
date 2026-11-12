# UI tests

Phase 5 adds `validate_theme.sh`. It will check that:
- every `ui.xml`/`portrait.xml` include parses (`xmllint`),
- every `<image filename=…>` and `<font filename=…>` resolves to a file in `nova/`,
- every `<page name=…>` that an action targets exists,
- only element types and attributes that upstream `bootable/recovery/gui` parses are used (list taken from the pinned `android-12.1` sources).
