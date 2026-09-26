import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Slide-in Claude panel (Super+A or the ✦ button, Esc to close).
// Phase 1: read-only. Questions go to `agentos-ask`, which runs Claude Code
// headless inside the agentos repo with read-only tools.
PanelWindow {
    id: root

    anchors {
        top: true
        right: true
        bottom: true
    }
    margins {
        top: 52
        right: 12
        bottom: 12
    }
    implicitWidth: 460
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    // Stay mapped until the close animation has finished.
    visible: ShellState.claudeOpen || card.opacity > 0

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "agentos-claude"
    WlrLayershell.keyboardFocus: ShellState.claudeOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool busy: false

    function send(prompt) {
        if (!prompt.trim() || busy)
            return;
        messages.append({ who: "you", body: prompt });
        messages.append({ who: "claude", body: "" });
        busy = true;
        ask.command = ["agentos-ask", prompt];
        ask.running = true;
    }

    function appendToLast(chunk) {
        const i = messages.count - 1;
        messages.setProperty(i, "body", messages.get(i).body + chunk);
    }

    ListModel {
        id: messages
    }

    Process {
        id: ask

        stdout: SplitParser {
            onRead: data => root.appendToLast(data + "\n")
        }
        stderr: SplitParser {
            onRead: data => console.warn("agentos-ask:", data)
        }
        onExited: (code, status) => {
            if (code !== 0)
                root.appendToLast("\n_(agentos-ask exited with code " + code + "; see journalctl --user -u quickshell)_");
            root.busy = false;
            input.forceActiveFocus();
        }
    }

    Connections {
        target: ShellState
        function onClaudeOpenChanged() {
            if (ShellState.claudeOpen)
                input.forceActiveFocus();
        }
    }

    Rectangle {
        id: card

        width: parent.width
        height: parent.height
        radius: 20
        color: Theme.alpha(Theme.bg, 0.86)
        border.width: 1
        border.color: Theme.alpha(Theme.fg, 0.08)

        opacity: ShellState.claudeOpen ? 1 : 0
        x: ShellState.claudeOpen ? 0 : 48
        Behavior on opacity {
            NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic }
        }
        Behavior on x {
            NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // Header
            RowLayout {
                spacing: 10

                Text {
                    text: "✦"
                    color: Theme.accent2
                    font.pixelSize: 20
                }
                Text {
                    Layout.fillWidth: true
                    text: "Claude"
                    color: Theme.fg
                    font.family: Theme.fontSans
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }
                // Pulsing dot while Claude is thinking.
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.accent2
                    visible: root.busy
                    SequentialAnimation on opacity {
                        running: root.busy
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.2; duration: 600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
                    }
                }
            }

            // Conversation
            ListView {
                id: list

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 10
                model: messages
                onContentHeightChanged: Qt.callLater(positionViewAtEnd)

                delegate: Rectangle {
                    required property string who
                    required property string body

                    width: ListView.view.width
                    height: txt.implicitHeight + 20
                    radius: 14
                    color: who === "you" ? Theme.alpha(Theme.accent, 0.14) : Theme.alpha(Theme.fg, 0.05)

                    Text {
                        id: txt
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        text: body.length ? body : "…"
                        textFormat: who === "claude" ? Text.MarkdownText : Text.PlainText
                        wrapMode: Text.Wrap
                        color: Theme.fg
                        font.family: Theme.fontSans
                        font.pixelSize: 13
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    horizontalAlignment: Text.AlignHCenter
                    text: "Ask about your system, your config,\nor how to change something."
                    color: Theme.alpha(Theme.fg, 0.4)
                    font.family: Theme.fontSans
                    font.pixelSize: 13
                }
            }

            TextField {
                id: input

                Layout.fillWidth: true
                enabled: !root.busy
                placeholderText: root.busy ? "Thinking…" : "Ask Claude…"
                placeholderTextColor: Theme.alpha(Theme.fg, 0.4)
                color: Theme.fg
                font.family: Theme.fontSans
                font.pixelSize: 14
                leftPadding: 14
                rightPadding: 14
                topPadding: 10
                bottomPadding: 10

                background: Rectangle {
                    radius: 12
                    color: Theme.alpha(Theme.fg, 0.06)
                    border.width: 1
                    border.color: input.activeFocus ? Theme.accent : "transparent"
                    Behavior on border.color {
                        ColorAnimation { duration: Theme.fast }
                    }
                }

                onAccepted: {
                    root.send(text);
                    text = "";
                }
                Keys.onEscapePressed: ShellState.claudeOpen = false
            }
        }
    }
}
