// agentos shell. LIVE: Quickshell hot-reloads on save.
// Errors: journalctl --user -u quickshell -f
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    Variants {
        model: Quickshell.screens
        Background {}
    }

    Variants {
        model: Quickshell.screens
        Bar {}
    }

    Variants {
        model: Quickshell.screens
        Screensaver {}
    }

    ClaudePanel {}

    Osd {}

    Cheatsheet {}

    Overview {}

    // System password prompts (polkit agent lives in ShellState).
    PolkitDialog {}

    SystemMenu {}

    // Notification pop-ups (the daemon itself is the Notifs singleton).
    Toasts {}

    // qs ipc call notifications list: the history as text (for the panel's Claude,
    // behind an approval card like the clipboard).
    IpcHandler {
        target: "notifications"
        function list(): string {
            return Notifs.history.map(n => "[" + (n.appName || "?") + "] " + n.summary + (n.body ? ": " + n.body.replace(/<[^>]*>/g, "") : "")).join("\n");
        }
    }

    Launcher {}

    // qs ipc call launcher toggle  (Super+Space)
    IpcHandler {
        target: "launcher"
        function toggle(): void { ShellState.launcherOpen = !ShellState.launcherOpen }
    }

    // qs ipc call system toggle  (Super+Escape, or the status button in the bar)
    IpcHandler {
        target: "system"
        function toggle(): void { ShellState.systemOpen = !ShellState.systemOpen }
    }

    // qs ipc call overview toggle  (Super+Tab)
    IpcHandler {
        target: "overview"
        function toggle(): void { ShellState.overviewOpen = !ShellState.overviewOpen }
    }

    // qs ipc call cheatsheet toggle  (Super+/)
    IpcHandler {
        target: "cheatsheet"
        function toggle(): void { ShellState.cheatsheetOpen = !ShellState.cheatsheetOpen }
    }

    // qs ipc call claude toggle  (Super+A)
    IpcHandler {
        target: "claude"
        function toggle(): void { ShellState.claudeOpen = !ShellState.claudeOpen }
        function open(): void { ShellState.claudeOpen = true }
        function close(): void { ShellState.claudeOpen = false }
        function isOpen(): bool { return ShellState.claudeOpen }
    }

    // qs ipc call screensaver start|stop  (hypridle)
    IpcHandler {
        target: "screensaver"
        function start(): void { ShellState.screensaver = true }
        function stop(): void { ShellState.screensaver = false }
    }
}
