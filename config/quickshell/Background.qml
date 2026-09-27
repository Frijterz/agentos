import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Wayland

// Mission Control wallpaper: a faint orbital plot on a technical grid, like a 1970s
// mission-control display. The grid, orbits and planet are drawn once (Canvas); only a
// satellite and some telemetry move, at 5 fps. The whole plot drifts a few pixels over
// ~15 minutes so no line stays lit in one place (OLED). Frozen on battery and in
// battery mode (Theme.animatedBackground).
// Day and night follow the real sun (sunrise/sunset from Weather): by day a warm haze
// and a broad sunlit rim, by night dimmer lines, a thin crescent and faint stars. The
// change fades over twilight in 20 steps; the Canvas repaints only when a step changes.
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

    // ── Day and night ──
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    function minutes(hm) {
        const [h, m] = hm.split(":").map(Number);
        return h * 60 + m;
    }
    readonly property string sunrise: Weather.data?.sunrise ?? "07:00"
    readonly property string sunset: Weather.data?.sunset ?? "19:30"
    // 0 = night, 1 = day; ramps over the hour around sunrise and sunset.
    readonly property real daylight: {
        if (ShellState.daylightPreview >= 0)
            return Math.min(1, ShellState.daylightPreview);
        const now = clock.date.getHours() * 60 + clock.date.getMinutes();
        const ramp = x => Math.max(0, Math.min(1, x / 60 + 0.5));
        return Math.min(ramp(now - minutes(sunrise)), ramp(minutes(sunset) - now));
    }
    readonly property real phase: Math.round(daylight * 20) / 20 // repaint steps

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
            property var deps: [root.width, root.height, Theme.fg, Theme.accent, Theme.bg, root.phase]
            onDepsChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                const fg = Theme.fg, ac = Theme.accent;
                const rgba = (c, a) => "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")";
                const day = root.phase;
                const lines = 0.6 + 0.4 * day; // everything a notch dimmer at night
                ctx.reset();
                ctx.translate(40, 40);

                // Night: faint stars, always in the same places (a seeded sequence), and
                // off the planet's side of the screen.
                if (day < 1) {
                    let seed = 7;
                    const rand = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
                    ctx.fillStyle = rgba(fg, 0.22 * (1 - day));
                    for (let i = 0; i < 90; i++) {
                        const x = rand() * root.width, y = rand() * root.height, big = rand() > 0.85;
                        if (Math.hypot(x - root.cx, y - root.cy) > 110)
                            ctx.fillRect(x, y, big ? 2 : 1, big ? 2 : 1);
                    }
                }

                // Day: a warm haze around the planet.
                if (day > 0) {
                    const haze = ctx.createRadialGradient(root.cx, root.cy, 60, root.cx, root.cy, 460);
                    haze.addColorStop(0, rgba(ac, 0.07 * day));
                    haze.addColorStop(1, rgba(ac, 0));
                    ctx.fillStyle = haze;
                    ctx.fillRect(root.cx - 460, root.cy - 460, 920, 920);
                }

                // Technical grid: fine every 48 px, major every 240 px.
                for (let pass = 0; pass < 2; pass++) {
                    const step = pass ? 240 : 48;
                    ctx.strokeStyle = rgba(fg, (pass ? 0.055 : 0.028) * lines);
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
                    ctx.strokeStyle = rgba(ac, o.alpha * lines);
                    ctx.fillStyle = rgba(ac, o.alpha * 1.6 * lines);
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

                // Planet: dark disc, a sunlit rim (broad by day, a thin crescent at night),
                // a faint equator.
                const r = 64;
                ctx.fillStyle = rgba(Theme.bg, 1);
                ctx.beginPath();
                ctx.arc(root.cx, root.cy, r, 0, 2 * Math.PI);
                ctx.fill();
                ctx.lineWidth = 1.5;
                ctx.strokeStyle = rgba(ac, 0.35 + 0.2 * day);
                const lit = Math.PI * (0.25 + 0.55 * day), mid = Math.PI * 1.45;
                ctx.beginPath();
                ctx.arc(root.cx, root.cy, r, mid - lit / 2, mid + lit / 2);
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
                    root.daylight >= 0.5 ? "DAYSIDE   · SUNSET " + root.sunset : "NIGHTSIDE · SUNRISE " + root.sunrise,
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

        // agentOS logo block, bottom left: mark, wordmark, system line. Dim, and it drifts
        // with the plot like everything else.
        Row {
            x: 28
            y: root.height - 100
            spacing: 10
            visible: Theme.logoDir !== ""

            Image {
                anchors.verticalCenter: parent.verticalCenter
                source: Theme.logo("mark@2x.png")
                width: 72
                height: 72
                sourceSize.width: 144
                sourceSize.height: 144
                smooth: true
                opacity: 0.55
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Image {
                    source: Theme.logo("word@2x.png")
                    height: 26
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    opacity: 0.5
                }
                Text {
                    text: "NIXOS · HYPRLAND · QUICKSHELL · ZENBOOK 14 UM3406"
                    color: Theme.fg
                    opacity: 0.2
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    font.letterSpacing: 2
                }
            }
        }
        // Claude FM console, bottom right (home/radio.nix): play / stop, the current song
        // (read off the stream by agentos-radio-now) and sound waves from cava. The waves
        // only move while the radio plays and no window covers this corner (nothing
        // fullscreen), at 10 fps on battery, and rest flat in battery mode.
        Item {
            id: radio

            x: root.width - width - 56
            y: root.height - height - 58
            width: 300
            height: 122

            readonly property var player: Mpris.players.values.find(p => (p.trackTitle || "").startsWith("Claude FM")) ?? null
            readonly property bool on: player !== null
            readonly property bool playing: player?.playbackState === MprisPlaybackState.Playing
            property bool tuning: false // clicked play, the stream is still starting
            onOnChanged: tuning = false
            Timer {
                running: radio.tuning
                interval: 20000
                onTriggered: radio.tuning = false
            }

            property var song: null
            FileView {
                path: Quickshell.env("XDG_RUNTIME_DIR") + "/agentos-radio-now.json"
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
                onLoaded: {
                    try {
                        const d = JSON.parse(text());
                        radio.song = d.title ? d : null;
                    } catch (e) {
                        radio.song = null;
                    }
                }
                onLoadFailed: radio.song = null
            }

            // In view: no window on this workspace overlaps the console (positions in layout
            // coordinates, so relative to this monitor's corner).
            readonly property var monitor: Hyprland.monitorFor(root.screen)
            readonly property var workspace: monitor?.activeWorkspace ?? null
            readonly property rect area: Qt.rect(x + plot.x, y + plot.y, width, height)
            readonly property bool inView: !(workspace?.toplevels?.values ?? []).some(t => {
                const o = t.lastIpcObject;
                if (!o?.at || !o?.size)
                    return false;
                if (o.fullscreen)
                    return true;
                const wx = o.at[0] - (monitor?.lastIpcObject?.x ?? 0), wy = o.at[1] - (monitor?.lastIpcObject?.y ?? 0);
                return wx < area.x + area.width && wx + o.size[0] > area.x && wy < area.y + area.height && wy + o.size[1] > area.y;
            })
            // Hyprland announces no move or resize of floating windows: ask for positions.
            Timer {
                interval: 2000
                repeat: true
                running: radio.playing
                triggeredOnStart: true
                onTriggered: Hyprland.refreshToplevels()
            }
            property var levels: []
            Process {
                id: cava
                readonly property bool wanted: radio.playing && radio.inView && Theme.animatedBackground
                running: wanted
                command: ["cava", "-p", Quickshell.env("HOME") + "/.config/agentos/cava" + (UPower.onBattery ? "-battery" : "") + ".conf"]
                stdout: SplitParser {
                    onRead: data => radio.levels = data.split(";").filter(v => v !== "").map(Number)
                }
                onRunningChanged: if (!running) radio.levels = []
            }
            // Plugged in or out while the waves move: restart cava with the other rate.
            Connections {
                target: UPower
                function onOnBatteryChanged() {
                    if (cava.running) {
                        cava.running = false;
                        cava.running = Qt.binding(() => cava.wanted);
                    }
                }
            }

            Column {
                anchors.fill: parent
                spacing: 8

                Text {
                    text: "CLAUDE FM  ·  " + (radio.tuning ? "TUNING IN" : !radio.on ? "OFF AIR" : radio.playing ? "LIVE" : "PAUSED")
                    color: Theme.accent
                    opacity: radio.on ? 0.7 : 0.4
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    font.letterSpacing: 2
                }

                Row {
                    spacing: 14

                    // Play / stop, the same as Super+R.
                    Rectangle {
                        id: button
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 40
                        radius: 20
                        color: buttonArea.containsMouse ? Theme.alpha(Theme.accent, 0.18) : Theme.alpha(Theme.bg, 0.5)
                        border.width: 1
                        border.color: Theme.alpha(Theme.accent, radio.on ? 0.7 : 0.35)
                        LineIcon {
                            anchors.centerIn: parent
                            size: 16
                            name: radio.on || radio.tuning ? "square" : "play"
                            tone: "accent"
                            glyph: radio.on || radio.tuning ? "■" : "▶"
                        }
                        MouseArea {
                            id: buttonArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                radio.tuning = !radio.on;
                                Quickshell.execDetached(["agentos-radio", "toggle"]);
                            }
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Text {
                            width: radio.width - button.width - 14
                            text: radio.song?.title ?? (radio.on ? "Music for thinking and building" : "Lo-fi and ambient, made by musicians")
                            elide: Text.ElideRight
                            color: Theme.fg
                            opacity: radio.song ? 0.85 : 0.45
                            font.family: Theme.fontSans
                            font.pixelSize: 14
                        }
                        Text {
                            width: radio.width - button.width - 14
                            text: (radio.song?.artist ?? (radio.on ? "reading the ticker…" : "Super+R  or  press play")).toUpperCase()
                            elide: Text.ElideRight
                            color: Theme.fg
                            opacity: 0.4
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            font.letterSpacing: 1.5
                        }
                    }
                }

                // Sound waves: 32 bars rising from a baseline.
                Row {
                    height: 36
                    spacing: 3
                    Repeater {
                        model: 32
                        delegate: Rectangle {
                            required property int index
                            anchors.bottom: parent.bottom
                            width: 6
                            height: 2 + (radio.levels[index] ?? 0) / 100 * 34
                            radius: 1
                            color: Theme.accent
                            opacity: radio.on ? 0.55 : 0.2
                            Behavior on height {
                                NumberAnimation { duration: 50 }
                            }
                        }
                    }
                }
            }
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
