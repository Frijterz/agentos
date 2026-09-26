import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland

// Wallpaper + a slow "aurora" of drifting colour glows in the theme's accents.
// Animates at ~15 fps on purpose: motion this slow still looks smooth, and it
// keeps the iGPU mostly idle. Freezes entirely on battery.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "agentos-background"
    color: Theme.bg

    property real t: 0

    Timer {
        interval: 66
        repeat: true
        running: Theme.animatedBackground && !UPower.onBattery
        onTriggered: root.t += interval / 1000
    }

    // Optional: ln -sf ~/Pictures/whatever.jpg ~/.local/state/agentos/wallpaper
    Image {
        anchors.fill: parent
        source: "file://" + Quickshell.env("HOME") + "/.local/state/agentos/wallpaper"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.slow }
        }
    }

    component Glow: Shape {
        id: glow

        required property color tint
        property real cx
        property real cy
        property real reach: Math.max(root.width, root.height) * 0.55

        anchors.fill: parent

        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: glow.cx
                centerY: glow.cy
                centerRadius: glow.reach
                focalX: glow.cx
                focalY: glow.cy
                GradientStop { position: 0; color: Theme.alpha(glow.tint, 0.22) }
                GradientStop { position: 1; color: Theme.alpha(glow.tint, 0) }
            }
            startX: 0
            startY: 0
            PathLine { x: glow.width; y: 0 }
            PathLine { x: glow.width; y: glow.height }
            PathLine { x: 0; y: glow.height }
            PathLine { x: 0; y: 0 }
        }
    }

    Glow {
        tint: Theme.accent
        cx: root.width * (0.28 + 0.16 * Math.sin(root.t * 0.050))
        cy: root.height * (0.32 + 0.14 * Math.cos(root.t * 0.041))
    }
    Glow {
        tint: Theme.accent2
        cx: root.width * (0.72 + 0.15 * Math.cos(root.t * 0.036))
        cy: root.height * (0.68 + 0.12 * Math.sin(root.t * 0.047))
    }
    Glow {
        tint: Theme.accent3
        opacity: 0.6
        reach: Math.max(root.width, root.height) * 0.4
        cx: root.width * (0.5 + 0.3 * Math.sin(root.t * 0.023 + 2))
        cy: root.height * (0.5 + 0.25 * Math.cos(root.t * 0.029 + 1))
    }
}
