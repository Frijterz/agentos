pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit

// Shared UI state, so any component can open the Claude panel etc.
Singleton {
    property bool claudeOpen: false
    property bool screensaver: false
    property bool dimming: false // the fade before the screensaver (Dim.qml)
    onScreensaverChanged: dimming = false // it takes over, or you're back
    property bool cheatsheetOpen: false
    property bool overviewOpen: false
    property bool systemOpen: false
    property bool launcherOpen: false
    property bool calendarOpen: false
    property bool clipboardOpen: false
    property bool switcherOpen: false
    // Background day/night preview (qs ipc call background preview 0…1); -1 follows the sun.
    property real daylightPreview: -1
    // A question for the Claude panel (from the launcher's "Ask Claude"); it sends it.
    property string claudeQuestion: ""

    // Desktop mode, written by agentos-mode (bar chip, Super+M, Claude).
    property string mode: "normal"

    FileView {
        id: modeFile
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/agentos/mode"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: mode = text().trim() || "normal"
        onLoadFailed: {
            mode = "normal";
            retry.start(); // not written yet (e.g. we started before agentos-mode-reset)
        }
    }

    Timer {
        id: retry
        interval: 5000
        onTriggered: modeFile.reload()
    }

    // Polkit agent: the shell draws password prompts itself, in the Claude panel's
    // Apply card for Apply / Undo, otherwise in PolkitDialog. A session has one agent;
    // registration is retried because on a hot reload the old instance still holds it
    // for a moment (and hyprpolkitagent did, before it was removed).
    readonly property var authFlow: polkit.item?.flow ?? null
    // "Is this our Apply / Undo?": systemd asks for manage-units and either names the
    // unit ("…to start 'agentos-switch@…'") or the panel is running that start right now.
    property bool applyRunning: false
    readonly property bool authIsApply: authFlow !== null && authFlow.actionId === "org.freedesktop.systemd1.manage-units" && (applyRunning || String(authFlow.message).indexOf("agentos-switch@") >= 0)

    LazyLoader {
        id: polkit
        active: false
        component: PolkitAgent {}
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: {
            if (!polkit.active) {
                polkit.active = true;
            } else if (!polkit.item?.isRegistered) {
                polkit.active = false; // try again next tick
                interval = 10000;
            } else {
                stop();
            }
        }
    }
}
