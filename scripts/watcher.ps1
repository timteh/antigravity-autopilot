# Antigravity Autopilot — OS-Level UI Automation Watcher
# Uses Windows UI Automation + InvokePattern to click agent buttons
# No CDP, no mouse movement, no DOM injection
#
# Copyright (c) 2026 Tim Melnik — MIT License
# https://github.com/timteh/antigravity-autopilot

param(
    [int]$IntervalMs = 800,
    [int]$CooldownSeconds = 10,
    [int]$ScrollCooldownSeconds = 3,
    [switch]$NoAutoScroll,
    [switch]$DryRun,
    [switch]$Verbose
)

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

# Win32 API for foreground window detection — prevents focus stealing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class FocusHelper {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
}
"@

# ====== Button Patterns ======
# Configurable via environment variables (set by extension.js)
# or defaults below

if ($env:AUTOPILOT_ACCEPT_PATTERNS) {
    $acceptPatterns = $env:AUTOPILOT_ACCEPT_PATTERNS | ConvertFrom-Json
} else {
    $acceptPatterns = @(
        "^Run",
        "^Accept",
        "^Accept All$",
        "^Send all",
        "^Always Allow",
        "^Always run",
        "^Allow$",
        "^Allow this conversation$",
        "^Continue$",
        "^Keep All$",
        "^Yes$",
        "^Retry$"
    )
}

if (-not $NoAutoScroll) {
    $acceptPatterns += "^Scroll to bottom$"
}

if ($env:AUTOPILOT_REJECT_PATTERNS) {
    $rejectPatterns = $env:AUTOPILOT_REJECT_PATTERNS | ConvertFrom-Json
} else {
    $rejectPatterns = @(
        "^Reject",
        "^Cancel$",
        "^Deny",
        "^Delete",
        "^Remove",
        "^Discard",
        "^Close",
        "^Minimize$",
        "^Maximize$",
        "^Collapse",
        "^Relocate$",
        "^Go Back",
        "^Go Forward",
        "^Split Editor",
        "^Profile$",
        "^Notifications$",
        "^Quick Open$",
        "^More Actions",
        "^Record voice",
        "^Ask every",
        "^Review Changes$",
        "^Thought for"
    )
}

$running = $true
$clickCount = 0
$skippedCount = 0
$startTime = Get-Date
$lastClickTimes = @{}

function Write-Status($msg) {
    $ts = (Get-Date).ToString("HH:mm:ss")
    Write-Host "[$ts] $msg"
}

# ====== IDE Window Detection ======
# Supports Antigravity, Cursor, Windsurf, and other Electron-based IDEs
$supportedProcesses = @("Antigravity", "Cursor", "Windsurf", "Code")

function Find-IDEWindow {
    $root = [System.Windows.Automation.AutomationElement]::RootElement
    $allWindows = $root.FindAll(
        [System.Windows.Automation.TreeScope]::Children,
        [System.Windows.Automation.Condition]::TrueCondition
    )
    foreach ($w in $allWindows) {
        try {
            $wpid = $w.Current.ProcessId
            $proc = Get-Process -Id $wpid -ErrorAction SilentlyContinue
            if ($proc -and $proc.ProcessName -in $supportedProcesses) {
                $name = $w.Current.Name
                if ($name -and $name.Length -gt 0) {
                    return $w
                }
            }
        } catch { continue }
    }
    return $null
}

# ====== Button Scanner ======
function Find-AcceptButtons($window) {
    $found = @()

    # Scan Button control type
    $btnCondition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::Button
    )

    try {
        $buttons = $window.FindAll(
            [System.Windows.Automation.TreeScope]::Descendants,
            $btnCondition
        )

        foreach ($btn in $buttons) {
            $name = $btn.Current.Name
            if ([string]::IsNullOrEmpty($name)) { continue }

            # Check reject patterns first
            $isReject = $false
            foreach ($rp in $rejectPatterns) {
                if ($name -match $rp) { $isReject = $true; break }
            }
            if ($isReject) { continue }

            # Check accept patterns
            foreach ($ap in $acceptPatterns) {
                if ($name -match $ap) {
                    $found += @{
                        Element = $btn
                        Name = $name
                        Pattern = $ap
                    }
                    break
                }
            }
        }
    } catch {
        if ($Verbose) { Write-Status "Button scan error: $_" }
    }

    # Also scan Hyperlink control types (some buttons render as links)
    $linkCondition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::Hyperlink
    )

    try {
        $links = $window.FindAll(
            [System.Windows.Automation.TreeScope]::Descendants,
            $linkCondition
        )

        foreach ($link in $links) {
            $name = $link.Current.Name
            if ([string]::IsNullOrEmpty($name)) { continue }

            foreach ($ap in $acceptPatterns) {
                if ($name -match $ap) {
                    $found += @{
                        Element = $link
                        Name = $name
                        Pattern = $ap
                    }
                    break
                }
            }
        }
    } catch {
        if ($Verbose) { Write-Status "Link scan error: $_" }
    }

    return $found
}

# ====== Click Handler ======
function Invoke-AcceptButton($buttonInfo) {
    $element = $buttonInfo.Element
    $name = $buttonInfo.Name

    # Cooldown: "Scroll to bottom" uses shorter cooldown
    $now = Get-Date
    $effectiveCooldown = if ($name -eq "Scroll to bottom") { $ScrollCooldownSeconds } else { $CooldownSeconds }
    if ($script:lastClickTimes.ContainsKey($name)) {
        $elapsed = ($now - $script:lastClickTimes[$name]).TotalSeconds
        if ($elapsed -lt $effectiveCooldown) {
            $script:skippedCount++
            return $false
        }
    }

    try {
        # InvokePattern ONLY — no mouse movement, completely invisible
        $invokePattern = $element.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
        if ($invokePattern) {
            if ($DryRun) {
                Write-Status "[DRY RUN] Would click: '$name'"
            } else {
                $invokePattern.Invoke()
                $script:clickCount++
                $script:lastClickTimes[$name] = $now
                if ($name -ne "Scroll to bottom") {
                    Write-Status "CLICKED: '$name' (total: $script:clickCount)"
                }
            }
            return $true
        }
    } catch {
        if ($Verbose) { Write-Status "InvokePattern failed for '$name': $_" }
    }

    return $false
}

# ====== Main Loop ======
Write-Host ""
Write-Host "========================================="
Write-Host "  Antigravity Autopilot v1.1.0"
Write-Host "  github.com/timteh/antigravity-autopilot"
Write-Host "  Interval: ${IntervalMs}ms"
Write-Host "  Cooldown: ${CooldownSeconds}s"
Write-Host "  Auto-scroll: $(-not $NoAutoScroll)"
if ($DryRun) { Write-Host "  MODE: DRY RUN (no clicks)" }
Write-Host "  Press Ctrl+C to stop"
Write-Host "========================================="
Write-Host ""

# Check accessibility
if (-not $env:ELECTRON_FORCE_RENDERER_ACCESSIBILITY) {
    Write-Host "WARNING: ELECTRON_FORCE_RENDERER_ACCESSIBILITY is not set."
    Write-Host "Webview buttons may not be visible to UI Automation."
    Write-Host "The extension should have offered to set this for you."
    Write-Host ""
}

$lastWindowCheck = [DateTime]::MinValue
$ideWindow = $null

try {
    while ($running) {
        # Re-find window periodically (every 5 seconds)
        $now = Get-Date
        if (($now - $lastWindowCheck).TotalSeconds -gt 5 -or $null -eq $ideWindow) {
            $ideWindow = Find-IDEWindow
            $lastWindowCheck = $now

            if ($null -eq $ideWindow) {
                if ($Verbose) { Write-Status "IDE window not found, waiting..." }
                Start-Sleep -Milliseconds $IntervalMs
                continue
            } else {
                Write-Status "Found IDE: '$($ideWindow.Current.Name)'"
            }
        }

        # Only click when IDE is the foreground window — prevents focus stealing
        $fgHwnd = [FocusHelper]::GetForegroundWindow()
        $fgPid = [uint32]0
        [FocusHelper]::GetWindowThreadProcessId($fgHwnd, [ref]$fgPid) | Out-Null

        $idePid = $ideWindow.Current.ProcessId
        if ($fgPid -ne $idePid) {
            # IDE is not focused, skip clicking to avoid stealing focus
            Start-Sleep -Milliseconds $IntervalMs
            continue
        }

        # Scan for accept buttons
        $buttons = Find-AcceptButtons $ideWindow

        if ($buttons.Count -gt 0) {
            foreach ($btn in $buttons) {
                Invoke-AcceptButton $btn | Out-Null
                Start-Sleep -Milliseconds 200
            }
        }

        Start-Sleep -Milliseconds $IntervalMs
    }
} catch [System.Management.Automation.PipelineStoppedException] {
    # Ctrl+C pressed
} finally {
    $elapsed = (Get-Date) - $startTime
    Write-Host ""
    Write-Host "========================================="
    Write-Host "  Antigravity Autopilot stopped"
    Write-Host "  Total clicks: $clickCount"
    Write-Host "  Runtime: $($elapsed.ToString('hh\:mm\:ss'))"
    Write-Host "========================================="
}
