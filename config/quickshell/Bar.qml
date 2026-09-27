import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland

// Floating translucent pill bar: workspaces · telemetry · clock · status, battery + Claude.
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 44
    color: "transparent"
    WlrLayershell.namespace: "agentos-bar"

    readonly property var monitor: Hyprland.monitorFor(screen)

    Rectangle {
        id: pill

        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 8
        radius: height / 2
        color: Theme.alpha(Theme.bg, 0.62)
        border.width: 1
        border.color: Theme.alpha(Theme.fg, 0.08)

        // Fade in when the shell (re)loads.
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity {
            NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic }
        }

        // ── Workspaces: at least 5 dots, more if you use them ──
        Row {
            id: workspaces
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: Math.max(5, ...Hyprland.workspaces.values.map(w => w.id).filter(id => id > 0 && id <= 10))

                delegate: Rectangle {
                    id: dot

                    required property int index
                    readonly property int wsId: index + 1
                    readonly property bool active: bar.monitor?.activeWorkspace?.id === wsId
                    readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === wsId)

                    anchors.verticalCenter: parent.verticalCenter
                    width: active ? 28 : 9
                    height: 9
                    radius: height / 2
                    color: active ? Theme.accent : Theme.alpha(Theme.fg, occupied ? 0.55 : 0.16)

                    Behavior on width {
                        NumberAnimation { duration: Theme.medium; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                    }
                    Behavior on color {
                        ColorAnimation { duration: Theme.medium }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + dot.wsId + " })")
                    }
                }
            }
        }

        // ── Telemetry: dim labels, values in paper white, red past the limits.
        // Click to open / close btop (Super+Shift+Escape). ──
        Row {
            id: telemetry

            component Reading: Row {
                id: reading
                property string label
                property string value
                property bool alarm
                property string widest // reserve this width, so changing values don't shift the row
                spacing: 5
                TextMetrics {
                    id: widestMetrics
                    font: valueText.font
                    text: reading.widest
                }
                Text {
                    text: parent.label
                    color: Theme.alpha(Theme.fg, 0.4)
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    anchors.baseline: valueText.baseline
                }
                Text {
                    id: valueText
                    width: Math.max(implicitWidth, widestMetrics.advanceWidth)
                    text: parent.value
                    color: parent.alarm ? Theme.warn : Theme.alpha(Theme.fg, 0.8)
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                }
            }

            anchors.left: workspaces.right
            anchors.leftMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Reading {
                label: "CPU"
                widest: "100%"
                value: Math.round(Telemetry.cpu * 100) + "%"
                alarm: Telemetry.cpu > 0.9
            }
            Reading {
                visible: Telemetry.temp > 0
                label: "TMP"
                widest: "100°"
                value: Math.round(Telemetry.temp) + "°"
                alarm: Telemetry.temp >= 90
            }
            Reading {
                label: "MEM"
                widest: "30.0G"
                value: Telemetry.memUsed.toFixed(1) + "G"
                alarm: Telemetry.memTotal > 0 && Telemetry.memUsed / Telemetry.memTotal > 0.9
            }
            Reading {
                visible: UPower.onBattery && Telemetry.watts > 0
                label: "PWR"
                widest: "30.0W"
                value: Telemetry.watts.toFixed(1) + "W"
                alarm: Telemetry.watts > 25
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: Telemetry.toggleMonitor()
            }
        }

        // ── Clock ──
        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        // Date, time and the outside temperature; click for the calendar.
        Rectangle {
            anchors.centerIn: parent
            width: clockRow.implicitWidth + 24
            height: 30
            radius: 15
            color: ShellState.calendarOpen ? Theme.alpha(Theme.accent, 0.25) : clockHover.hovered ? Theme.alpha(Theme.fg, 0.1) : "transparent"

            Row {
                id: clockRow
                anchors.centerIn: parent
                spacing: 16

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "ddd d MMM   HH:mm")
                    color: Theme.fg
                    font.family: Theme.fontSans
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                // Hidden when the reading is over 3 hours old (offline).
                Row {
                    visible: Weather.fresh
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    LineIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 16
                        name: Weather.icon(Weather.data?.code, Weather.isNight(clock.date))
                        opacity: 0.8
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (Weather.data?.temp ?? "") + "°"
                        color: Theme.alpha(Theme.fg, 0.85)
                        font.family: Theme.fontSans
                        font.pixelSize: 14
                    }
                }
            }

            HoverHandler {
                id: clockHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: ShellState.calendarOpen = !ShellState.calendarOpen
            }
        }

        // ── Right side ──
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            // Status button: Wi-Fi strength + speaker; opens the system menu (Super+Escape).
            Rectangle {
                id: statusButton

                readonly property var wifi: Networking.devices.values.find(d => d.networks !== undefined)?.networks.values.find(n => n.connected) ?? null
                readonly property var sink: Pipewire.defaultAudioSink

                anchors.verticalCenter: parent.verticalCenter
                width: statusRow.implicitWidth + 20
                height: 30 // same as the Claude button
                radius: 15
                color: ShellState.systemOpen ? Theme.alpha(Theme.accent, 0.25) : statusHover.hovered ? Theme.alpha(Theme.fg, 0.1) : "transparent"

                PwObjectTracker {
                    objects: [statusButton.sink]
                }

                Row {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 11

                    // Wi-Fi as a signal indicator: all arcs dim, the ones your signal
                    // reaches lit on top (Lucide line icons, 17 px like the Claude mark).
                    Item {
                        readonly property var w: statusButton.wifi
                        readonly property real s: w?.signalStrength ?? 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: 17
                        height: 17

                        LineIcon {
                            anchors.fill: parent
                            visible: Networking.wifiEnabled
                            size: 17
                            name: "wifi"
                            opacity: 0.25
                        }
                        LineIcon {
                            anchors.fill: parent
                            size: 17
                            name: !Networking.wifiEnabled ? "wifi-off" : !parent.w ? "wifi-zero" : parent.s > 0.66 ? "wifi" : parent.s > 0.4 ? "wifi-high" : parent.s > 0.15 ? "wifi-low" : "wifi-zero"
                            glyph: !Networking.wifiEnabled ? "󰤭" : "󰤨"
                        }
                    }

                    // Notifications: dot = unread (orange), crossed out = do not disturb.
                    LineIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 17
                        name: Notifs.dnd ? "bell-off" : Notifs.unread > 0 ? "bell-dot" : "bell"
                        tone: Notifs.unread > 0 && !Notifs.dnd ? "accent" : "fg"
                        glyph: Notifs.dnd ? "󰂛" : "󰂚"
                    }

                    // Volume as a VU meter: four segments stacked, lit from the bottom up
                    // to the volume; dim red when muted.
                    Column {
                        readonly property var a: statusButton.sink?.audio
                        readonly property real v: a?.volume ?? 0
                        readonly property bool muted: !a || a.muted
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Repeater {
                            model: 4
                            delegate: Rectangle {
                                required property int index
                                readonly property int level: 3 - index // top segment = loudest
                                readonly property bool lit: !parent.muted && parent.v > level * 0.25 + 0.001
                                width: 11
                                height: 2.5
                                radius: 1
                                color: parent.muted ? Theme.alpha(Theme.warn, 0.55) : lit ? Theme.fg : Theme.alpha(Theme.fg, 0.22)
                            }
                        }
                    }
                }

                HoverHandler {
                    id: statusHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: ShellState.systemOpen = !ShellState.systemOpen
                }
            }

            // Battery: a bolt while charging, red below 15% on battery.
            Row {
                readonly property var dev: UPower.displayDevice
                // Quickshell reports 0–1 (verified on the UM3406).
                readonly property real pct: dev.percentage * 100
                readonly property bool low: UPower.onBattery && pct < 15

                visible: dev.isLaptopBattery
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                LineIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !UPower.onBattery
                    size: 14
                    name: "zap"
                    glyph: "󱐋"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(parent.pct) + "%"
                    color: parent.low ? Theme.warn : Theme.fg
                    font.family: Theme.fontSans
                    font.pixelSize: 13
                }
            }

            // Claude button: same as Super+A.
            Rectangle {
                width: 30
                height: 30
                radius: 15
                anchors.verticalCenter: parent.verticalCenter
                color: ShellState.claudeOpen ? Theme.alpha(Theme.claude, 0.3) : hover.hovered ? Theme.alpha(Theme.claude, 0.15) : "transparent"

                Behavior on color {
                    ColorAnimation { duration: Theme.fast }
                }

                ClaudeMark {
                    anchors.centerIn: parent
                    size: 17
                }

                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: ShellState.claudeOpen = !ShellState.claudeOpen
                }
            }
        }
    }
}
