pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Shared UI state, so any component can open the Claude panel etc.
Singleton {
    property bool claudeOpen: false
    property bool screensaver: false
    property bool cheatsheetOpen: false
    property bool overviewOpen: false

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
}
