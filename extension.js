// Antigravity Autopilot — VS Code Extension
// Auto-accept agent steps using OS-level UI Automation (no CDP required)
// Copyright (c) 2026 Tim Melnik — MIT License

const vscode = require('vscode');
const path = require('path');
const { spawn } = require('child_process');

let statusBarItem;
let watcherProcess = null;
let outputChannel;
let isRunning = false;

function activate(context) {
    outputChannel = vscode.window.createOutputChannel('Antigravity Autopilot');
    outputChannel.appendLine('Antigravity Autopilot activated');

    // Status bar item
    statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    statusBarItem.command = 'antigravity-autopilot.toggle';
    updateStatusBar(false);
    statusBarItem.show();
    context.subscriptions.push(statusBarItem);

    // Register commands
    context.subscriptions.push(
        vscode.commands.registerCommand('antigravity-autopilot.start', () => startWatcher(context)),
        vscode.commands.registerCommand('antigravity-autopilot.stop', () => stopWatcher()),
        vscode.commands.registerCommand('antigravity-autopilot.toggle', () => {
            if (isRunning) { stopWatcher(); } else { startWatcher(context); }
        }),
        vscode.commands.registerCommand('antigravity-autopilot.status', () => showStatus())
    );

    // Check platform
    if (process.platform !== 'win32') {
        outputChannel.appendLine('WARNING: Antigravity Autopilot currently supports Windows only.');
        outputChannel.appendLine('macOS and Linux support coming in a future release.');
        vscode.window.showWarningMessage(
            'Antigravity Autopilot currently supports Windows only. macOS/Linux support coming soon.'
        );
        return;
    }

    // Check accessibility env var
    if (!process.env.ELECTRON_FORCE_RENDERER_ACCESSIBILITY) {
        outputChannel.appendLine('WARNING: ELECTRON_FORCE_RENDERER_ACCESSIBILITY is not set.');
        outputChannel.appendLine('Webview buttons may not be visible to UI Automation.');
        const setVar = 'Set Environment Variable';
        vscode.window.showWarningMessage(
            'Antigravity Autopilot works best with ELECTRON_FORCE_RENDERER_ACCESSIBILITY=1. Set it now?',
            setVar, 'Dismiss'
        ).then(choice => {
            if (choice === setVar) {
                const terminal = vscode.window.createTerminal('Autopilot Setup');
                terminal.show();
                terminal.sendText(
                    `[System.Environment]::SetEnvironmentVariable('ELECTRON_FORCE_RENDERER_ACCESSIBILITY', '1', 'User')`,
                    true
                );
                terminal.sendText('Write-Host "Set! Restart Antigravity for it to take effect."', true);
                vscode.window.showInformationMessage(
                    'Environment variable set. Please restart Antigravity for it to take effect.'
                );
            }
        });
    }

    // Auto-start if enabled
    const config = vscode.workspace.getConfiguration('antigravityAutopilot');
    if (config.get('enabled', true)) {
        startWatcher(context);
    }
}

function startWatcher(context) {
    if (isRunning && watcherProcess) {
        vscode.window.showInformationMessage('Autopilot is already running.');
        return;
    }

    const config = vscode.workspace.getConfiguration('antigravityAutopilot');
    const scriptPath = path.join(context.extensionPath, 'scripts', 'watcher.ps1');
    const interval = config.get('pollIntervalMs', 800);
    const cooldown = config.get('cooldownSeconds', 10);
    const scrollCooldown = config.get('scrollCooldownSeconds', 3);
    const autoScroll = config.get('autoScroll', true);
    const acceptPatterns = config.get('acceptPatterns', []);
    const rejectPatterns = config.get('rejectPatterns', []);

    // Build arguments
    const args = [
        '-ExecutionPolicy', 'Bypass',
        '-File', scriptPath,
        '-IntervalMs', String(interval),
        '-CooldownSeconds', String(cooldown),
        '-ScrollCooldownSeconds', String(scrollCooldown)
    ];

    if (!autoScroll) { args.push('-NoAutoScroll'); }

    // Pass custom patterns via environment
    const env = { ...process.env };
    if (acceptPatterns.length > 0) {
        env.AUTOPILOT_ACCEPT_PATTERNS = JSON.stringify(acceptPatterns);
    }
    if (rejectPatterns.length > 0) {
        env.AUTOPILOT_REJECT_PATTERNS = JSON.stringify(rejectPatterns);
    }

    outputChannel.appendLine(`Starting watcher: powershell ${args.join(' ')}`);

    watcherProcess = spawn('powershell', args, {
        env,
        stdio: ['pipe', 'pipe', 'pipe']
    });

    watcherProcess.stdout.on('data', (data) => {
        const text = data.toString().trim();
        if (text) { outputChannel.appendLine(text); }
    });

    watcherProcess.stderr.on('data', (data) => {
        const text = data.toString().trim();
        if (text) { outputChannel.appendLine(`[ERROR] ${text}`); }
    });

    watcherProcess.on('exit', (code) => {
        outputChannel.appendLine(`Watcher exited with code ${code}`);
        isRunning = false;
        updateStatusBar(false);
    });

    isRunning = true;
    updateStatusBar(true);
    outputChannel.appendLine('Autopilot watcher started.');
}

function stopWatcher() {
    if (watcherProcess) {
        watcherProcess.kill();
        watcherProcess = null;
    }
    isRunning = false;
    updateStatusBar(false);
    outputChannel.appendLine('Autopilot watcher stopped.');
}

function updateStatusBar(running) {
    if (running) {
        statusBarItem.text = '$(rocket) Autopilot ON';
        statusBarItem.tooltip = 'Autopilot is auto-clicking agent buttons — click to DISABLE (Ctrl+Shift+A)';
        statusBarItem.backgroundColor = undefined;
    } else {
        statusBarItem.text = '$(debug-pause) Autopilot OFF';
        statusBarItem.tooltip = 'Autopilot is paused — click to ENABLE (Ctrl+Shift+A)';
        statusBarItem.backgroundColor = new vscode.ThemeColor('statusBarItem.warningBackground');
    }
}

function showStatus() {
    const config = vscode.workspace.getConfiguration('antigravityAutopilot');
    const hasAccessibility = !!process.env.ELECTRON_FORCE_RENDERER_ACCESSIBILITY;

    const lines = [
        `Status: ${isRunning ? '🟢 Running' : '🔴 Stopped'}`,
        `Platform: ${process.platform}`,
        `Accessibility: ${hasAccessibility ? '✅ Set' : '❌ Not set'}`,
        `Poll interval: ${config.get('pollIntervalMs')}ms`,
        `Cooldown: ${config.get('cooldownSeconds')}s`,
        `Auto-scroll: ${config.get('autoScroll') ? 'Yes' : 'No'}`,
        `Accept patterns: ${config.get('acceptPatterns', []).length}`,
        `Reject patterns: ${config.get('rejectPatterns', []).length}`
    ];

    vscode.window.showInformationMessage(lines.join(' | '));
    outputChannel.appendLine('--- Status ---');
    lines.forEach(l => outputChannel.appendLine(l));
}

function deactivate() {
    stopWatcher();
    if (outputChannel) { outputChannel.dispose(); }
}

module.exports = { activate, deactivate };
