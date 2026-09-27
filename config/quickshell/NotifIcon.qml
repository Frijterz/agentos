import QtQuick
import Quickshell

// A notification's picture: its own image, else the app's icon, else a bell line icon.
// Claude's get the Claude mark: Claude Code in a terminal sends them through Ghostty
// with no app name, only the title "Claude Code", so they'd show Ghostty's icon.
Item {
    id: root

    required property var notification
    property real size: 32

    width: size
    height: size

    readonly property string source: {
        const n = notification;
        if (!n)
            return "";
        // Before the image: Ghostty sends its own icon as the notification's image.
        if (Theme.claudeIcon && (/claude/i.test(n.appName ?? "") || n.summary === "Claude Code"))
            return Theme.claudeIcon;
        if (n.image)
            return n.image;
        const name = n.appIcon || n.desktopEntry;
        if (!name)
            return "";
        return name.startsWith("/") || name.startsWith("file:") ? name : Quickshell.iconPath(name, true);
    }

    Image {
        id: picture
        anchors.fill: parent
        visible: status === Image.Ready
        source: root.source
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
    LineIcon {
        anchors.centerIn: parent
        visible: !picture.visible
        size: root.size * 0.6
        name: "bell"
        tone: "accent"
        glyph: "󰂚"
    }
}
