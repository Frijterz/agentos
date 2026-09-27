import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Clipboard history (Super+V): what you copied, newest first, from cliphist
// (home/clipboard.nix). Type to filter; Enter or a click copies it again, ready for
// Ctrl+V. Delete removes an entry; "clear all" asks for a second click. Passwords from
// Super+Shift+P are never stored. Images show a thumbnail: the newest 30 are unpacked
// into $XDG_RUNTIME_DIR (memory, gone at logout) when the card opens.
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
    visible: ShellState.clipboardOpen || card.opacity > 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "agentos-clipboard"
    WlrLayershell.keyboardFocus: ShellState.clipboardOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function close() {
        ShellState.clipboardOpen = false;
    }

    // ── History: `cliphist list` gives "id<TAB>preview" lines, newest first ──
    property var entries: []
    property string query: ""
    property bool confirmingClear: false
    property bool previewing: false // the selected image, large (Space)
    readonly property var current: shown[list.currentIndex] ?? null

    readonly property var shown: {
        const q = query.trim().toLowerCase();
        return q ? entries.filter(e => e.preview.toLowerCase().includes(q)) : entries;
    }
    onShownChanged: list.currentIndex = 0
    onCurrentChanged: if (!current?.image) previewing = false

    readonly property string thumbDir: Quickshell.env("XDG_RUNTIME_DIR") + "/agentos-clipboard"

    function parse(line) {
        const tab = line.indexOf("\t");
        const preview = line.slice(tab + 1);
        // Images: "[[ binary data 23 KiB png 1920x1080 ]]"
        const img = preview.match(/^\[\[ binary data (.+?) (\w+) (\d+x\d+) \]\]$/);
        return {
            line: line,
            preview: preview,
            image: !!img,
            title: img ? "Image  " + img[3].replace("x", " × ") : preview.replace(/\s+/g, " ").trim(),
            detail: img ? img[2].toUpperCase() + " · " + img[1] : "",
            kind: img ? "image" : /^\s*https?:\/\/\S+\s*$/.test(preview) ? "link" : "type",
            thumb: img ? "file://" + thumbDir + "/" + line.slice(0, tab) + "." + img[2] : ""
        };
    }

    Process {
        id: listProc
        // Unpack the images that have no thumbnail yet and drop the ones no longer in the
        // history, then list.
        command: ["sh", "-c", `
            dir="$1"; mkdir -p "$dir"; cd "$dir" || exit 1
            cliphist list > list.tsv
            grep -F '[[ binary data' list.tsv | head -30 | while IFS= read -r line; do
                id=\${line%%\t*}; fmt=$(printf '%s' "$line" | awk '{print $(NF-2)}')
                [ -s "$id.$fmt" ] || printf '%s\n' "$line" | cliphist decode > "$id.$fmt"
            done
            for f in *.*; do
                [ "$f" = list.tsv ] || grep -q "^\${f%.*}\t" list.tsv || rm -f -- "$f"
            done
            cat list.tsv`, "sh", root.thumbDir]
        stdout: StdioCollector {
            onStreamFinished: root.entries = text.split("\n").filter(l => l.includes("\t")).map(root.parse)
        }
    }
    Process {
        id: actionProc
        onExited: listProc.running = true // refresh after a delete or wipe
    }
    Process {
        id: copyProc
    }

    function copy(e) {
        if (!e)
            return;
        // Back on the clipboard; the watcher moves it to the top of the history.
        copyProc.command = ["sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy", "sh", e.line];
        copyProc.running = true;
        close();
    }
    function remove(e) {
        if (!e)
            return;
        actionProc.command = ["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "sh", e.line];
        actionProc.running = true;
    }
    function clearAll() {
        if (!confirmingClear) {
            confirmingClear = true;
            clearTimeout.restart();
            return;
        }
        confirmingClear = false;
        actionProc.command = ["cliphist", "wipe"];
        actionProc.running = true;
    }
    Timer {
        id: clearTimeout
        interval: 3000
        onTriggered: root.confirmingClear = false
    }

    Connections {
        target: ShellState
        function onClipboardOpenChanged() {
            if (ShellState.clipboardOpen) {
                ShellState.launcherOpen = false;
                ShellState.systemOpen = false;
                root.query = "";
                search.text = "";
                root.confirmingClear = false;
                root.previewing = false;
                listProc.running = true;
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
        width: 580
        height: column.implicitHeight + 28
        radius: Theme.radius
        color: Theme.alpha(Theme.bg, 0.86)
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.3)

        opacity: ShellState.clipboardOpen ? 1 : 0
        scale: ShellState.clipboardOpen ? 1 : 0.97
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
                placeholderText: "Clipboard history  ·  type to filter"
                placeholderTextColor: Theme.alpha(Theme.fg, 0.35)
                color: Theme.fg
                font.family: Theme.fontMono
                font.pixelSize: 15
                leftPadding: 44
                rightPadding: 14
                topPadding: 11
                bottomPadding: 11
                background: Rectangle {
                    radius: Theme.radiusSmall
                    color: Theme.alpha(Theme.fg, 0.05)
                    LineIcon {
                        anchors.left: parent.left
                        anchors.leftMargin: 15
                        anchors.verticalCenter: parent.verticalCenter
                        size: 17
                        name: "clipboard"
                        tone: "accent"
                        glyph: "󰅍"
                    }
                }

                onTextChanged: root.query = text
                onAccepted: root.copy(root.current)
                Keys.onEscapePressed: root.previewing ? root.previewing = false : root.close()
                Keys.onDownPressed: list.incrementCurrentIndex()
                Keys.onUpPressed: list.decrementCurrentIndex()
                Keys.onPressed: event => {
                    // Delete removes the selected entry (the field's own text keeps
                    // Backspace).
                    // Space on an image: the large preview (on text it types a space).
                    if (event.key === Qt.Key_Space && root.current?.image) {
                        root.previewing = !root.previewing;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Delete && root.shown.length) {
                        root.remove(root.shown[list.currentIndex]);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_PageDown) {
                        list.currentIndex = Math.min(root.shown.length - 1, list.currentIndex + 8);
                    } else if (event.key === Qt.Key_PageUp) {
                        list.currentIndex = Math.max(0, list.currentIndex - 8);
                    }
                }
            }

            Text {
                visible: root.shown.length === 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                topPadding: 14
                bottomPadding: 14
                text: root.entries.length ? "Nothing matches" : "Nothing copied yet"
                color: Theme.alpha(Theme.fg, 0.4)
                font.family: Theme.fontSans
                font.pixelSize: 13
            }

            ListView {
                id: list

                visible: root.shown.length > 0
                width: parent.width
                height: Math.min(contentHeight, 8 * 42)
                clip: true
                spacing: 2
                model: root.shown
                boundsBehavior: Flickable.StopAtBounds
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property bool current: ListView.isCurrentItem

                    width: ListView.view.width
                    height: modelData.image ? 68 : 40
                    radius: Theme.radiusSmall
                    color: current ? Theme.alpha(Theme.accent, 0.16) : hover.containsMouse ? Theme.alpha(Theme.fg, 0.05) : "transparent"
                    border.width: current ? 1 : 0
                    border.color: Theme.alpha(Theme.accent, 0.4)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        LineIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !thumb.visible
                            size: 16
                            name: row.modelData.kind
                            tone: row.current ? "accent" : "fg"
                            opacity: row.current ? 1 : 0.5
                        }
                        // Image entries: a thumbnail, framed like a console readout.
                        Rectangle {
                            id: thumb
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.modelData.image && shot.status === Image.Ready
                            width: 88
                            height: 54
                            radius: 3
                            color: Theme.alpha(Theme.fg, 0.04)
                            border.width: 1
                            border.color: row.current ? Theme.alpha(Theme.accent, 0.5) : Theme.alpha(Theme.fg, 0.12)
                            Image {
                                id: shot
                                anchors.fill: parent
                                anchors.margins: 2
                                source: row.modelData.thumb
                                sourceSize.width: 176
                                sourceSize.height: 108
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                cache: false
                                smooth: true
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: row.width - 110 - detailText.implicitWidth
                            text: row.modelData.title
                            elide: Text.ElideRight
                            color: row.current ? Theme.fg : Theme.alpha(Theme.fg, 0.8)
                            font.family: Theme.fontMono
                            font.pixelSize: 12
                        }
                    }
                    Text {
                        id: detailText
                        anchors.right: removeIcon.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.detail
                        color: Theme.alpha(Theme.fg, 0.4)
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: list.currentIndex = row.index
                        // A click on an image's thumbnail previews it; anywhere else copies.
                        onClicked: mouse => {
                            if (row.modelData.image && mouse.x < 12 + thumb.width + 6)
                                root.previewing = !root.previewing;
                            else
                                root.copy(row.modelData);
                        }
                    }
                    // Remove: shown on the selected row (or press Delete).
                    LineIcon {
                        id: removeIcon
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.current
                        size: 14
                        name: "trash-2"
                        opacity: removeArea.containsMouse ? 1 : 0.45
                        MouseArea {
                            id: removeArea
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.remove(row.modelData)
                        }
                    }
                }
            }

            // Large preview of the selected image (Space or a click on its thumbnail).
            Rectangle {
                visible: root.previewing
                width: parent.width
                height: Math.min(parent.width / 1.6, 340)
                radius: Theme.radiusSmall
                color: Theme.alpha(Theme.fg, 0.04)
                border.width: 1
                border.color: Theme.alpha(Theme.accent, 0.3)
                Image {
                    anchors.fill: parent
                    anchors.margins: 6
                    source: root.previewing ? root.current?.thumb ?? "" : ""
                    sourceSize.width: 1104
                    sourceSize.height: 680
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    smooth: true
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.previewing = false
                }
            }

            // Footer: key hints and clear all.
            Item {
                width: parent.width
                height: 20

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ENTER COPY  ·  " + (root.current?.image ? (root.previewing ? "SPACE CLOSE" : "SPACE VIEW") + "  ·  " : "") + "DEL REMOVE  ·  " + root.entries.length + " ITEMS"
                    color: Theme.alpha(Theme.fg, 0.3)
                    font.family: Theme.fontMono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.entries.length > 0
                    text: root.confirmingClear ? "CLICK AGAIN TO CLEAR ALL" : "CLEAR ALL"
                    color: root.confirmingClear ? Theme.warn : clearArea.containsMouse ? Theme.fg : Theme.alpha(Theme.fg, 0.4)
                    font.family: Theme.fontMono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.clearAll()
                    }
                }
            }
        }
    }
}
