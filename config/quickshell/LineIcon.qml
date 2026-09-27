import QtQuick

// A Lucide line icon in a palette tone (Theme.icon), or `glyph` (a Nerd Font icon) until
// the icons are installed.
Item {
    id: root

    property string name
    property string tone: "fg"
    property string glyph: ""
    property real size: 18

    implicitWidth: size
    implicitHeight: size

    Image {
        id: svg
        anchors.fill: parent
        visible: status === Image.Ready
        source: Theme.icon(root.name, root.tone)
        // Render at 2x so the thin strokes stay crisp at 125% scaling.
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        smooth: true
    }
    Text {
        anchors.centerIn: parent
        visible: !svg.visible
        text: root.glyph
        color: root.tone === "accent" ? Theme.accent : root.tone === "warn" ? Theme.warn : Theme.fg
        font.family: Theme.fontMono
        font.pixelSize: root.size
    }
}
