import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// App launcher (Super+Space): fuzzy search over installed apps, with a calculator
// ("=12*7") and "Ask Claude" when nothing matches. Apps you open often rise to the top.
// Apps start through `uwsm app`, each in its own systemd unit: started from here they
// would live inside quickshell.service and die with every shell restart.
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
    visible: ShellState.launcherOpen || card.opacity > 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "agentos-launcher"
    WlrLayershell.keyboardFocus: ShellState.launcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property string query: ""
    property int selected: 0

    function close() {
        ShellState.launcherOpen = false;
    }

    // ── Usage counts, so frequent apps rank higher ──
    property var usage: ({})
    FileView {
        id: usageFile
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/agentos/launcher.json"
        printErrors: false
        onLoaded: {
            try {
                root.usage = JSON.parse(text());
            } catch (e) {}
        }
    }

    // ── Fuzzy score: prefix > word start > substring > letters in order; 0 = no match ──
    function score(text, q) {
        text = (text || "").toLowerCase();
        if (!q)
            return 1;
        if (text.startsWith(q))
            return 100;
        if (text.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
            return 80;
        if (text.indexOf(q) >= 0)
            return 60;
        let i = 0;
        for (const ch of text)
            if (ch === q[i] && ++i === q.length)
                return 30;
        return 0;
    }

    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay)

    // Calculator: only digits, operators and brackets, so nothing else gets evaluated.
    readonly property string calcResult: {
        const m = query.match(/^=\s*([0-9+\-*/%^().,\s]+)$/);
        if (!m)
            return "";
        try {
            const v = Function("return (" + m[1].replace(/\^/g, "**").replace(/,/g, ".") + ")")();
            return typeof v === "number" && isFinite(v) ? String(Math.round(v * 1e10) / 1e10) : "";
        } catch (e) {
            return "";
        }
    }

    readonly property var results: {
        const q = query.trim().toLowerCase();
        const out = [];
        if (calcResult)
            out.push({ kind: "calc", title: calcResult, subtitle: "Enter copies the result" });
        if (!q.startsWith("=")) {
            const scored = [];
            for (const a of apps) {
                const s = Math.max(score(a.name, q), score(a.genericName, q) * 0.8, score(a.keywords.join(" "), q) * 0.6, score(a.comment, q) * 0.4);
                if (s > 0)
                    scored.push({ app: a, s: s + Math.min(40, (usage[a.id] ?? 0) * 4) });
            }
            scored.sort((x, y) => y.s - x.s || x.app.name.localeCompare(y.app.name));
            for (const r of scored.slice(0, 8))
                out.push({ kind: "app", app: r.app, title: r.app.name, subtitle: r.app.genericName || r.app.comment, icon: r.app.icon });
        }
        if (q && !q.startsWith("="))
            out.push({ kind: "claude", title: "Ask Claude: " + query.trim(), subtitle: "Opens the Claude panel and sends it" });
        return out;
    }
    onResultsChanged: selected = 0

    Process {
        id: copyProc
    }

    function activate(r) {
        if (!r)
            return;
        if (r.kind === "app") {
            const u = Object.assign({}, usage);
            u[r.app.id] = (u[r.app.id] ?? 0) + 1;
            usage = u;
            usageFile.setText(JSON.stringify(u));
            Quickshell.execDetached(["uwsm", "app", "--", r.app.id + ".desktop"]);
        } else if (r.kind === "calc") {
            copyProc.command = ["wl-copy", r.title];
            copyProc.running = true;
        } else if (r.kind === "claude") {
            ShellState.claudeQuestion = query.trim();
            ShellState.claudeOpen = true;
        }
        close();
    }

    Connections {
        target: ShellState
        function onLauncherOpenChanged() {
            if (ShellState.launcherOpen) {
                ShellState.systemOpen = false;
                root.query = "";
                search.text = "";
                search.forceActiveFocus();
            }
        }
    }

    // Dim the desktop; a click outside the card closes.
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bg, 0.35)
        opacity: card.opacity
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.2
        width: 620
        height: column.implicitHeight + 28
        radius: Theme.radius
        color: Theme.alpha(Theme.bg, 0.86)
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.3)

        opacity: ShellState.launcherOpen ? 1 : 0
        scale: ShellState.launcherOpen ? 1 : 0.97
        Behavior on opacity {
            NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 8

            TextField {
                id: search

                width: parent.width
                placeholderText: "Search apps  ·  =12*7 to calculate  ·  anything else: ask Claude"
                placeholderTextColor: Theme.alpha(Theme.fg, 0.35)
                color: Theme.fg
                font.family: Theme.fontMono
                font.pixelSize: 17
                leftPadding: 46
                rightPadding: 14
                topPadding: 12
                bottomPadding: 12
                background: Rectangle {
                    radius: Theme.radiusSmall
                    color: Theme.alpha(Theme.fg, 0.05)
                    LineIcon {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        size: 18
                        name: "search"
                        tone: "accent"
                        glyph: "󰍉"
                    }
                }

                onTextChanged: root.query = text
                onAccepted: root.activate(root.results[root.selected])
                Keys.onEscapePressed: root.close()
                Keys.onDownPressed: root.selected = Math.min(root.results.length - 1, root.selected + 1)
                Keys.onUpPressed: root.selected = Math.max(0, root.selected - 1)
                Keys.onTabPressed: root.selected = (root.selected + 1) % Math.max(1, root.results.length)
            }

            Repeater {
                model: root.results

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property bool current: index === root.selected

                    width: column.width
                    height: 50
                    radius: Theme.radiusSmall
                    color: current ? Theme.alpha(Theme.accent, 0.16) : hover.containsMouse ? Theme.alpha(Theme.fg, 0.05) : "transparent"
                    border.width: current ? 1 : 0
                    border.color: Theme.alpha(Theme.accent, 0.4)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 14

                        Item {
                            width: 30
                            height: 30
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                id: appIcon
                                anchors.fill: parent
                                visible: row.modelData.kind === "app" && status === Image.Ready
                                source: row.modelData.kind === "app" ? Quickshell.iconPath(row.modelData.icon, true) : ""
                                sourceSize.width: 60
                                sourceSize.height: 60
                                smooth: true
                            }
                            // Line icon for the calculator, or when an app has no icon.
                            LineIcon {
                                anchors.centerIn: parent
                                visible: !appIcon.visible && row.modelData.kind !== "claude"
                                size: 22
                                name: row.modelData.kind === "calc" ? "calculator" : "app-window"
                                tone: "accent"
                                glyph: row.modelData.kind === "calc" ? "󰃬" : "󰀻"
                            }
                            ClaudeMark {
                                anchors.centerIn: parent
                                visible: row.modelData.kind === "claude"
                                size: 22
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                width: row.width - 80
                                text: row.modelData.title
                                elide: Text.ElideRight
                                color: row.current ? Theme.accent : Theme.fg
                                font.family: row.modelData.kind === "calc" ? Theme.fontMono : Theme.fontSans
                                font.pixelSize: row.modelData.kind === "calc" ? 18 : 14
                                font.weight: Font.DemiBold
                            }
                            Text {
                                width: row.width - 80
                                visible: text !== ""
                                text: row.modelData.subtitle ?? ""
                                elide: Text.ElideRight
                                color: Theme.alpha(Theme.fg, 0.5)
                                font.family: Theme.fontSans
                                font.pixelSize: 11
                            }
                        }
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selected = row.index
                        onClicked: root.activate(row.modelData)
                    }
                }
            }
        }
    }
}
