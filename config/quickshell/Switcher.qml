import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Window switcher (Alt+Tab): your windows, most recently used first, the previous one
// selected. Hold Alt and press Tab to step (Shift+Tab back), let go of Alt to switch. A
// quick Alt+Tab flips between your last two windows. Arrows, Enter or a click work too;
// Esc cancels. Previews are captured once on open (not live: cheap on battery).
PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: ShellState.switcherOpen || strip.opacity > 0
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "agentos-switcher"
    WlrLayershell.keyboardFocus: ShellState.switcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Most recently used first (Hyprland's focus history; 0 is the active window).
    readonly property var windows: Hyprland.toplevels.values.filter(t => t.lastIpcObject?.focusHistoryID !== undefined && t.lastIpcObject.focusHistoryID >= 0).sort((a, b) => a.lastIpcObject.focusHistoryID - b.lastIpcObject.focusHistoryID)
    property int selected: 0

    // Keep the focus history fresh, so the order is right the moment Alt+Tab opens.
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            Hyprland.refreshToplevels();
        }
    }

    function step(delta) {
        if (!windows.length)
            return;
        if (!ShellState.switcherOpen) {
            Hyprland.refreshToplevels();
            selected = windows.length > 1 ? (delta > 0 ? 1 : windows.length - 1) : 0;
            ShellState.switcherOpen = true;
            keys.forceActiveFocus();
            return;
        }
        selected = (selected + delta + windows.length) % windows.length;
    }

    // Close first, focus after: releasing our keyboard focus makes Hyprland refocus the
    // previous window, which would undo a switch made while we were still open.
    property string pendingAddress: ""
    Timer {
        id: focusLater
        interval: 60
        onTriggered: Hyprland.dispatch("focuswindow address:0x" + root.pendingAddress)
    }
    function commit() {
        if (!ShellState.switcherOpen)
            return;
        const w = windows[selected];
        ShellState.switcherOpen = false;
        if (w) {
            pendingAddress = w.address;
            focusLater.restart();
        }
    }
    function cancel() {
        ShellState.switcherOpen = false;
    }

    IpcHandler {
        target: "switcher"
        function next(): void { root.step(1) }
        function prev(): void { root.step(-1) }
        function commit(): void { root.commit() }
    }

    Item {
        id: keys
        focus: true
        // Alt+Tab itself reaches us through Hyprland's binds; these cover the rest.
        Keys.onPressed: event => {
            const k = event.key;
            if (k === Qt.Key_Escape)
                root.cancel();
            else if (k === Qt.Key_Return || k === Qt.Key_Enter)
                root.commit();
            else if (k === Qt.Key_Right || k === Qt.Key_Tab)
                root.step(1);
            else if (k === Qt.Key_Left || k === Qt.Key_Backtab)
                root.step(-1);
        }
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt && !event.isAutoRepeat)
                root.commit();
        }
    }

    // Dimmed backdrop, blurred by Hyprland (layerrule, like the overview); a click cancels.
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bg, 0.45)
        opacity: strip.opacity
        MouseArea {
            anchors.fill: parent
            enabled: ShellState.switcherOpen
            onClicked: root.cancel()
        }
    }

    // ── The strip of window cards ──
    Rectangle {
        id: strip

        readonly property int cardW: Math.min(264, (root.width - 120) / Math.max(1, root.windows.length) - 10)
        readonly property int previewH: Math.round(cardW * 0.62)

        anchors.centerIn: parent
        width: row.implicitWidth + 28
        height: row.implicitHeight + 28
        radius: Theme.radius
        color: Theme.alpha(Theme.bg, 0.88)
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.3)

        opacity: ShellState.switcherOpen ? 1 : 0
        scale: ShellState.switcherOpen ? 1 : 0.97
        Behavior on opacity {
            NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic }
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 10

            Repeater {
                model: root.windows

                delegate: Rectangle {
                    id: card

                    required property var modelData
                    required property int index
                    readonly property var ipc: modelData.lastIpcObject
                    readonly property bool current: index === root.selected
                    readonly property var entry: DesktopEntries.heuristicLookup(ipc.class ?? "")

                    width: strip.cardW
                    height: strip.previewH + 44
                    radius: Theme.radiusSmall
                    color: current ? Theme.alpha(Theme.accent, 0.14) : area.containsMouse ? Theme.alpha(Theme.fg, 0.06) : "transparent"
                    border.width: current ? 1 : 0
                    border.color: Theme.alpha(Theme.accent, 0.55)

                    // Preview, fitted to the window's shape.
                    Item {
                        id: frame
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 16
                        height: strip.previewH - 8

                        readonly property real ratio: (card.ipc.size?.[0] ?? 16) / Math.max(1, card.ipc.size?.[1] ?? 10)
                        readonly property real w: Math.min(width, height * ratio)
                        readonly property real h: w / ratio

                        Rectangle {
                            anchors.centerIn: parent
                            width: frame.w
                            height: frame.h
                            radius: 3
                            color: Theme.alpha(Theme.fg, 0.04)
                            border.width: 1
                            border.color: card.current ? Theme.alpha(Theme.accent, 0.6) : Theme.alpha(Theme.fg, 0.14)
                            clip: true

                            ScreencopyView {
                                anchors.fill: parent
                                anchors.margins: 1
                                // Captured once per opening; nothing while closed.
                                captureSource: ShellState.switcherOpen ? card.modelData.wayland : null
                                live: false
                                // Shrinking a whole window ~7x in one step makes text grainy:
                                // render at 4x into a mipmapped layer, then scale down smoothly.
                                layer.enabled: true
                                layer.textureSize: Qt.size(width * 4, height * 4)
                                layer.mipmap: true
                                layer.smooth: true
                            }
                        }
                        // Workspace number, top left.
                        Text {
                            x: (frame.width - frame.w) / 2 + 6
                            y: (frame.height - frame.h) / 2 + 4
                            text: card.ipc.workspace?.name ?? ""
                            color: Theme.fg
                            opacity: 0.6
                            style: Text.Outline
                            styleColor: Theme.alpha(Theme.bg, 0.8)
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                        }
                    }

                    // App icon and title.
                    Row {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 20
                        spacing: 7

                        Image {
                            id: appIcon
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            source: card.entry?.icon ? Quickshell.iconPath(card.entry.icon, true) : ""
                            sourceSize.width: 36
                            sourceSize.height: 36
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - (appIcon.visible ? 25 : 0)
                            text: card.modelData.title || card.entry?.name || (card.ipc.class ?? "")
                            elide: Text.ElideRight
                            color: card.current ? Theme.accent : Theme.alpha(Theme.fg, 0.7)
                            font.family: Theme.fontSans
                            font.pixelSize: 12
                            font.weight: card.current ? Font.DemiBold : Font.Normal
                        }
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selected = card.index
                        onClicked: root.commit()
                    }
                }
            }
        }
    }
}
