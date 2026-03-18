# Changelog

## [1.1.0] — 2026-03-18

### Added

- `^Retry$` pattern to default accept list — auto-clicks "Retry" when an agent task fails
- Default keybinding `Ctrl+Shift+A` (`Cmd+Shift+A` on macOS) to toggle Autopilot on/off

### Fixed

- **Focus-stealing bug**: Autopilot no longer clicks buttons when the IDE is not the active foreground window — prevents interrupting typing in Chrome, terminals, or other apps
- Status bar tooltip now shows keybinding hint and clearer DISABLE/ENABLE language

## [1.0.0] — 2026-03-17

### Added
- Initial release
- OS-level UI Automation watcher (Windows)
- InvokePattern click — no mouse movement, completely invisible
- No CDP required — works when every other auto-accept extension fails
- Configurable accept/reject patterns (regex)
- Cooldown system to prevent spam-clicking persistent buttons
- Auto-scroll to follow chat during agent runs
- Status bar toggle (Autopilot ON/OFF)
- Auto-detect ELECTRON_FORCE_RENDERER_ACCESSIBILITY and offer to set it
- Support for Antigravity, Cursor, Windsurf, and VS Code
