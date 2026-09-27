pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Colours and fonts from Stylix (~/.config/agentos/theme.json, written by Home Manager).
// Falls back to Catppuccin Mocha so the shell renders even before the first rebuild.
Singleton {
    id: root

    property var scheme: ({})

    readonly property color bg: scheme.base00 ?? "#1e1e2e"
    readonly property color surface: scheme.base01 ?? "#181825"
    readonly property color overlay: scheme.base02 ?? "#313244"
    readonly property color fg: scheme.base05 ?? "#cdd6f4"
    readonly property color accent: scheme.base0D ?? "#89b4fa"
    readonly property color accent2: scheme.base0E ?? "#cba6f7"
    readonly property color accent3: scheme.base0C ?? "#94e2d5"
    readonly property color warn: scheme.base08 ?? "#f38ba8"

    readonly property string fontSans: scheme.fontSans ?? "Inter"
    readonly property string fontMono: scheme.fontMono ?? "JetBrainsMono Nerd Font"

    // Claude's mark (SVG path from home/shell.nix); "" means use the ✦ fallback.
    readonly property string claudeIcon: scheme.claudeIcon ?? ""
    readonly property color claude: "#D97757" // Claude's brand terracotta

    // agentOS logo images (modules/nixos/themes/agentos-logo.nix); "" until the rebuild.
    readonly property string logoDir: scheme.logoDir ?? ""
    function logo(name) {
        return logoDir ? "file://" + logoDir + "/" + name : "";
    }

    // Motion: tune the feel of every animation in one place.
    readonly property int fast: 160
    readonly property int medium: 280
    readonly property int slow: 520

    // Eye-candy switches: battery mode (agentos-mode) turns them off.
    readonly property bool animatedBackground: ShellState.mode !== "battery"

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/agentos/theme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.scheme = JSON.parse(text());
            } catch (e) {
                console.warn("agentos: could not parse theme.json:", e);
            }
        }
    }
}
