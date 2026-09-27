import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland

// Volume/brightness pop-up. Volume follows PipeWire; brightness arrives via
// `qs ipc call osd brightness` from the Hyprland key binds (sysfs can't notify us).
PanelWindow {
    id: osd

    anchors.bottom: true
    margins.bottom: 72
    implicitWidth: 260
    implicitHeight: 52
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "agentos-osd"
    mask: Region {} // clicks pass through

    readonly property PwNode sink: Pipewire.defaultAudioSink

    property string icon: ""
    property real value: 0
    property bool muted: false
    property bool shown: false
    // Ignore the burst of volume signals while PipeWire connects at startup.
    property bool armed: false

    visible: shown || pill.opacity > 0

    function show(i, v, m) {
        icon = i;
        value = Math.max(0, Math.min(1, v));
        muted = m;
        shown = true;
        hideTimer.restart();
    }

    function showVolume() {
        if (!armed || !sink?.audio)
            return;
        const m = sink.audio.muted;
        const v = sink.audio.volume;
        show(m ? "󰖁" : v < 0.34 ? "󰕿" : v < 0.67 ? "󰖀" : "󰕾", v, m);
    }

    PwObjectTracker {
        objects: [osd.sink]
    }

    Connections {
        target: osd.sink?.audio ?? null
        function onVolumeChanged() { osd.showVolume() }
        function onMutedChanged() { osd.showVolume() }
    }

    Timer {
        running: true
        interval: 1500
        onTriggered: osd.armed = true
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: osd.shown = false
    }

    // -e4 matches the exponent the key binds use, so steps look even.
    Process {
        id: brightnessProc
        command: ["brightnessctl", "-m", "-e4", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const pct = parseInt(text.trim().split(",")[3]);
                if (!isNaN(pct))
                    osd.show("󰃠", pct / 100, false);
            }
        }
    }

    IpcHandler {
        target: "osd"
        function brightness(): void { brightnessProc.running = true }
    }

    Rectangle {
        id: pill

        anchors.fill: parent
        radius: Theme.radius
        color: Theme.alpha(Theme.bg, 0.62)
        border.width: 1
        border.color: Theme.alpha(Theme.fg, 0.08)

        opacity: osd.shown ? 1 : 0
        scale: osd.shown ? 1 : 0.94
        Behavior on opacity {
            NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic }
        }

        Row {
            anchors.centerIn: parent
            spacing: 14

            Text {
                width: 22
                anchors.verticalCenter: parent.verticalCenter
                text: osd.icon
                color: osd.muted ? Theme.warn : Theme.fg
                font.family: Theme.fontMono
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
                width: 150
                height: 6
                radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.alpha(Theme.fg, 0.14)

                Rectangle {
                    width: parent.width * osd.value
                    height: parent.height
                    radius: parent.radius
                    color: osd.muted ? Theme.alpha(Theme.fg, 0.3) : Theme.accent
                    Behavior on width {
                        NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic }
                    }
                }
            }

            Text {
                width: 30
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(osd.value * 100)
                color: Theme.alpha(Theme.fg, 0.7)
                font.family: Theme.fontSans
                font.pixelSize: 13
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
