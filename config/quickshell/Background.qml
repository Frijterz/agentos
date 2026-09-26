import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland

// Mission Control wallpaper: a faint orbital plot on a technical grid, like a 1970s
// mission-control display. The grid, orbits and planet are drawn once (Canvas); only a
// satellite and some telemetry move, at 5 fps. The whole plot drifts a few pixels over
// ~15 minutes so no line stays lit in one place (OLED). Frozen on battery and in
// battery mode (Theme.animatedBackground).
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

    // Seconds of animation; drives the satellite, drift and telemetry.
    property real t: 0
    readonly property bool running: Theme.animatedBackground && !UPower.onBattery

    Timer {
        interval: 200
        repeat: true
        running: root.running
        onTriggered: root.t += interval / 1000
    }

    // Orbital geometry, shared by the Canvas and the satellite.
    readonly property real cx: width * 0.66
    readonly property real cy: height * 0.6
    readonly property real tilt: -16 * Math.PI / 180
    readonly property var orbits: [
        { rx: 215, ry: 88, alpha: 0.2 },
        { rx: 345, ry: 142, alpha: 0.13, dotted: true },
        { rx: 480, ry: 198, alpha: 0.08 }
    ]
    readonly property int period: 360 // seconds per satellite orbit

    function orbitPoint(o, theta) {
        const x = o.rx * Math.cos(theta), y = o.ry * Math.sin(theta);
        return { x: cx + x * Math.cos(tilt) - y * Math.sin(tilt), y: cy + x * Math.sin(tilt) + y * Math.cos(tilt) };
    }

    // Uptime at start, so the "mission elapsed time" counts from boot.
    property real bootUptime: 0
    FileView {
        path: "/proc/uptime"
        onLoaded: root.bootUptime = parseFloat(text().split(" ")[0]) - root.t
    }

    function met(seconds) {
        const s = Math.floor(seconds), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60);
        const pad = n => String(n).padStart(2, "0");
        return pad(h) + ":" + pad(m) + ":" + pad(s % 60);
    }

    // Optional: ln -sf ~/Pictures/whatever.jpg ~/.local/state/agentos/wallpaper
    Image {
        id: userWallpaper
        anchors.fill: parent
        source: "file://" + Quickshell.env("HOME") + "/.local/state/agentos/wallpaper"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        opacity: status === Image.Ready ? 1 : 0
    }

    // Everything in here drifts together.
    Item {
        id: plot

        visible: userWallpaper.status !== Image.Ready
        width: root.width
        height: root.height
        x: 18 * Math.sin(root.t * 2 * Math.PI / 900)
        y: 12 * Math.cos(root.t * 2 * Math.PI / 1260)

        Canvas {
            id: chart

            // Bigger than the screen, so drifting never shows an edge.
            x: -40
            y: -40
            width: root.width + 80
            height: root.height + 80

            // Repaint when the size or theme changes, never per frame.
            property var deps: [root.width, root.height, Theme.fg, Theme.accent, Theme.bg]
            onDepsChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                const fg = Theme.fg, ac = Theme.accent;
                const rgba = (c, a) => "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")";
                ctx.reset();
                ctx.translate(40, 40);

                // Technical grid: fine every 48 px, major every 240 px.
                for (let pass = 0; pass < 2; pass++) {
                    const step = pass ? 240 : 48;
                    ctx.strokeStyle = rgba(fg, pass ? 0.055 : 0.028);
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    for (let x = -40; x <= root.width + 40; x += step) {
                        ctx.moveTo(x + 0.5, -40);
                        ctx.lineTo(x + 0.5, root.height + 40);
                    }
                    for (let y = -40; y <= root.height + 40; y += step) {
                        ctx.moveTo(-40, y + 0.5);
                        ctx.lineTo(root.width + 40, y + 0.5);
                    }
                    ctx.stroke();
                }

                // Registration crosses on some major intersections.
                ctx.strokeStyle = rgba(fg, 0.16);
                ctx.beginPath();
                for (let x = 240; x < root.width; x += 480)
                    for (let y = 240; y < root.height; y += 480) {
                        ctx.moveTo(x - 6, y + 0.5);
                        ctx.lineTo(x + 7, y + 0.5);
                        ctx.moveTo(x + 0.5, y - 6);
                        ctx.lineTo(x + 0.5, y + 7);
                    }
                ctx.stroke();

                // Orbits: solid, dotted, solid.
                for (const o of root.orbits) {
                    ctx.strokeStyle = rgba(ac, o.alpha);
                    ctx.fillStyle = rgba(ac, o.alpha * 1.6);
                    if (o.dotted) {
                        for (let a = 0; a < 360; a += 4) {
                            const p = root.orbitPoint(o, a * Math.PI / 180);
                            ctx.fillRect(p.x - 1, p.y - 1, 2, 2);
                        }
                    } else {
                        ctx.lineWidth = 1.2;
                        ctx.beginPath();
                        for (let a = 0; a <= 360; a += 2) {
                            const p = root.orbitPoint(o, a * Math.PI / 180);
                            if (a === 0)
                                ctx.moveTo(p.x, p.y);
                            else
                                ctx.lineTo(p.x, p.y);
                        }
                        ctx.stroke();
                    }
                }

                // Planet: dark disc, lit rim on one side, a faint equator.
                const r = 64;
                ctx.fillStyle = rgba(Theme.bg, 1);
                ctx.beginPath();
                ctx.arc(root.cx, root.cy, r, 0, 2 * Math.PI);
                ctx.fill();
                ctx.lineWidth = 1.5;
                ctx.strokeStyle = rgba(ac, 0.55);
                ctx.beginPath();
                ctx.arc(root.cx, root.cy, r, Math.PI * 1.05, Math.PI * 1.85);
                ctx.stroke();
                ctx.strokeStyle = rgba(ac, 0.15);
                ctx.beginPath();
                ctx.arc(root.cx, root.cy, r, 0, 2 * Math.PI);
                ctx.stroke();
                ctx.strokeStyle = rgba(fg, 0.08);
                ctx.beginPath();
                ctx.ellipse(root.cx - r, root.cy - r * 0.18, 2 * r, r * 0.36);
                ctx.stroke();

                // Apsis ticks on the middle orbit.
                ctx.strokeStyle = rgba(fg, 0.25);
                ctx.fillStyle = rgba(fg, 0.3);
                ctx.font = "10px '" + Theme.fontMono + "'";
                const peri = root.orbitPoint(root.orbits[1], 0), apo = root.orbitPoint(root.orbits[1], Math.PI);
                for (const [p, label] of [[peri, "PERIAPSIS"], [apo, "APOAPSIS"]]) {
                    ctx.beginPath();
                    ctx.moveTo(p.x, p.y - 8);
                    ctx.lineTo(p.x, p.y + 8);
                    ctx.stroke();
                    ctx.fillText(label, p.x + 8, p.y - 10);
                }
            }
        }

        // The satellite on the middle orbit, with a short fading trail.
        Repeater {
            model: 6

            delegate: Rectangle {
                required property int index
                readonly property var p: root.orbitPoint(root.orbits[1], (root.t - index * 1.6) * 2 * Math.PI / root.period)

                x: p.x - width / 2
                y: p.y - height / 2
                width: index === 0 ? 5 : 3
                height: width
                radius: width / 2
                color: Theme.accent
                opacity: index === 0 ? 0.9 : 0.35 - index * 0.05
            }
        }

        Text {
            readonly property var p: root.orbitPoint(root.orbits[1], root.t * 2 * Math.PI / root.period)
            x: p.x + 9
            y: p.y + 4
            text: "AGS-1"
            color: Theme.accent
            opacity: 0.55
            font.family: Theme.fontMono
            font.pixelSize: 10
        }

        // Telemetry, top left (below the bar) and bottom left.
        Column {
            x: 40
            y: 84
            spacing: 3

            Repeater {
                model: [
                    "MISSION CONTROL · AGENTOS",
                    "MET   T+ " + root.met(root.bootUptime + root.t),
                    "ORBIT " + String(Math.floor(root.t / root.period) + 1).padStart(4, "0") + " · PERIOD 06:00",
                    root.running ? "TELEMETRY NOMINAL" : "TELEMETRY HOLD"
                ]

                delegate: Text {
                    required property string modelData
                    required property int index
                    text: modelData
                    color: index === 0 ? Theme.accent : Theme.fg
                    opacity: index === 0 ? 0.45 : 0.24
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    font.letterSpacing: 1.5
                }
            }
        }

        Text {
            x: 40
            y: root.height - 48
            text: "NIXOS · HYPRLAND · QUICKSHELL · ZENBOOK 14 UM3406"
            color: Theme.fg
            opacity: 0.16
            font.family: Theme.fontMono
            font.pixelSize: 10
            font.letterSpacing: 2
        }
    }

    // Vignette: darker edges, like an old console screen.
    Shape {
        anchors.fill: parent
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: root.width / 2
                centerY: root.height / 2
                centerRadius: Math.max(root.width, root.height) * 0.75
                focalX: centerX
                focalY: centerY
                GradientStop { position: 0.55; color: "transparent" }
                GradientStop { position: 1; color: Theme.alpha(Theme.bg, 0.85) }
            }
            startX: 0
            startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
        }
    }
}
