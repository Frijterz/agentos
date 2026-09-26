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
    // OnDemand, not Exclusive: other windows (and the polkit password dialog) can still
    // take focus. While a switch waits for the password, let go entirely.
    WlrLayershell.keyboardFocus: ShellState.claudeOpen && !switchProc.running ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property bool busy: false
    // Claude Code session of this conversation; follow-ups resume it (memory).
    property string sessionId: ""

    // Every entry carries all roles; ListModel wants a consistent shape.
    // rid/state are only used by approval cards.
    function add(who, body, rid, state) {
        messages.append({ who, body, rid: rid ?? "", state: state ?? "" });
    }

    function send(prompt) {
        if (!prompt.trim() || busy)
            return;
        add("you", prompt);
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
            add("claude", chunk);
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
                    add("tool", toolLabel(block.name, block.input));
        } else if (ev.type === "result") {
            // Includes deny rules (sudo, switch, push) that never reach a card.
            for (const d of ev.permission_denials ?? [])
                add("note", "Not allowed: " + toolLabel(d.tool_name, d.tool_input));
            if (ev.is_error)
                add("note", "Error: " + (ev.result ?? ev.subtype));
        }
    }

    // ── Approval cards (agentos-approve hook → socket → here) ──
    // Open connections waiting for a click, by request id.
    property var pending: ({})
    property int nextRid: 0

    // Show what will actually run, not Claude's description of it.
    function describe(req) {
        const t = req.tool_name, i = req.tool_input ?? {};
        if (t === "Bash")
            return "$ " + i.command;
        if (t === "Write")
            return "Write " + i.file_path + "\n" + String(i.content ?? "").slice(0, 400);
        if (t === "Edit")
            return "Edit " + i.file_path + "\n− " + String(i.old_string ?? "").slice(0, 200) + "\n+ " + String(i.new_string ?? "").slice(0, 200);
        if (i.file_path || i.url || i.path)
            return t + " " + (i.file_path ?? i.url ?? i.path);
        return t + " " + JSON.stringify(i).slice(0, 400);
    }

    function request(conn, line) {
        let req;
        try {
            req = JSON.parse(line);
        } catch (e) {
            conn.write("deny\n");
            conn.flush();
            return;
        }
        const rid = String(nextRid++);
        pending[rid] = conn;
        add("approve", describe(req), rid, "waiting");
        ShellState.claudeOpen = true;
    }

    // ── Apply cards (agentos-pending → Apply → agentos-switch@<hash>, your password) ──
    // Hashes already offered, so a dismissed build isn't offered again.
    property var offered: ({})

    function checkPending() {
        if (!pendingProc.running)
            pendingProc.running = true;
    }

    function offerBuild(json) {
        let b;
        try {
            b = JSON.parse(json);
        } catch (e) {
            return;
        }
        if (offered[b.hash])
            return;
        offered[b.hash] = true;
        let text = b.diff;
        if (b.changes)
            text += "\n\nUncommitted:\n" + b.changes;
        if (b.unpushed)
            text += "\n\nNot pushed:\n" + b.unpushed;
        add("apply", text, b.hash, "waiting");
    }

    function startSwitch(rid, instance, nextState) {
        setCardState(rid, "applying");
        switchProc.rid = rid;
        switchProc.nextState = nextState;
        switchProc.command = ["systemctl", "start", "agentos-switch@" + instance + ".service"];
        switchProc.running = true;
    }

    function cardAction(rid, action) {
        if (action === "allow" || action === "deny")
            answer(rid, action);
        else if (action === "apply")
            startSwitch(rid, rid, "applied");
        else if (action === "undo")
            startSwitch(rid, "rollback", "rolledback");
        else if (action === "dismiss")
            setCardState(rid, "dismissed");
    }

    function cardTitle(who, state) {
        if (who === "approve")
            return state === "waiting" ? "Claude asks permission to:" : state === "allowed" ? "✓ Allowed" : state === "denied" ? "✕ Denied" : "Expired (no answer in time)";
        return {
            waiting: "A new system build is ready to apply:",
            applying: "Applying… (enter your password when asked)",
            applied: "✓ Applied. Ask Claude to commit if it hasn't.",
            rolledback: "↶ Rolled back to the previous generation",
            failed: "✕ Not applied (see the note below)",
            dismissed: "Dismissed"
        }[state] ?? state;
    }

    function cardButtons(who, state) {
        if (who === "approve" && state === "waiting")
            return [{ label: "Deny", action: "deny" }, { label: "Allow once", action: "allow", primary: true }];
        if (who === "apply" && state === "waiting")
            return [{ label: "Dismiss", action: "dismiss" }, { label: "Apply", action: "apply", primary: true }];
        if (who === "apply" && state === "applied")
            return [{ label: "Undo (roll back)", action: "undo" }];
        return [];
    }

    Process {
        id: pendingProc
        command: ["agentos-pending"]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim()) root.offerBuild(text.trim())
        }
    }

    // `systemctl start` waits for the oneshot switch and asks polkit for your password.
    Process {
        id: switchProc

        property string rid
        property string nextState

        stderr: StdioCollector {
            id: switchErr
        }
        onExited: code => {
            if (code === 0) {
                root.setCardState(rid, nextState);
                // A rolled-back build can be offered (and applied) again.
                if (nextState === "rolledback") {
                    delete root.offered[rid];
                    root.checkPending();
                }
            } else {
                root.setCardState(rid, "failed");
                root.add("note", switchErr.text.trim() || "systemctl exited with code " + code);
                journalProc.command = ["journalctl", "-u", "agentos-switch@*", "-n", "12", "--no-pager", "-o", "cat"];
                journalProc.running = true;
            }
        }
    }

    Process {
        id: journalProc
        stdout: StdioCollector {
            onStreamFinished: if (text.trim()) root.add("note", text.trim())
        }
    }

    function answer(rid, verdict) {
        const conn = pending[rid];
        delete pending[rid];
        setCardState(rid, verdict === "allow" ? "allowed" : "denied");
        if (conn && conn.connected) {
            conn.write(verdict + "\n");
            conn.flush();
            conn.connected = false; // lets the hook's socat exit
        }
    }

    function setCardState(rid, state) {
        for (let i = 0; i < messages.count; i++)
            if (messages.get(i).rid === rid)
                messages.setProperty(i, "state", state);
    }

    // The hook gave up (timeout) or Claude was stopped: retire the card.
    function dropped(conn) {
        for (const rid in pending)
            if (pending[rid] === conn) {
                delete pending[rid];
                setCardState(rid, "expired");
            }
    }

    // Start late: on a hot reload the old instance removes the socket file as it exits.
    Timer {
        running: true
        interval: 1500
        onTriggered: approveServer.active = true
    }

    SocketServer {
        id: approveServer
        active: false
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/agentos-approve.sock"
        handler: Socket {
            id: conn
            parser: SplitParser {
                onRead: line => root.request(conn, line)
            }
            onConnectedChanged: if (!connected) root.dropped(conn)
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
                root.add("note", "agentos-ask exited with code " + code + "; see journalctl --user -u quickshell");
            root.busy = false;
            input.forceActiveFocus();
            root.checkPending(); // Claude may have just built something
        }
    }

    Connections {
        target: ShellState
        function onClaudeOpenChanged() {
            if (ShellState.claudeOpen) {
                input.forceActiveFocus();
                root.checkPending(); // e.g. built with nh os build in a terminal
            }
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

                // who: "you" | "claude" (bubbles), "tool" | "note" (small status lines),
                // or "approve" (a permission card waiting for your click).
                delegate: Rectangle {
                    id: entry

                    required property string who
                    required property string body
                    required property string rid
                    required property string state
                    readonly property bool line: who === "tool" || who === "note"
                    readonly property bool card: who === "approve" || who === "apply"

                    width: ListView.view.width
                    height: card ? cardCol.implicitHeight + 24 : txt.implicitHeight + (line ? 4 : 20)
                    radius: 14
                    color: line ? "transparent" : card ? Theme.alpha(Theme.accent2, 0.1) : who === "you" ? Theme.alpha(Theme.accent, 0.14) : Theme.alpha(Theme.fg, 0.05)
                    border.width: card && (state === "waiting" || state === "applying") ? 1 : 0
                    border.color: Theme.alpha(Theme.accent2, 0.6)

                    Column {
                        id: cardCol

                        visible: entry.card
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 10

                        Text {
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: root.cardTitle(entry.who, entry.state)
                            color: entry.state === "denied" || entry.state === "failed" ? Theme.warn : Theme.alpha(Theme.fg, 0.7)
                            font.family: Theme.fontSans
                            font.pixelSize: 12
                        }

                        Text {
                            width: parent.width
                            text: entry.body
                            textFormat: Text.PlainText
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: entry.who === "apply" ? 30 : 14
                            elide: Text.ElideRight
                            color: Theme.fg
                            opacity: entry.state === "waiting" || entry.state === "applying" ? 1 : 0.55
                            font.family: Theme.fontMono
                            font.pixelSize: 12
                        }

                        Row {
                            spacing: 8

                            Repeater {
                                model: root.cardButtons(entry.who, entry.state)

                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool allow: modelData.primary === true

                                    width: btnText.implicitWidth + 28
                                    height: 30
                                    radius: 9
                                    color: allow ? (btnArea.containsMouse ? Theme.accent : Theme.alpha(Theme.accent, 0.8)) : (btnArea.containsMouse ? Theme.alpha(Theme.fg, 0.16) : Theme.alpha(Theme.fg, 0.08))

                                    Text {
                                        id: btnText
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: allow ? Theme.bg : Theme.fg
                                        font.family: Theme.fontSans
                                        font.pixelSize: 13
                                        font.weight: allow ? Font.DemiBold : Font.Normal
                                    }

                                    // Mouse only: a stray Enter while typing can't approve anything.
                                    MouseArea {
                                        id: btnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.cardAction(entry.rid, modelData.action)
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: !entry.card
                        id: txt
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: line ? 2 : 10
                        anchors.leftMargin: 10
                        text: who === "tool" ? "⚙ " + body : who === "note" ? "⚠ " + body : body
                        textFormat: who === "claude" ? Text.MarkdownText : Text.PlainText
                        wrapMode: line ? Text.WrapAnywhere : Text.Wrap
                        maximumLineCount: who === "note" ? 14 : line ? 3 : 100000
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
