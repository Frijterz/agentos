import QtQuick
import Quickshell
import Quickshell.Wayland

// The warning before the screensaver: hypridle calls `qs ipc call screensaver dim` 15 s
// ahead, and the screen fades slowly toward dark; any activity (hypridle's resume)
// brings it straight back. Click-through and never takes the keyboard, so it can't
// trap you, and it clears itself after 30 s whatever happens.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: ShellState.dimming || shade.opacity > 0
    mask: Region {} // clicks and keys go to your windows as usual

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "agentos-dim"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        id: shade
        anchors.fill: parent
        color: "black"
        opacity: 0
    }

    // Slow in (almost the whole 15 s), quick out (you're back).
    NumberAnimation {
        id: fadeIn
        target: shade
        property: "opacity"
        to: 0.7
        duration: 14000
        easing.type: Easing.InQuad
    }
    NumberAnimation {
        id: fadeOut
        target: shade
        property: "opacity"
        to: 0
        duration: 250
        easing.type: Easing.OutCubic
    }
    Connections {
        target: ShellState
        function onDimmingChanged() {
            fadeIn.stop();
            fadeOut.stop();
            (ShellState.dimming ? fadeIn : fadeOut).start();
        }
    }

    Timer {
        running: ShellState.dimming
        interval: 30000
        onTriggered: ShellState.dimming = false
    }
}
