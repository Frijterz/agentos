import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Workspace overview (Super+Tab). Each tile shows its windows at their real position,
// with a preview captured once on open (not live: cheap on battery).
// Click a workspace or window to go there, drag a window onto another workspace to
// move it. Arrows / 1-9 / Enter work too; Esc or a click on the backdrop closes.
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
    visible: ShellState.overviewOpen || grid.opacity > 0
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "agentos-overview"
    WlrLayershell.keyboardFocus: ShellState.overviewOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property real monX: monitor?.lastIpcObject?.x ?? 0
    readonly property real monY: monitor?.lastIpcObject?.y ?? 0

    // At least 5 workspaces, more if one up to 10 is in use.
    readonly property int count: Math.max(5, ...Hyprland.workspaces.values.map(w => w.id).filter(id => id > 0 && id <= 10))
    readonly property int cols: 5
    readonly property int gap: 20
    readonly property real tileW: Math.min(340, (width - 120 - (cols - 1) * gap) / cols)
    readonly property real k: tileW / Math.max(1, screen.width) // screen → tile scale
    readonly property real tileH: screen.height * k

    property int selected: 1

    function close() {
        ShellState.overviewOpen = false;
    }

    // Close first, dispatch after: releasing our exclusive keyboard focus makes Hyprland
    // refocus the previous window (and jump back to its workspace), undoing a switch
    // made while we were still open.
    property string pendingDispatch: ""

    Timer {
        id: dispatchLater
        interval: 60
        onTriggered: Hyprland.dispatch(root.pendingDispatch)
    }

    function closeThen(cmd) {
        close();
        pendingDispatch = cmd;
        dispatchLater.restart();
    }

    function goTo(ws) {
        closeThen("workspace " + ws);
    }

    function focusWindow(addr) {
        closeThen("focuswindow address:0x" + addr);
    }

    function moveWindow(addr, ws) {
        Hyprland.dispatch("movetoworkspacesilent " + ws + ",address:0x" + addr);
        Hyprland.refreshToplevels();
    }

    Connections {
        target: ShellState
        function onOverviewOpenChanged() {
            if (ShellState.overviewOpen) {
                Hyprland.refreshToplevels();
                root.selected = root.monitor?.activeWorkspace?.id ?? 1;
                keys.forceActiveFocus();
            }
        }
    }

    // Keyboard navigation.
    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            const k = event.key;
            if (k === Qt.Key_Escape || k === Qt.Key_Tab)
                root.close();
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)
                root.goTo(root.selected);
            else if (k === Qt.Key_Left)
                root.selected = Math.max(1, root.selected - 1);
            else if (k === Qt.Key_Right)
                root.selected = Math.min(root.count, root.selected + 1);
            else if (k === Qt.Key_Up)
                root.selected = Math.max(1, root.selected - root.cols);
            else if (k === Qt.Key_Down)
                root.selected = Math.min(root.count, root.selected + root.cols);
            else if (k >= Qt.Key_1 && k <= Qt.Key_9)
                root.goTo(k - Qt.Key_0);
            else
                return;
            event.accepted = true;
        }
    }

    // Dimmed backdrop; clicking it closes.
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bg, 0.45)
        opacity: grid.opacity

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Grid {
        id: grid

        anchors.centerIn: parent
        columns: root.cols
        spacing: root.gap

        opacity: ShellState.overviewOpen ? 1 : 0
        scale: ShellState.overviewOpen ? 1 : 0.96
        Behavior on opacity {
            NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: root.count

            delegate: Rectangle {
                id: tile

                required property int index
                readonly property int wsId: index + 1
                readonly property bool current: root.monitor?.activeWorkspace?.id === wsId

                width: root.tileW
                height: root.tileH
                radius: Theme.radius
                clip: true
                color: Theme.alpha(Theme.bg, 0.6)
                border.width: wsId === root.selected ? 2 : 1
                border.color: drop.containsDrag ? Theme.accent2 : wsId === root.selected ? Theme.accent : Theme.alpha(Theme.fg, current ? 0.3 : 0.1)

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.selected = tile.wsId
                    onClicked: root.goTo(tile.wsId)
                }

                DropArea {
                    id: drop
                    anchors.fill: parent
                    onDropped: dropEvent => root.moveWindow(dropEvent.source.addr, tile.wsId)
                }

                // Windows at their real position, scaled down.
                Repeater {
                    model: Hyprland.toplevels.values.filter(t => t.workspace?.id === tile.wsId && t.lastIpcObject?.at)

                    delegate: Item {
                        id: win

                        required property var modelData
                        readonly property var ipc: modelData.lastIpcObject
                        readonly property string addr: modelData.address

                        x: (ipc.at[0] - root.monX) * root.k
                        y: (ipc.at[1] - root.monY) * root.k
                        width: Math.max(8, ipc.size[0] * root.k)
                        height: Math.max(8, ipc.size[1] * root.k)

                        ScreencopyView {
                            anchors.fill: parent
                            // Capture once per opening; null while closed.
                            captureSource: ShellState.overviewOpen ? win.modelData.wayland : null
                            live: false
                            // Smooth downscaling (see Switcher.qml): 4x, mipmapped.
                            layer.enabled: true
                            layer.textureSize: Qt.size(width * 4, height * 4)
                            layer.mipmap: true
                            layer.smooth: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: "transparent"
                            border.width: 1
                            border.color: winArea.containsMouse ? Theme.accent : Theme.alpha(Theme.fg, 0.2)
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.margins: 4
                            width: Math.min(parent.width - 8, label.implicitWidth + 10)
                            height: label.implicitHeight + 4
                            radius: 5
                            color: Theme.alpha(Theme.bg, 0.8)
                            visible: parent.width > 40

                            Text {
                                id: label
                                anchors.centerIn: parent
                                width: parent.width - 10
                                text: (win.ipc.class ?? "").split(".").pop()
                                elide: Text.ElideRight
                                color: Theme.fg
                                font.family: Theme.fontSans
                                font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            id: winArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                            drag.target: ghost
                            onEntered: root.selected = tile.wsId
                            onPressed: mouse => {
                                const p = win.mapToItem(root.contentItem, 0, 0);
                                ghost.x = p.x;
                                ghost.y = p.y;
                                ghost.width = win.width;
                                ghost.height = win.height;
                                ghost.addr = win.addr;
                                ghost.label = label.text;
                                ghost.source = winArea;
                            }
                            onReleased: {
                                if (drag.active)
                                    ghost.Drag.drop();
                                ghost.source = null;
                            }
                            onClicked: root.focusWindow(win.addr)
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 8
                    text: tile.wsId
                    color: tile.current ? Theme.accent : Theme.alpha(Theme.fg, 0.6)
                    font.family: Theme.fontSans
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    // What you drag: a stand-in for the window, so it can leave its clipped tile.
    Rectangle {
        id: ghost

        property string addr
        property string label
        property var source: null

        visible: source?.drag.active ?? false
        radius: 6
        color: Theme.alpha(Theme.accent, 0.35)
        border.width: 2
        border.color: Theme.accent
        Drag.active: visible
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        Text {
            anchors.centerIn: parent
            text: ghost.label
            color: Theme.fg
            font.family: Theme.fontSans
            font.pixelSize: 11
        }
    }
}
