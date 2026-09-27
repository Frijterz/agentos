import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Mission Control standby screen: true black (OLED), with one console block: an orbit
// ring, a big amber clock, the date and the weather. The block moves to a new spot
// every minute so no pixel stays lit. Started and stopped by hypridle via
// `qs ipc call screensaver start|stop`.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    visible: ShellState.screensaver
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "agentos-screensaver"
    color: "black"

    // Weather from agentos-weather (home/weather.nix), refreshed every 30 minutes.
    property var weather: null
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/agentos/weather.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.weather = JSON.parse(text());
            } catch (e) {}
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        onDateChanged: block.wander()
    }

    Item {
        id: scene

        anchors.fill: parent
        opacity: 0

        Connections {
            target: root
            function onVisibleChanged() {
                scene.opacity = 0;
                if (root.visible) {
                    block.wander();
                    fadeIn.restart();
                }
            }
        }
        NumberAnimation {
            id: fadeIn
            target: scene
            property: "opacity"
            to: 1
            duration: 2500
            easing.type: Easing.InOutQuad
        }

        Item {
            id: block

            readonly property real ring: 190

            function wander() {
                x = ring * 0.2 + Math.random() * (scene.width - width - ring * 0.4);
                y = ring * 0.2 + Math.random() * (scene.height - height - ring * 0.4);
            }

            width: ring * 2
            height: ring * 2

            Behavior on x {
                NumberAnimation { duration: 4000; easing.type: Easing.InOutSine }
            }
            Behavior on y {
                NumberAnimation { duration: 4000; easing.type: Easing.InOutSine }
            }

            // Orbit ring, with one satellite taking a minute per lap.
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Theme.alpha(Theme.accent, 0.22)
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 14
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Theme.alpha(Theme.fg, 0.06)
            }
            Item {
                anchors.fill: parent
                RotationAnimation on rotation {
                    running: root.visible
                    from: 0
                    to: 360
                    duration: 60000
                    loops: Animation.Infinite
                }
                Rectangle {
                    x: parent.width / 2 - width / 2
                    y: -height / 2
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.accent
                    opacity: 0.85
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 10

                // The agentOS mark, breathing a slow glow (calmer than the boot splash).
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 84
                    height: 84
                    visible: Theme.logoDir !== ""

                    Image {
                        anchors.fill: parent
                        source: Theme.logo("glow@2x.png")
                        sourceSize.width: 168
                        sourceSize.height: 168
                        smooth: true
                        SequentialAnimation on opacity {
                            running: root.visible
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.08; to: 0.5; duration: 3000; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.5; to: 0.08; duration: 3000; easing.type: Easing.InOutSine }
                        }
                    }
                    Image {
                        anchors.fill: parent
                        source: Theme.logo("mark@2x.png")
                        sourceSize.width: 168
                        sourceSize.height: 168
                        smooth: true
                        opacity: 0.85
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Theme.logoDir === ""
                    text: "MISSION CONTROL · STANDBY"
                    color: Theme.accent
                    opacity: 0.4
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    font.letterSpacing: 3
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: Theme.accent
                    opacity: 0.8
                    font.family: Theme.fontMono
                    font.pixelSize: 104
                    font.weight: Font.Light
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "dddd d MMMM yyyy").toUpperCase()
                    color: Theme.fg
                    opacity: 0.45
                    font.family: Theme.fontMono
                    font.pixelSize: 13
                    font.letterSpacing: 3
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.weather !== null
                    text: root.weather ? (root.weather.place + "  ·  " + root.weather.temp + "°C  ·  " + root.weather.desc).toUpperCase() : ""
                    color: Theme.fg
                    opacity: 0.32
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                    font.letterSpacing: 2
                }
            }
        }
    }
}
