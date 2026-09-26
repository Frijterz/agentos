import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Wayland

// Floating translucent pill bar: workspaces · clock · battery + Claude.
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 44
    color: "transparent"
    WlrLayershell.namespace: "agentos-bar"

    readonly property var monitor: Hyprland.monitorFor(screen)

    Rectangle {
        id: pill

        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 8
        radius: height / 2
        color: Theme.alpha(Theme.bg, 0.62)
        border.width: 1
        border.color: Theme.alpha(Theme.fg, 0.08)

        // Fade in when the shell (re)loads.
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity {
            NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic }
        }

        // ── Workspaces: at least 5 dots, more if you use them ──
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: Math.max(5, ...Hyprland.workspaces.values.map(w => w.id).filter(id => id > 0 && id <= 10))

                delegate: Rectangle {
                    id: dot

                    required property int index
                    readonly property int wsId: index + 1
                    readonly property bool active: bar.monitor?.activeWorkspace?.id === wsId
                    readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === wsId)

                    anchors.verticalCenter: parent.verticalCenter
                    width: active ? 28 : 9
                    height: 9
                    radius: height / 2
                    color: active ? Theme.accent : Theme.alpha(Theme.fg, occupied ? 0.55 : 0.16)

                    Behavior on width {
                        NumberAnimation { duration: Theme.medium; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                    }
                    Behavior on color {
                        ColorAnimation { duration: Theme.medium }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch("workspace " + dot.wsId)
                    }
                }
            }
        }

        // ── Clock ──
        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        Text {
            anchors.centerIn: parent
            text: Qt.formatDateTime(clock.date, "ddd d MMM   HH:mm")
            color: Theme.fg
            font.family: Theme.fontSans
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        // ── Right side ──
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Text {
                readonly property var dev: UPower.displayDevice
                // Quickshell reports 0–1 (verified on the UM3406).
                readonly property real pct: dev.percentage * 100

                visible: dev.isLaptopBattery
                anchors.verticalCenter: parent.verticalCenter
                text: (UPower.onBattery ? "" : "⚡ ") + Math.round(pct) + "%"
                color: UPower.onBattery && pct < 15 ? Theme.warn : Theme.fg
                font.family: Theme.fontSans
                font.pixelSize: 13
            }

            // Claude button: same as Super+A.
            Rectangle {
                width: 30
                height: 30
                radius: 15
                anchors.verticalCenter: parent.verticalCenter
                color: ShellState.claudeOpen ? Theme.accent2 : hover.hovered ? Theme.alpha(Theme.accent2, 0.25) : "transparent"

                Behavior on color {
                    ColorAnimation { duration: Theme.fast }
                }

                Text {
                    anchors.centerIn: parent
                    text: "✦"
                    color: ShellState.claudeOpen ? Theme.bg : Theme.accent2
                    font.pixelSize: 16
                }

                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: ShellState.claudeOpen = !ShellState.claudeOpen
                }
            }
        }
    }
}
