import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland

// Notification pop-ups, top right under the bar (left of the Claude panel or system
// menu when one is open). Click: the notification's default action. They time out
// after 6 s, 15 s with buttons (or what the app asked), not while the pointer is on
// them; critical ones stay until dismissed. Data and do-not-disturb: Notifs.qml.
PanelWindow {
    id: root

    anchors {
        top: true
        right: true
    }
    margins {
        top: 52
        right: 12 + (ShellState.claudeOpen ? 472 : ShellState.systemOpen ? 392 : 0)
    }
    implicitWidth: 380
    implicitHeight: Math.max(1, stack.implicitHeight)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: Notifs.toasts.length > 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "agentos-toasts"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Column {
        id: stack
        width: parent.width
        spacing: 8

        Repeater {
            model: Notifs.toasts

            delegate: Rectangle {
                id: toast

                required property var modelData
                readonly property var n: modelData
                readonly property bool critical: n.urgency === NotificationUrgency.Critical
                readonly property var extraActions: n.actions.filter(a => a.identifier !== "default")

                width: stack.width
                height: content.implicitHeight + 24
                radius: 16
                color: Theme.alpha(Theme.bg, 0.9)
                border.width: 1
                border.color: critical ? Theme.warn : Theme.alpha(Theme.accent, 0.3)

                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity {
                    NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic }
                }

                // 6 s, or 15 s when it has buttons (it's asking you something), unless
                // the app set its own timeout.
                Timer {
                    interval: toast.n.expireTimeout > 0 ? toast.n.expireTimeout : toast.extraActions.length > 0 ? 15000 : 6000
                    running: !toast.critical && !hover.containsMouse
                    onTriggered: Notifs.hideToast(toast.n)
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.activate(toast.n)
                }

                Row {
                    id: content

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 12

                    NotifIcon {
                        notification: toast.n
                        size: 38
                    }

                    Column {
                        width: parent.width - 38 - 12 - 20
                        spacing: 3

                        Text {
                            width: parent.width
                            text: (toast.n.appName || "notification").toUpperCase()
                            elide: Text.ElideRight
                            color: toast.critical ? Theme.warn : Theme.accent
                            opacity: 0.8
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            font.letterSpacing: 1.5
                        }
                        Text {
                            width: parent.width
                            text: toast.n.summary
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            color: Theme.fg
                            font.family: Theme.fontSans
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: toast.n.body
                            textFormat: Text.StyledText
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            color: Theme.alpha(Theme.fg, 0.7)
                            font.family: Theme.fontSans
                            font.pixelSize: 12
                            onLinkActivated: link => Qt.openUrlExternally(link)
                        }
                        // The app's own buttons (e.g. "Reply", "Open").
                        Row {
                            visible: toast.extraActions.length > 0
                            spacing: 6
                            topPadding: 4
                            Repeater {
                                model: toast.extraActions
                                delegate: Rectangle {
                                    required property var modelData
                                    width: actionText.implicitWidth + 20
                                    height: 26
                                    radius: 8
                                    color: actionArea.containsMouse ? Theme.alpha(Theme.accent, 0.3) : Theme.alpha(Theme.fg, 0.08)
                                    Text {
                                        id: actionText
                                        anchors.centerIn: parent
                                        text: modelData.text
                                        color: Theme.fg
                                        font.family: Theme.fontSans
                                        font.pixelSize: 12
                                    }
                                    MouseArea {
                                        id: actionArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            modelData.invoke();
                                            Notifs.dismiss(toast.n);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Close: gone from the pop-ups and the history.
                LineIcon {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 8
                    size: 14
                    name: "x"
                    opacity: closeArea.containsMouse ? 1 : 0.4
                    glyph: "󰅖"
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.dismiss(toast.n)
                    }
                }
            }
        }
    }
}
