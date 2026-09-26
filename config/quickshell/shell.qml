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

    // qs ipc call claude toggle  (Super+A)
    IpcHandler {
        target: "claude"
        function toggle(): void { ShellState.claudeOpen = !ShellState.claudeOpen }
        function open(): void { ShellState.claudeOpen = true }
        function close(): void { ShellState.claudeOpen = false }
    }

    // qs ipc call screensaver start|stop  (hypridle)
    IpcHandler {
        target: "screensaver"
        function start(): void { ShellState.screensaver = true }
        function stop(): void { ShellState.screensaver = false }
    }
}
