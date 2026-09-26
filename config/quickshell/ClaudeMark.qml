import QtQuick

// Claude's mark (Theme.claudeIcon, from home/shell.nix), or ✦ if it isn't there.
Item {
    id: root

    property real size: 18

    implicitWidth: size
    implicitHeight: size

    Image {
        anchors.fill: parent
        visible: Theme.claudeIcon !== ""
        source: Theme.claudeIcon ? "file://" + Theme.claudeIcon : ""
        // Render the SVG at the device pixel size, so it stays crisp at 125% scale.
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Text {
        anchors.centerIn: parent
        visible: Theme.claudeIcon === ""
        text: "✦"
        color: Theme.claude
        font.pixelSize: root.size
    }
}
