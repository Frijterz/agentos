import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Wayland

// System menu (bar status button or Super+Escape): Wi-Fi and Bluetooth, speaker,
// microphone and brightness sliders, and power actions. Esc or a click outside closes it.
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
    visible: ShellState.systemOpen || card.opacity > 0

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "agentos-system"
    WlrLayershell.keyboardFocus: ShellState.systemOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    function close() {
        ShellState.systemOpen = false;
    }

    // ── Wi-Fi (Quickshell.Networking talks to NetworkManager) ──
    readonly property var wifiDevice: Networking.devices.values.find(d => d.networks !== undefined) ?? null
    readonly property var networks: (wifiDevice?.networks.values ?? []).slice().sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength))
    readonly property var connectedNetwork: networks.find(n => n.connected) ?? null
    property bool wifiExpanded: false
    property var askPasswordFor: null // network waiting for its password

    // Scan for networks only while the list is visible.
    Binding {
        target: root.wifiDevice
        property: "scannerEnabled"
        value: ShellState.systemOpen && root.wifiExpanded
        when: root.wifiDevice !== null
    }

    function wifiIcon(strength) {
        return strength > 0.75 ? "󰤨" : strength > 0.5 ? "󰤥" : strength > 0.25 ? "󰤢" : "󰤟";
    }
    // Same thresholds as the bar's Wi-Fi indicator.
    function wifiLine(strength) {
        return strength > 0.66 ? "wifi" : strength > 0.4 ? "wifi-high" : strength > 0.15 ? "wifi-low" : "wifi-zero";
    }
    function needsPassword(n) {
        return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe;
    }
    function connectTo(n) {
        if (n.connected)
            n.disconnect();
        else if (n.known || !needsPassword(n))
            n.connect();
        else
            askPasswordFor = n;
    }

    // ── Bluetooth (Quickshell.Bluetooth talks to BlueZ) ──
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btDevices: (adapter?.devices.values ?? []).filter(d => d.paired || d.name).slice().sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired))
    property bool btExpanded: false

    // ── Sound (PipeWire) and brightness (brightnessctl) ──
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    property real brightness: 0.5
    Process {
        id: brightnessRead
        command: ["brightnessctl", "-m", "-e4", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const pct = parseInt(text.split(",")[3]);
                if (!isNaN(pct))
                    root.brightness = pct / 100;
            }
        }
    }
    Process {
        id: brightnessWrite
    }
    function setBrightness(v) {
        brightness = v;
        brightnessWrite.command = ["brightnessctl", "-q", "-e4", "set", Math.max(1, Math.round(v * 100)) + "%"];
        brightnessWrite.running = true;
    }

    // ── Power (logind allows these for the active local user, no password) ──
    property string confirming: "" // action waiting for its second click
    Timer {
        id: confirmTimeout
        interval: 3000
        onTriggered: root.confirming = ""
    }
    Process {
        id: power
    }
    Process {
        id: modeProc
    }
    function powerAction(a) {
        if (a.confirm && confirming !== a.id) {
            confirming = a.id;
            confirmTimeout.restart();
            return;
        }
        confirming = "";
        close();
        power.command = a.command;
        power.running = true;
    }

    Connections {
        target: ShellState
        function onSystemOpenChanged() {
            if (ShellState.systemOpen) {
                ShellState.claudeOpen = false; // same corner of the screen
                brightnessRead.running = true;
                Notifs.unread = 0;
                keys.forceActiveFocus();
            } else {
                root.askPasswordFor = null;
                root.confirming = "";
            }
        }
    }

    // A click anywhere outside the card closes the menu.
    MouseArea {
        anchors.fill: parent
        enabled: ShellState.systemOpen
        onClicked: root.close()
    }

    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: root.close()
    }

    // ── Reusable pieces ──
    component Tile: Rectangle {
        id: tile

        property string icon // Nerd Font glyph, fallback until the line icons are installed
        property string line // Lucide icon name (Theme.icon)
        property string title
        property string subtitle
        property bool lit // switched on
        property bool expanded
        signal toggled
        signal expandToggled

        height: 58
        radius: 14
        color: lit ? Theme.alpha(Theme.accent, 0.18) : Theme.alpha(Theme.fg, 0.06)
        border.width: 1
        border.color: lit ? Theme.alpha(Theme.accent, 0.45) : "transparent"

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.toggled()
        }
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            LineIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: 20
                name: tile.line
                tone: tile.lit ? "accent" : "fg"
                opacity: tile.lit ? 1 : 0.5
                glyph: tile.icon
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: tile.title
                    color: Theme.fg
                    font.family: Theme.fontSans
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                Text {
                    width: tile.width - 90
                    text: tile.subtitle
                    elide: Text.ElideRight
                    color: Theme.alpha(Theme.fg, 0.55)
                    font.family: Theme.fontSans
                    font.pixelSize: 11
                }
            }
        }
        // Chevron: show the list of networks / devices.
        Item {
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: parent.height
            LineIcon {
                anchors.centerIn: parent
                size: 16
                name: tile.expanded ? "chevron-up" : "chevron-down"
                opacity: 0.6
                glyph: tile.expanded ? "󰅃" : "󰅀"
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.expandToggled()
            }
        }
    }

    component SliderRow: Row {
        id: slider

        property string icon // glyph fallback
        property string line // Lucide icon name
        property real value
        property bool muted
        property bool mutable: true
        signal moved(real v)
        signal muteToggled

        spacing: 12
        height: 28

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            LineIcon {
                anchors.centerIn: parent
                size: 19
                name: slider.line
                tone: slider.muted ? "warn" : "fg"
                glyph: slider.icon
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                enabled: slider.mutable
                cursorShape: slider.mutable ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: slider.muteToggled()
            }
        }
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: slider.width - 22 - 12 - 40 - 12
            height: 20

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                color: Theme.alpha(Theme.fg, 0.1)
                Rectangle {
                    width: parent.width * Math.min(1, Math.max(0, slider.value))
                    height: parent.height
                    radius: 3
                    color: slider.muted ? Theme.alpha(Theme.fg, 0.3) : Theme.accent
                }
            }
            Rectangle {
                x: (parent.width - width) * Math.min(1, Math.max(0, slider.value))
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: 7
                color: Theme.fg
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function update(mouse) {
                    slider.moved(Math.min(1, Math.max(0, mouse.x / width)));
                }
                onPressed: mouse => update(mouse)
                onPositionChanged: mouse => update(mouse)
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            horizontalAlignment: Text.AlignRight
            text: Math.round(slider.value * 100) + "%"
            color: Theme.alpha(Theme.fg, 0.6)
            font.family: Theme.fontSans
            font.pixelSize: 12
        }
    }

    component ListItem: Rectangle {
        id: item

        property string icon // glyph fallback
        property string line // Lucide icon name
        property string label
        property string detail
        property bool secured // a password-protected network: small lock after the detail
        property bool active
        signal clicked

        width: parent.width
        height: 34
        radius: 9
        color: area.containsMouse ? Theme.alpha(Theme.fg, 0.08) : "transparent"

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            LineIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: 16
                name: item.line
                tone: item.active ? "accent" : "fg"
                opacity: item.active ? 1 : 0.6
                glyph: item.icon
            }
            Text {
                width: item.width - 150
                text: item.label
                elide: Text.ElideRight
                color: item.active ? Theme.accent : Theme.fg
                font.family: Theme.fontSans
                font.pixelSize: 13
            }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: item.detail
                color: Theme.alpha(Theme.fg, 0.5)
                font.family: Theme.fontMono
                font.pixelSize: 11
            }
            LineIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: item.secured
                size: 12
                name: "lock"
                opacity: 0.5
                glyph: "󰌾"
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: item.clicked()
        }
    }

    // ── The card ──
    Rectangle {
        id: card

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 52
        anchors.rightMargin: 12
        width: 380
        height: content.implicitHeight + 36
        radius: 20
        color: Theme.alpha(Theme.bg, 0.88)
        border.width: 1
        border.color: Theme.alpha(Theme.fg, 0.08)
        clip: true

        opacity: ShellState.systemOpen ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic }
        }

        // Swallow clicks so they don't reach the close-catcher behind.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            spacing: 14

            // Wi-Fi and Bluetooth tiles
            Row {
                width: parent.width
                spacing: 10

                Tile {
                    width: (parent.width - 10) / 2
                    icon: !Networking.wifiEnabled ? "󰤭" : root.connectedNetwork ? root.wifiIcon(root.connectedNetwork.signalStrength) : "󰤯"
                    line: !Networking.wifiEnabled ? "wifi-off" : root.connectedNetwork ? root.wifiLine(root.connectedNetwork.signalStrength) : "wifi-zero"
                    title: "Wi-Fi"
                    subtitle: !Networking.wifiEnabled ? "Off" : root.connectedNetwork ? root.connectedNetwork.name : "Not connected"
                    lit: Networking.wifiEnabled
                    expanded: root.wifiExpanded
                    onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                    onExpandToggled: {
                        root.wifiExpanded = !root.wifiExpanded;
                        root.btExpanded = false;
                    }
                }
                Tile {
                    readonly property var connected: root.btDevices.filter(d => d.connected)
                    width: (parent.width - 10) / 2
                    icon: !root.adapter?.enabled ? "󰂲" : connected.length ? "󰂱" : "󰂯"
                    line: !root.adapter?.enabled ? "bluetooth-off" : connected.length ? "bluetooth-connected" : "bluetooth"
                    title: "Bluetooth"
                    subtitle: !root.adapter ? "No adapter" : !root.adapter.enabled ? "Off" : connected.length ? connected.map(d => d.name).join(", ") : "On"
                    lit: root.adapter?.enabled ?? false
                    expanded: root.btExpanded
                    onToggled: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
                    onExpandToggled: {
                        root.btExpanded = !root.btExpanded;
                        root.wifiExpanded = false;
                    }
                }
            }

            // Wi-Fi networks
            Column {
                width: parent.width
                spacing: 2
                visible: root.wifiExpanded

                Text {
                    visible: !Networking.wifiEnabled || root.networks.length === 0
                    text: Networking.wifiEnabled ? "Scanning…" : "Wi-Fi is off"
                    color: Theme.alpha(Theme.fg, 0.5)
                    font.family: Theme.fontSans
                    font.pixelSize: 12
                    leftPadding: 10
                }
                Repeater {
                    model: Networking.wifiEnabled ? root.networks.slice(0, 8) : []
                    delegate: ListItem {
                        required property var modelData
                        icon: root.wifiIcon(modelData.signalStrength)
                        line: root.wifiLine(modelData.signalStrength)
                        label: modelData.name
                        detail: modelData.connected ? "connected" : modelData.known ? "saved" : ""
                        secured: root.needsPassword(modelData)
                        active: modelData.connected
                        onClicked: root.connectTo(modelData)
                    }
                }
                // Password for a new secured network. Local only: goes straight to
                // NetworkManager, not to Claude.
                TextField {
                    id: wifiPassword
                    width: parent.width
                    visible: root.askPasswordFor !== null
                    onVisibleChanged: if (visible) forceActiveFocus()
                    echoMode: TextInput.Password
                    placeholderText: "󰌾  Password for " + (root.askPasswordFor?.name ?? "")
                    placeholderTextColor: Theme.alpha(Theme.fg, 0.4)
                    color: Theme.fg
                    font.family: Theme.fontSans
                    font.pixelSize: 13
                    leftPadding: 12
                    background: Rectangle {
                        radius: 10
                        color: Theme.alpha(Theme.fg, 0.06)
                        border.width: 1
                        border.color: Theme.accent
                    }
                    onAccepted: {
                        root.askPasswordFor.connectWithPsk(text);
                        text = "";
                        root.askPasswordFor = null;
                    }
                    Keys.onEscapePressed: {
                        text = "";
                        root.askPasswordFor = null;
                    }
                }
            }

            // Bluetooth devices
            Column {
                width: parent.width
                spacing: 2
                visible: root.btExpanded

                Row {
                    width: parent.width
                    Text {
                        width: parent.width - scanButton.width
                        text: !root.adapter?.enabled ? "Bluetooth is off" : root.btDevices.length ? "" : "No devices yet: scan to find some"
                        color: Theme.alpha(Theme.fg, 0.5)
                        font.family: Theme.fontSans
                        font.pixelSize: 12
                        leftPadding: 10
                    }
                    Text {
                        id: scanButton
                        visible: root.adapter?.enabled ?? false
                        text: root.adapter?.discovering ? "Scanning…  stop" : "Scan"
                        color: Theme.accent
                        font.family: Theme.fontSans
                        font.pixelSize: 12
                        rightPadding: 10
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.adapter.discovering = !root.adapter.discovering
                        }
                    }
                }
                Repeater {
                    model: root.adapter?.enabled ? root.btDevices.slice(0, 8) : []
                    delegate: ListItem {
                        required property var modelData
                        icon: modelData.connected ? "󰂱" : "󰂯"
                        line: modelData.connected ? "bluetooth-connected" : "bluetooth"
                        label: modelData.name || modelData.address
                        detail: (modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%  " : "") + (modelData.connected ? "connected" : modelData.pairing ? "pairing…" : modelData.paired ? "paired" : "new")
                        active: modelData.connected
                        onClicked: modelData.connected ? modelData.disconnect() : modelData.paired ? modelData.connect() : modelData.pair()
                    }
                }
            }

            // Mode (agentos-mode): also the one place that shows which mode is on.
            Row {
                width: parent.width
                spacing: 6

                Repeater {
                    model: [
                        { id: "normal", line: "orbit", icon: "󰾅", label: "Normal" },
                        { id: "battery", line: "battery-low", icon: "󰂃", label: "Battery" },
                        { id: "presentation", line: "presentation", icon: "󰐯", label: "Present" },
                        { id: "focus", line: "focus", icon: "󰂛", label: "Focus" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool current: ShellState.mode === modelData.id

                        width: (parent.width - 3 * 6) / 4
                        height: 34
                        radius: 10
                        color: current ? Theme.alpha(Theme.accent, 0.2) : modeArea.containsMouse ? Theme.alpha(Theme.fg, 0.1) : Theme.alpha(Theme.fg, 0.05)
                        border.width: current ? 1 : 0
                        border.color: Theme.alpha(Theme.accent, 0.5)

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            LineIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                size: 15
                                name: modelData.line
                                tone: parent.parent.current ? "accent" : "fg"
                                glyph: modelData.icon
                            }
                            Text {
                                text: modelData.label
                                color: parent.parent.current ? Theme.accent : Theme.alpha(Theme.fg, 0.7)
                                font.family: Theme.fontSans
                                font.pixelSize: 11
                            }
                        }
                        MouseArea {
                            id: modeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                modeProc.command = ["agentos-mode", modelData.id];
                                modeProc.running = true;
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.alpha(Theme.fg, 0.08)
            }

            // Sliders
            SliderRow {
                width: parent.width
                icon: root.sink?.audio?.muted ? "󰖁" : "󰕾"
                line: root.sink?.audio?.muted ? "volume-x" : "volume-2"
                value: root.sink?.audio?.volume ?? 0
                muted: root.sink?.audio?.muted ?? false
                onMoved: v => {
                    if (root.sink?.audio) {
                        root.sink.audio.muted = false;
                        root.sink.audio.volume = v;
                    }
                }
                onMuteToggled: if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted
            }
            SliderRow {
                width: parent.width
                icon: root.source?.audio?.muted ? "󰍭" : "󰍬"
                line: root.source?.audio?.muted ? "mic-off" : "mic"
                value: root.source?.audio?.volume ?? 0
                muted: root.source?.audio?.muted ?? false
                // Above ~30% the built-in mic clips (Mic Boost): see zenbook-um3406.nix.
                onMoved: v => {
                    if (root.source?.audio) {
                        root.source.audio.muted = false;
                        root.source.audio.volume = v;
                    }
                }
                onMuteToggled: if (root.source?.audio) root.source.audio.muted = !root.source.audio.muted
            }
            SliderRow {
                width: parent.width
                icon: "󰃠"
                line: "sun"
                mutable: false
                value: root.brightness
                onMoved: v => root.setBrightness(v)
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.alpha(Theme.fg, 0.08)
            }

            // Notifications (Notifs.qml): newest first; click runs the notification's
            // default action, × removes it.
            Row {
                width: parent.width
                Text {
                    width: parent.width - clearAll.width
                    text: "NOTIFICATIONS" + (Notifs.history.length ? "  " + Notifs.history.length : "") + (Notifs.dnd ? "  ·  DO NOT DISTURB" : "")
                    color: Theme.alpha(Theme.fg, 0.5)
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                }
                Text {
                    id: clearAll
                    visible: Notifs.history.length > 0
                    text: "Clear"
                    color: Theme.accent
                    font.family: Theme.fontSans
                    font.pixelSize: 11
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.clearAll()
                    }
                }
            }
            Text {
                visible: Notifs.history.length === 0
                text: "Nothing new"
                color: Theme.alpha(Theme.fg, 0.35)
                font.family: Theme.fontSans
                font.pixelSize: 12
            }
            Column {
                width: parent.width
                spacing: 2

                Repeater {
                    model: Notifs.history.slice(0, 5)

                    delegate: Rectangle {
                        id: entry

                        required property var modelData
                        readonly property real at: Notifs.arrived[modelData.id] ?? 0

                        width: parent.width
                        height: 46
                        radius: 10
                        color: entryArea.containsMouse ? Theme.alpha(Theme.fg, 0.07) : "transparent"

                        MouseArea {
                            id: entryArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifs.activate(entry.modelData)
                        }
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            NotifIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                notification: entry.modelData
                                size: 24
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    width: entry.width - 100
                                    text: entry.modelData.summary
                                    elide: Text.ElideRight
                                    color: Theme.fg
                                    font.family: Theme.fontSans
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    width: entry.width - 100
                                    text: entry.modelData.body.replace(/<[^>]*>/g, "").replace(/\n/g, " ")
                                    elide: Text.ElideRight
                                    color: Theme.alpha(Theme.fg, 0.55)
                                    font.family: Theme.fontSans
                                    font.pixelSize: 11
                                }
                            }
                        }
                        Text {
                            anchors.right: dismissIcon.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                const mins = Math.floor((Date.now() - entry.at) / 60000);
                                return !entry.at ? "" : mins < 1 ? "now" : mins < 60 ? mins + "m" : Math.floor(mins / 60) + "h";
                            }
                            color: Theme.alpha(Theme.fg, 0.4)
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                        }
                        LineIcon {
                            id: dismissIcon
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            size: 14
                            name: "x"
                            opacity: 0.45
                            glyph: "󰅖"
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Notifs.dismiss(entry.modelData)
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.alpha(Theme.fg, 0.08)
            }

            // Power
            Row {
                width: parent.width
                spacing: 6

                Repeater {
                    model: [
                        { id: "lock", line: "lock", icon: "󰌾", label: "Lock", command: ["loginctl", "lock-session"], confirm: false },
                        { id: "sleep", line: "moon", icon: "󰒲", label: "Sleep", command: ["systemctl", "suspend"], confirm: false },
                        { id: "logout", line: "log-out", icon: "󰍃", label: "Log out", command: ["uwsm", "stop"], confirm: true },
                        { id: "reboot", line: "rotate-cw", icon: "󰜉", label: "Restart", command: ["systemctl", "reboot"], confirm: true },
                        { id: "poweroff", line: "power", icon: "󰐥", label: "Shut down", command: ["systemctl", "poweroff"], confirm: true }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool asking: root.confirming === modelData.id

                        width: (parent.width - 4 * 6) / 5
                        height: 50
                        radius: 12
                        // Icons only; a confirming button turns red until its second click.
                        color: asking ? Theme.alpha(Theme.warn, 0.25) : powerArea.containsMouse ? Theme.alpha(Theme.fg, 0.1) : Theme.alpha(Theme.fg, 0.05)
                        border.width: asking ? 1 : 0
                        border.color: Theme.warn

                        LineIcon {
                            anchors.centerIn: parent
                            size: 22
                            name: modelData.line
                            tone: parent.asking ? "warn" : "fg"
                            glyph: modelData.icon
                        }
                        MouseArea {
                            id: powerArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.powerAction(modelData)
                        }
                    }
                }
            }
        }
    }
}
