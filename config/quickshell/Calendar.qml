import QtQuick
import Quickshell
import Quickshell.Wayland

// Calendar card (click the bar's date and time, or Super+C): month grid with ISO week numbers,
// Monday first, and the weather with a three-day outlook. ← → or scroll for other
// months, Home for today; Esc or a click outside closes it.
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
    visible: ShellState.calendarOpen || card.opacity > 0

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "agentos-calendar"
    WlrLayershell.keyboardFocus: ShellState.calendarOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    function close() {
        ShellState.calendarOpen = false;
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // The month on show; back to this month every time the card opens.
    property int viewYear: clock.date.getFullYear()
    property int viewMonth: clock.date.getMonth()
    function showToday() {
        viewYear = clock.date.getFullYear();
        viewMonth = clock.date.getMonth();
    }
    function step(months) {
        const d = new Date(viewYear, viewMonth + months, 1);
        viewYear = d.getFullYear();
        viewMonth = d.getMonth();
    }
    Connections {
        target: ShellState
        function onCalendarOpenChanged() {
            if (ShellState.calendarOpen)
                root.showToday();
        }
    }

    readonly property bool onThisMonth: viewYear === clock.date.getFullYear() && viewMonth === clock.date.getMonth()

    // Six weeks from the Monday on or before the 1st: the grid never changes height.
    readonly property var days: {
        const first = new Date(viewYear, viewMonth, 1);
        const offset = (first.getDay() + 6) % 7;
        const list = [];
        for (let i = 0; i < 42; i++)
            list.push(new Date(viewYear, viewMonth, 1 - offset + i));
        return list;
    }

    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
        return Math.ceil(((t - Date.UTC(t.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
    }
    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    // A click anywhere outside the card closes it.
    MouseArea {
        anchors.fill: parent
        enabled: ShellState.calendarOpen
        onClicked: root.close()
    }

    Item {
        focus: true
        Keys.onEscapePressed: root.close()
        Keys.onLeftPressed: root.step(-1)
        Keys.onRightPressed: root.step(1)
        Keys.onPressed: event => {
            if (event.key === Qt.Key_PageUp)
                root.step(-1);
            else if (event.key === Qt.Key_PageDown)
                root.step(1);
            else if (event.key === Qt.Key_Home)
                root.showToday();
        }
    }

    component Chevron: Item {
        id: chevron
        property string name
        signal clicked
        width: 26
        height: 26
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSmall
            color: chevronArea.containsMouse ? Theme.alpha(Theme.fg, 0.1) : "transparent"
        }
        LineIcon {
            anchors.centerIn: parent
            size: 16
            name: chevron.name
            opacity: 0.7
            glyph: chevron.name === "chevron-left" ? "‹" : "›"
        }
        MouseArea {
            id: chevronArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chevron.clicked()
        }
    }

    // ── The card ──
    Rectangle {
        id: card

        readonly property int cell: 38 // day cell width
        readonly property int weekCol: 30

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 52
        width: weekCol + 7 * cell + 36
        height: content.implicitHeight + 36
        radius: Theme.radius
        color: Theme.alpha(Theme.bg, 0.88)
        border.width: 1
        border.color: Theme.alpha(Theme.fg, 0.08)

        opacity: ShellState.calendarOpen ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic }
        }

        // Swallow clicks so they don't reach the close-catcher behind; scroll for months.
        MouseArea {
            anchors.fill: parent
            onWheel: wheel => root.step(wheel.angleDelta.y > 0 ? -1 : 1)
        }

        Column {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            spacing: 10

            // Month and navigation
            Item {
                width: parent.width
                height: 26

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDate(new Date(root.viewYear, root.viewMonth, 1), "MMMM yyyy")
                    color: Theme.fg
                    font.family: Theme.fontSans
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        visible: !root.onThisMonth
                        anchors.verticalCenter: parent.verticalCenter
                        rightPadding: 8
                        text: "TODAY"
                        color: todayArea.containsMouse ? Theme.accent : Theme.alpha(Theme.accent, 0.75)
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.letterSpacing: 1.5
                        MouseArea {
                            id: todayArea
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showToday()
                        }
                    }
                    Chevron {
                        name: "chevron-left"
                        onClicked: root.step(-1)
                    }
                    Chevron {
                        name: "chevron-right"
                        onClicked: root.step(1)
                    }
                }
            }

            // Weekday header
            Row {
                Text {
                    width: card.weekCol
                    horizontalAlignment: Text.AlignHCenter
                    text: "WK"
                    color: Theme.alpha(Theme.fg, 0.25)
                    font.family: Theme.fontMono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }
                Repeater {
                    model: ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
                    delegate: Text {
                        required property string modelData
                        required property int index
                        width: card.cell
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.alpha(Theme.fg, index >= 5 ? 0.3 : 0.45)
                        font.family: Theme.fontMono
                        font.pixelSize: 9
                        font.letterSpacing: 1
                    }
                }
            }

            // Six weeks
            Column {
                spacing: 2

                Repeater {
                    model: 6
                    delegate: Row {
                        id: week
                        required property int index
                        readonly property var monday: root.days[index * 7]

                        Text {
                            width: card.weekCol
                            height: 30
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: root.isoWeek(week.monday)
                            color: Theme.alpha(Theme.fg, 0.25)
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                        }
                        Repeater {
                            model: 7
                            delegate: Item {
                                id: day
                                required property int index
                                readonly property var date: root.days[week.index * 7 + index]
                                readonly property bool inMonth: date.getMonth() === root.viewMonth
                                readonly property bool today: root.sameDay(date, clock.date)

                                width: card.cell
                                height: 30

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 30
                                    height: 30
                                    radius: 15
                                    visible: day.today
                                    color: Theme.alpha(Theme.accent, 0.18)
                                    border.width: 1
                                    border.color: Theme.alpha(Theme.accent, 0.7)
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: day.date.getDate()
                                    color: day.today ? Theme.accent : Theme.alpha(Theme.fg, !day.inMonth ? 0.18 : day.index >= 5 ? 0.55 : 0.85)
                                    font.family: Theme.fontMono
                                    font.pixelSize: 12
                                    font.weight: day.today ? Font.DemiBold : Font.Normal
                                }
                            }
                        }
                    }
                }
            }

            // ── Weather ──
            Rectangle {
                visible: Weather.ready
                width: parent.width
                height: 1
                color: Theme.alpha(Theme.fg, 0.08)
            }

            Item {
                visible: Weather.ready
                width: parent.width
                height: 44

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    LineIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 32
                        name: Weather.icon(Weather.data?.code, Weather.isNight(clock.date))
                        tone: "accent"
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: (Weather.data?.temp ?? "") + "°  " + (Weather.data?.desc ?? "")
                            color: Theme.fg
                            font.family: Theme.fontSans
                            font.pixelSize: 15
                        }
                        Text {
                            readonly property var today: Weather.data?.days?.[0]
                            text: "feels " + (Weather.data?.feels ?? "") + "°" + (today ? "   ↑" + today.max + "°  ↓" + today.min + "°" : "")
                            color: Theme.alpha(Theme.fg, 0.5)
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                        }
                    }
                }

                Column {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    visible: !!Weather.data?.sunrise

                    Repeater {
                        model: [["sunrise", Weather.data?.sunrise], ["sunset", Weather.data?.sunset]]
                        delegate: Row {
                            required property var modelData
                            spacing: 6
                            LineIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                size: 13
                                name: modelData[0]
                                opacity: 0.5
                            }
                            Text {
                                text: modelData[1] ?? ""
                                color: Theme.alpha(Theme.fg, 0.6)
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }

            // Three-day outlook
            Row {
                visible: (Weather.data?.days?.length ?? 0) > 0
                width: parent.width

                Repeater {
                    model: Weather.data?.days ?? []
                    delegate: Column {
                        required property var modelData
                        required property int index
                        width: content.width / 3
                        spacing: 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: index === 0 ? "TODAY" : Qt.formatDate(new Date(modelData.date + "T12:00"), "ddd").toUpperCase()
                            color: Theme.alpha(Theme.fg, 0.4)
                            font.family: Theme.fontMono
                            font.pixelSize: 9
                            font.letterSpacing: 1.5
                        }
                        LineIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            size: 18
                            name: Weather.icon(modelData.code, false)
                            opacity: 0.8
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.max + "°  " + modelData.min + "°"
                            color: Theme.alpha(Theme.fg, 0.7)
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                        }
                    }
                }
            }

            Text {
                visible: Weather.ready
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                topPadding: 2
                text: ((Weather.data?.place ?? "") + "  ·  updated " + Qt.formatTime(new Date((Weather.data?.updated ?? 0) * 1000), "HH:mm")).toUpperCase()
                color: Theme.alpha(Theme.fg, 0.28)
                font.family: Theme.fontMono
                font.pixelSize: 9
                font.letterSpacing: 1
            }
        }
    }
}
