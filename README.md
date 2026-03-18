# 🚀 Antigravity Autopilot

[![VS Marketplace](https://img.shields.io/visual-studio-marketplace/v/timteh.antigravity-autopilot-os?label=VS%20Marketplace&color=blue)](https://marketplace.visualstudio.com/items?itemName=timteh.antigravity-autopilot-os)
[![Installs](https://img.shields.io/visual-studio-marketplace/i/timteh.antigravity-autopilot-os?color=green)](https://marketplace.visualstudio.com/items?itemName=timteh.antigravity-autopilot-os)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Auto-accept agent steps in Antigravity IDE — no CDP required.**

Uses OS-level accessibility (Windows UI Automation) to click Run, Accept, Continue, and other agent buttons **invisibly** — no mouse movement, no DOM injection, no Chrome DevTools Protocol.

<a href="https://www.buymeacoffee.com/timteh" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="50" width="217"></a>

---

## Why This Extension?

Every other auto-accept extension relies on **Chrome DevTools Protocol (CDP)**. This breaks when:

- ❌ Electron builds disable `--remote-debugging-port` (Antigravity does this)
- ❌ Corporate policies block CDP ports
- ❌ Shortcut patching fails silently
- ❌ CDP WebSocket drops on auto-updates

**Antigravity Autopilot doesn't use CDP at all.** It uses Windows UI Automation APIs to find and click buttons through the accessibility tree — the same API that screen readers use. This means:

- ✅ **Works when CDP is blocked** — no port configuration needed
- ✅ **No mouse hijacking** — uses `InvokePattern.Invoke()` (invisible click)
- ✅ **No DOM injection** — doesn't touch the webview content
- ✅ **No shortcut patching** — no `.lnk` file modifications
- ✅ **Auto-scrolls chat** — keeps up with agent output

---

## Quick Start

### 1. Install the Extension

`Ctrl+Shift+X` → Search **"Antigravity Autopilot"** → Install

### 2. Enable Accessibility (One-Time)

On first launch, the extension will prompt you to set the `ELECTRON_FORCE_RENDERER_ACCESSIBILITY` environment variable. Click **"Set Environment Variable"** and restart Antigravity.

Or do it manually:
```powershell
[System.Environment]::SetEnvironmentVariable('ELECTRON_FORCE_RENDERER_ACCESSIBILITY', '1', 'User')
```

> **Why?** Electron-based IDEs don't expose webview UI elements by default. This env var forces the Chromium renderer to populate the accessibility tree, making agent buttons visible to UI Automation.

### 3. Use It

- **Status bar**: Click `Autopilot ON` / `Autopilot OFF` to toggle
- **Keyboard shortcut**: `Ctrl+Shift+A` (`Cmd+Shift+A` on macOS) — instant toggle
- **Command palette**: `Ctrl+Shift+P` → "Antigravity Autopilot: Start/Stop/Toggle"
- **Auto-start**: Enabled by default — starts when Antigravity opens

---

## How It Works

```
┌─────────────────────────────────────────┐
│         Antigravity IDE (Electron)       │
│  ┌──────────────────────────────────┐   │
│  │  Agent Panel (React Webview)     │   │
│  │  ┌────────────────────────────┐  │   │
│  │  │  [Run Alt+d] [Reject]     │  │   │
│  │  └────────────────────────────┘  │   │
│  └──────────────────────────────────┘   │
│         ↑ Accessibility Tree            │
└─────────┼───────────────────────────────┘
          │ InvokePattern.Invoke()
┌─────────┼───────────────────────────────┐
│  Autopilot Watcher (PowerShell)         │
│  - Polls every 800ms                    │
│  - Finds buttons by text pattern        │
│  - Clicks via InvokePattern (invisible) │
│  - Cooldown prevents re-clicking        │
└─────────────────────────────────────────┘
```

1. **Polls** the IDE window's accessibility tree every 800ms
2. **Focus-aware**: Only clicks when the IDE is the foreground window — won't interrupt other apps
3. **Matches** button names against configurable accept/reject regex patterns
4. **Clicks** matching buttons via `InvokePattern.Invoke()` — no mouse, no focus steal
5. **Cooldown** prevents re-clicking the same button within 10 seconds
6. **Auto-scrolls** the chat to keep up with agent output (3s cooldown)

---

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `antigravityAutopilot.enabled` | `true` | Master toggle |
| `antigravityAutopilot.pollIntervalMs` | `800` | Scan interval (ms) |
| `antigravityAutopilot.cooldownSeconds` | `10` | Per-button cooldown |
| `antigravityAutopilot.scrollCooldownSeconds` | `3` | Scroll button cooldown |
| `antigravityAutopilot.autoScroll` | `true` | Auto-click "Scroll to bottom" |
| `antigravityAutopilot.acceptPatterns` | `["^Run", "^Accept", ...]` | Regex patterns to auto-click |
| `antigravityAutopilot.rejectPatterns` | `["^Cancel", "^Reject", ...]` | Patterns to NEVER click |

### Default Accept Patterns
```
^Run, ^Accept, ^Accept All$, ^Allow$, ^Allow this conversation$,
^Continue$, ^Keep All$, ^Yes$, ^Retry$, ^Scroll to bottom$,
^Send all$, ^Always Allow$, ^Always run$
```

### Default Reject Patterns (Safety Net)
```
^Reject, ^Cancel$, ^Deny, ^Delete, ^Remove, ^Discard, ^Close,
^Minimize$, ^Maximize$, ^Review Changes$
```

---

## Supported IDEs

| IDE | Status |
|-----|--------|
| **Antigravity** | ✅ Fully tested |
| **Cursor** | ✅ Should work (same Electron base) |
| **Windsurf** | ✅ Should work (same Electron base) |
| **VS Code** | ✅ Should work |

---

## Platform Support

| Platform | Status |
|----------|--------|
| **Windows** | ✅ Full support (UI Automation) |
| **macOS** | 🔜 Planned (AXUIElement API) |
| **Linux** | 🔜 Planned (AT-SPI) |

---

## Troubleshooting

### Extension says "only 3 buttons found"
The accessibility env var isn't set or Antigravity wasn't restarted. Run:
```powershell
$env:ELECTRON_FORCE_RENDERER_ACCESSIBILITY = "1"
& "C:\path\to\Antigravity.exe"
```

### Watcher can't find the IDE window
Make sure only one instance of Antigravity is running.

### Buttons not being clicked
Check the Output panel (`Ctrl+Shift+U` → "Antigravity Autopilot") for logs. The button text may not match the default patterns — add custom patterns in settings.

---

## Contributing

PRs welcome! The main areas for contribution:

- **macOS support** — implement `AXUIElement`-based watcher in Swift/Python
- **Linux support** — implement `AT-SPI`-based watcher
- **New button patterns** — submit patterns for other IDE forks
- **Performance** — optimize the polling/scanning loop

---

## License

MIT — see [LICENSE](LICENSE)

---

<p align="center">
  <a href="https://www.buymeacoffee.com/timteh" target="_blank">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="50" width="217">
  </a>
  <br>
  <em>If this saved you from clicking 1000 buttons, consider buying me a coffee ☕</em>
</p>
