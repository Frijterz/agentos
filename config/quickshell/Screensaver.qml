import QtQuick
import Quickshell
import Quickshell.Wayland

// OLED-friendly screensaver: true black, slowly rising motes of light, and a dim
// clock that wanders every minute so no pixel stays lit.
// Started and stopped by hypridle via `qs ipc call screensaver start|stop`.
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

    Item {
        id: scene

        anchors.fill: parent
        opacity: 0

        Connections {
            target: root
            function onVisibleChanged() {
                scene.opacity = 0;
                if (root.visible)
                    fadeIn.restart();
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

        Repeater {
            model: 70

            delegate: Rectangle {
                id: mote

                required property int index
                readonly property real depth: Math.random() // 0 = far away, 1 = close

                x: Math.random() * scene.width
                y: scene.height + 20
                width: 2 + depth * 4
                height: width
                radius: width / 2
                color: [Theme.accent, Theme.accent2, Theme.accent3, Theme.fg][index % 4]
                opacity: 0.15 + depth * 0.5

                // Closer motes rise faster; random pauses stagger them.
                SequentialAnimation on y {
                    running: root.visible
                    loops: Animation.Infinite
                    PauseAnimation { duration: Math.random() * 30000 }
                    NumberAnimation {
                        from: scene.height + 20
                        to: -20
                        duration: 60000 - mote.depth * 35000
                    }
                }
            }
        }

        Text {
            id: clockText

            function wander() {
                x = Math.random() * (scene.width - width);
                y = Math.random() * (scene.height - height);
            }

            x: (scene.width - width) / 2
            y: (scene.height - height) / 2
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.fg
            opacity: 0.35
            font.family: Theme.fontSans
            font.pixelSize: 96
            font.weight: Font.Light

            Behavior on x {
                NumberAnimation { duration: 4000; easing.type: Easing.InOutSine }
            }
            Behavior on y {
                NumberAnimation { duration: 4000; easing.type: Easing.InOutSine }
            }

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
                onDateChanged: clockText.wander()
            }
        }
    }
}
