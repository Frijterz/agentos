import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Mission log (Super+L): what changed on this laptop and why, per day, from agentos-log
// (agent/agentos-log.sh; private, ~/.local/state/agentos/mission-log). Today is
// compiled live; past days carry a short summary written overnight. ↑ ↓ pick a day,
// Esc or a click outside closes.
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
    visible: ShellState.missionLogOpen || card.opacity > 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "agentos-missionlog"
    WlrLayershell.keyboardFocus: ShellState.missionLogOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function close() {
        ShellState.missionLogOpen = false;
    }

    property var days: [] // {date, label, summary}, today first
    property int selected: 0
    property var lines: [] // the selected day's Markdown, line by line

    Process {
        id: listProc
        command: ["agentos-log", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.days = text.split("\n").filter(l => l.trim()).map(l => JSON.parse(l));
                root.show(0);
            }
        }
    }
    Process {
        id: showProc
        stdout: StdioCollector {
            onStreamFinished: root.lines = text.split("\n")
        }
    }
    function show(i) {
        if (!days.length)
            return;
        selected = Math.max(0, Math.min(days.length - 1, i));
        showProc.command = ["agentos-log", "show", days[selected].date];
        showProc.running = true;
        page.contentY = 0;
    }

    Connections {
        target: ShellState
        function onMissionLogOpenChanged() {
            if (ShellState.missionLogOpen) {
                ShellState.launcherOpen = false;
                ShellState.systemOpen = false;
                listProc.running = true;
                keys.forceActiveFocus();
            }
        }
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            const k = event.key;
            if (k === Qt.Key_Escape)
                root.close();
            else if (k === Qt.Key_Down)
                root.show(root.selected + 1);
            else if (k === Qt.Key_Up)
                root.show(root.selected - 1);
            else if (k === Qt.Key_PageDown)
                page.contentY = Math.min(Math.max(0, page.contentHeight - page.height), page.contentY + page.height * 0.8);
            else if (k === Qt.Key_PageUp)
                page.contentY = Math.max(0, page.contentY - page.height * 0.8);
            else
                return;
            event.accepted = true;
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

        anchors.centerIn: parent
        width: Math.min(820, parent.width - 80)
        height: Math.min(560, parent.height - 140)
        radius: Theme.radius
        color: Theme.alpha(Theme.bg, 0.88)
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.3)

        opacity: ShellState.missionLogOpen ? 1 : 0
        scale: ShellState.missionLogOpen ? 1 : 0.97
        Behavior on opacity {
            NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
        }

        // ── Days ──
        Column {
            id: dayList

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 16
            width: 170
            spacing: 4

            Text {
                bottomPadding: 8
                text: "MISSION LOG"
                color: Theme.accent
                opacity: 0.8
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.letterSpacing: 2
            }

            ListView {
                id: dayView
                width: parent.width
                height: parent.height - 30
                clip: true
                spacing: 2
                model: root.days
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: root.selected
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Rectangle {
                    id: dayRow
                    required property var modelData
                    required property int index
                    readonly property bool current: index === root.selected

                    width: ListView.view.width
                    height: 32
                    radius: Theme.radiusSmall
                    color: current ? Theme.alpha(Theme.accent, 0.16) : dayArea.containsMouse ? Theme.alpha(Theme.fg, 0.05) : "transparent"
                    border.width: current ? 1 : 0
                    border.color: Theme.alpha(Theme.accent, 0.4)

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: dayRow.modelData.label
                        color: dayRow.current ? Theme.accent : Theme.alpha(Theme.fg, 0.75)
                        font.family: Theme.fontSans
                        font.pixelSize: 13
                        font.weight: dayRow.current ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        id: dayArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.show(dayRow.index)
                    }
                }
            }
        }

        Rectangle {
            anchors.left: dayList.right
            anchors.leftMargin: 14
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 16
            width: 1
            color: Theme.alpha(Theme.fg, 0.08)
        }

        // ── The selected day: our Markdown (title, sections, "- HH:MM · text"
        // entries, paragraphs) drawn as a console readout ──
        Flickable {
            id: page

            anchors.left: dayList.right
            anchors.leftMargin: 30
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 18
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body
                width: page.width
                spacing: 6

                Repeater {
                    model: root.lines

                    delegate: Item {
                        id: line
                        required property string modelData
                        readonly property string kind: modelData.startsWith("# ") ? "title" : modelData.startsWith("## ") ? "section" : modelData.startsWith("- ") ? "entry" : modelData.trim() ? "text" : "blank"
                        readonly property var entry: modelData.match(/^- (\d\d:\d\d) · (.*)$/)

                        width: body.width
                        height: kind === "blank" ? 0 : content.implicitHeight + (kind === "section" ? 10 : 0)
                        visible: kind !== "blank"

                        Loader {
                            id: content
                            width: parent.width
                            anchors.bottom: parent.bottom
                            sourceComponent: line.kind === "title" ? titleText : line.kind === "section" ? sectionText : line.kind === "entry" ? entryRow : paragraph
                        }

                        Component {
                            id: titleText
                            Text {
                                text: line.modelData.slice(2)
                                bottomPadding: 4
                                color: Theme.fg
                                font.family: Theme.fontSans
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                            }
                        }
                        Component {
                            id: sectionText
                            Text {
                                text: line.modelData.slice(3).toUpperCase()
                                color: Theme.accent
                                opacity: 0.75
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                                font.letterSpacing: 1.5
                            }
                        }
                        Component {
                            id: entryRow
                            Row {
                                spacing: 10
                                Text {
                                    width: 42
                                    text: line.entry ? line.entry[1] : "·"
                                    color: Theme.alpha(Theme.fg, 0.4)
                                    font.family: Theme.fontMono
                                    font.pixelSize: 11
                                    topPadding: 1
                                }
                                Text {
                                    width: line.width - 52
                                    text: line.entry ? line.entry[2] : line.modelData.slice(2)
                                    wrapMode: Text.Wrap
                                    color: Theme.alpha(Theme.fg, 0.85)
                                    font.family: Theme.fontSans
                                    font.pixelSize: 13
                                }
                            }
                        }
                        Component {
                            id: paragraph
                            Text {
                                text: line.modelData
                                wrapMode: Text.Wrap
                                color: Theme.fg
                                opacity: 0.9
                                font.family: Theme.fontSans
                                font.pixelSize: 14
                                lineHeight: 1.2
                            }
                        }
                    }
                }
            }
        }
    }
}
