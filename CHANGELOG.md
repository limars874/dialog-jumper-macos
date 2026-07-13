# Changelog

Notable changes to Dialog Jumper. Format inspired by [Keep a Changelog](https://keepachangelog.com/).

## [0.0.2] — 2026-07-12

### Added
- Path field: clear (×) control; drag handle inside the path chrome
- Overflow menu (···): Add Path to Favorites, Copy Path Field
- List favorite stars: filled + systemYellow when already in Favorites
- Segment strip chrome: Rec | Fav | Find | Zox and refresh as one bar (same outer width as Path / Jump)
- Refresh always visible; disabled on Rec/Fav, enabled on Find/Zox

### Changed
- Unified control grid (height ~segment bezel, shared content width)
- Primary Jump as full-bleed accent button (no system bezel side inset)
- Path text vertically centered in chrome
- Jump optical width −2pt per side to match neighbors
- Status line uses secondary label color

### Fixed
- Clear button hidden when path set from list rows
- Path field vertical alignment inside custom chrome

## [0.0.1] — 2026-07-12

### Added
- Initial lab release (ad-hoc signed, not notarized)
- Folder Jump for system Open/Save panels
- Path / Recents / Favorites / Finder / Zoxide sources
- List drag handles for native panel navigation
- Menu: Jump on List Click; Accessibility recovery
- GitHub Actions release workflow
