import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Slide-in Claude panel (Super+A or the ✦ button, Esc to close).
// Phase 1: questions go to `agentos-ask`, which runs Claude Code headless inside
// the agentos repo; it may edit and build there, never switch.
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
    // Claude Code session of this conversation; follow-ups resume it (memory).
    property string sessionId: ""

    function send(prompt) {
        if (!prompt.trim() || busy)
            return;
        messages.append({ who: "you", body: prompt });
        busy = true;
        ask.command = sessionId ? ["agentos-ask", "--resume", sessionId, prompt] : ["agentos-ask", prompt];
        ask.running = true;
    }

    function newChat() {
        if (busy)
            return;
        messages.clear();
        sessionId = "";
    }

    // Streamed text goes into the last Claude bubble, or a new one after a tool line.
    function appendText(chunk) {
        const i = messages.count - 1;
        if (i < 0 || messages.get(i).who !== "claude")
            messages.append({ who: "claude", body: chunk });
        else
            messages.setProperty(i, "body", messages.get(i).body + chunk);
    }

    function toolLabel(name, input) {
        const detail = input.command ?? input.file_path ?? input.pattern ?? input.path ?? "";
        return name + (detail ? " · " + detail : "");
    }

    // One stream-json event from agentos-ask (see `claude -p --output-format stream-json`).
    function handle(ev) {
        if (ev.session_id)
            sessionId = ev.session_id;
        if (ev.type === "stream_event") {
            const e = ev.event;
            if (e.type === "content_block_delta" && e.delta.type === "text_delta")
                appendText(e.delta.text);
        } else if (ev.type === "assistant") {
            for (const block of ev.message.content)
                if (block.type === "tool_use")
                    messages.append({ who: "tool", body: toolLabel(block.name, block.input) });
        } else if (ev.type === "result") {
            for (const d of ev.permission_denials ?? [])
                messages.append({ who: "note", body: "Not allowed: " + toolLabel(d.tool_name, d.tool_input) });
            if (ev.is_error)
                messages.append({ who: "note", body: "Error: " + (ev.result ?? ev.subtype) });
        }
    }

    ListModel {
        id: messages
    }

    Process {
        id: ask

        stdout: SplitParser {
            onRead: data => {
                try {
                    root.handle(JSON.parse(data));
                } catch (e) {
                    console.warn("agentos-ask: unparsed line:", data);
                }
            }
        }
        stderr: SplitParser {
            onRead: data => console.warn("agentos-ask:", data)
        }
        onExited: (code, status) => {
            if (code !== 0)
                messages.append({ who: "note", body: "agentos-ask exited with code " + code + "; see journalctl --user -u quickshell" });
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
                // New chat: forget the session so Claude starts fresh.
                Text {
                    text: "New chat"
                    visible: messages.count > 0
                    color: newChatArea.containsMouse && !root.busy ? Theme.fg : Theme.alpha(Theme.fg, 0.45)
                    font.family: Theme.fontSans
                    font.pixelSize: 12
                    MouseArea {
                        id: newChatArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: root.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: root.newChat()
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

                // who: "you" | "claude" (bubbles) or "tool" | "note" (small status lines).
                delegate: Rectangle {
                    required property string who
                    required property string body
                    readonly property bool line: who === "tool" || who === "note"

                    width: ListView.view.width
                    height: txt.implicitHeight + (line ? 4 : 20)
                    radius: 14
                    color: line ? "transparent" : who === "you" ? Theme.alpha(Theme.accent, 0.14) : Theme.alpha(Theme.fg, 0.05)

                    Text {
                        id: txt
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: line ? 2 : 10
                        anchors.leftMargin: 10
                        text: who === "tool" ? "⚙ " + body : who === "note" ? "⚠ " + body : body
                        textFormat: who === "claude" ? Text.MarkdownText : Text.PlainText
                        wrapMode: line ? Text.WrapAnywhere : Text.Wrap
                        maximumLineCount: line ? 3 : 100000
                        elide: Text.ElideRight
                        color: who === "note" ? Theme.warn : line ? Theme.alpha(Theme.fg, 0.55) : Theme.fg
                        font.family: line ? Theme.fontMono : Theme.fontSans
                        font.pixelSize: line ? 11 : 13
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
