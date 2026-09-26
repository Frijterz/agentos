pragma Singleton

import QtQuick
import Quickshell

// Shared UI state, so any component can open the Claude panel etc.
Singleton {
    property bool claudeOpen: false
    property bool screensaver: false
    property bool cheatsheetOpen: false
    property bool overviewOpen: false
}
