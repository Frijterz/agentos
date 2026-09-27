import QtQuick

// Keyboard focus outline for a button (put it inside the button): shows which one
// Enter/Space will press after Tab.
Rectangle {
    anchors.fill: parent
    anchors.margins: -3
    radius: (parent.radius ?? 0) + 3
    color: "transparent"
    border.width: 2
    border.color: Theme.accent
    visible: parent.activeFocus
}
