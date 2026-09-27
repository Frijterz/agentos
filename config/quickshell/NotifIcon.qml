import QtQuick
import Quickshell

// A notification's picture: its own image, else the app's icon, else a bell glyph.
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
    Text {
        anchors.centerIn: parent
        visible: !picture.visible
        text: "󰂚"
        color: Theme.accent
        font.family: Theme.fontMono
        font.pixelSize: root.size * 0.6
    }
}
