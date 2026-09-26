import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

// System password prompt (polkit), in the shell's own style. Apply-card prompts for
// agentos-switch@ are shown inside the Claude panel instead (ClaudePanel.qml).
PanelWindow {
    id: root

    readonly property var flow: ShellState.authFlow
    readonly property bool shown: flow !== null && !ShellState.authIsApply

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: shown || card.opacity > 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "agentos-polkit"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: if (shown) password.focusField()

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bg, 0.45)
        opacity: card.opacity
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: 420
        height: col.implicitHeight + 48
        radius: 22
        color: Theme.alpha(Theme.bg, 0.8)
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.5)

        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.97
        Behavior on opacity {
            NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic }
        }

        Column {
            id: col

            anchors.fill: parent
            anchors.margins: 24
            spacing: 14

            Row {
                spacing: 10
                Text {
                    text: "󰌾"
                    color: Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: 20
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Authentication required"
                    color: Theme.fg
                    font.family: Theme.fontSans
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
            }

            Text {
                width: parent.width
                text: root.flow?.message ?? ""
                wrapMode: Text.Wrap
                color: Theme.alpha(Theme.fg, 0.75)
                font.family: Theme.fontSans
                font.pixelSize: 13
            }

            AuthField {
                id: password
                width: parent.width
                flow: root.flow
            }
        }
    }
}
