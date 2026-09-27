import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Key binding cheat sheet (Super+/, Esc or click to close). Reads `hyprctl binds -j`
// on open, so it lists exactly the bindings in hyprland.lua that have a description.
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
    visible: ShellState.cheatsheetOpen || card.opacity > 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "agentos-cheatsheet"
    WlrLayershell.keyboardFocus: ShellState.cheatsheetOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // [{ name, rows: [{ keys: [..], text }] }]
    property var groups: []

    readonly property var keyNames: ({
            "RETURN": "Enter",
            "SPACE": "Space",
            "SLASH": "/",
            "TAB": "Tab",
            "grave": "`",
            "equal": "=",
            "minus": "−",
            "left": "←",
            "right": "→",
            "up": "↑",
            "down": "↓",
            "mouse:272": "Left drag",
            "mouse:273": "Right drag"
        })

    function modNames(mask) {
        const out = [];
        if (mask & 64) out.push("Super");
        if (mask & 4) out.push("Ctrl");
        if (mask & 8) out.push("Alt");
        if (mask & 1) out.push("Shift");
        return out;
    }

    function keyLabel(keys) {
        const names = keys.map(k => keyNames[k] ?? k.toUpperCase());
        if (names.length > 2 && names.every(n => /^[0-9]$/.test(n)))
            return names[0] + "–" + names[names.length - 1];
        return names.join(" ");
    }

    function build(binds) {
        const rows = [];
        const byId = {};
        for (const b of binds) {
            if (!b.has_description)
                continue;
            const id = b.modmask + "|" + b.description;
            if (!byId[id]) {
                byId[id] = { mask: b.modmask, desc: b.description, keys: [] };
                rows.push(byId[id]);
            }
            byId[id].keys.push(b.key);
        }
        const out = [];
        const byGroup = {};
        for (const r of rows) {
            const i = r.desc.indexOf(":");
            const group = i > 0 ? r.desc.slice(0, i).trim() : "Other";
            const text = i > 0 ? r.desc.slice(i + 1).trim() : r.desc;
            if (!byGroup[group]) {
                byGroup[group] = { name: group, rows: [] };
                out.push(byGroup[group]);
            }
            byGroup[group].rows.push({ keys: modNames(r.mask).concat([keyLabel(r.keys)]), text });
        }
        groups = out;
    }

    Process {
        id: bindsProc
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.build(JSON.parse(text));
                } catch (e) {
                    console.warn("agentos: could not parse hyprctl binds:", e);
                }
            }
        }
    }

    Connections {
        target: ShellState
        function onCheatsheetOpenChanged() {
            if (ShellState.cheatsheetOpen)
                bindsProc.running = true;
        }
    }

    // Dim the desktop; a click anywhere closes.
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bg, 0.35)
        opacity: card.opacity

        MouseArea {
            anchors.fill: parent
            onClicked: ShellState.cheatsheetOpen = false
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(parent.width - 96, 1360)
        height: content.implicitHeight + 64
        radius: Theme.radius
        color: Theme.alpha(Theme.bg, 0.72)
        border.width: 1
        border.color: Theme.alpha(Theme.fg, 0.08)

        opacity: ShellState.cheatsheetOpen ? 1 : 0
        scale: ShellState.cheatsheetOpen ? 1 : 0.97
        Behavior on opacity {
            NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic }
        }

        // Swallow clicks on the card so they don't close it.
        MouseArea {
            anchors.fill: parent
        }

        focus: ShellState.cheatsheetOpen
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Slash) {
                ShellState.cheatsheetOpen = false;
                event.accepted = true;
            }
        }

        Column {
            id: content

            anchors.fill: parent
            anchors.margins: 32
            spacing: 22

            Text {
                text: "Key bindings"
                color: Theme.fg
                font.family: Theme.fontSans
                font.pixelSize: 22
                font.weight: Font.DemiBold
            }

            Flow {
                width: parent.width
                spacing: 28

                Repeater {
                    model: root.groups

                    delegate: Column {
                        required property var modelData

                        width: (content.width - 2 * 28) / 3
                        spacing: 8

                        Text {
                            text: modelData.name.toUpperCase()
                            color: Theme.accent
                            font.family: Theme.fontSans
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                        }

                        Repeater {
                            model: modelData.rows

                            delegate: Row {
                                required property var modelData

                                spacing: 10

                                Row {
                                    id: chips
                                    spacing: 3
                                    width: 170

                                    Repeater {
                                        model: modelData.keys

                                        delegate: Rectangle {
                                            required property string modelData

                                            width: label.implicitWidth + 12
                                            height: 20
                                            radius: 6
                                            color: Theme.alpha(Theme.fg, 0.08)
                                            border.width: 1
                                            border.color: Theme.alpha(Theme.fg, 0.1)

                                            Text {
                                                id: label
                                                anchors.centerIn: parent
                                                text: modelData
                                                color: Theme.fg
                                                font.family: Theme.fontMono
                                                font.pixelSize: 11
                                            }
                                        }
                                    }
                                }

                                Text {
                                    width: (content.width - 2 * 28) / 3 - chips.width - 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.text
                                    color: Theme.alpha(Theme.fg, 0.8)
                                    font.family: Theme.fontSans
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
