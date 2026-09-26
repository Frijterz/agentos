import QtQuick
import QtQuick.Controls

// Password entry for a polkit AuthFlow (PolkitDialog and the Claude panel's Apply
// card). Only the user can type here; nothing Claude writes can fill it in.
Column {
    id: root

    required property var flow

    spacing: 10

    function focusField() {
        field.forceActiveFocus();
    }

    // Wrong password, or polkit's own note.
    Text {
        width: parent.width
        visible: text !== ""
        text: root.flow?.failed ? "Wrong password, try again." : (root.flow?.supplementaryMessage ?? "")
        wrapMode: Text.Wrap
        color: root.flow?.failed || root.flow?.supplementaryIsError ? Theme.warn : Theme.alpha(Theme.fg, 0.6)
        font.family: Theme.fontSans
        font.pixelSize: 12
    }

    TextField {
        id: field

        width: parent.width
        enabled: root.flow?.isResponseRequired ?? false
        echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
        placeholderText: "󰌾  " + (root.flow?.inputPrompt || "Password")
        placeholderTextColor: Theme.alpha(Theme.fg, 0.4)
        color: Theme.fg
        font.family: Theme.fontSans
        font.pixelSize: 14
        leftPadding: 14
        rightPadding: 14
        topPadding: 10
        bottomPadding: 10

        background: Rectangle {
            radius: 12
            color: Theme.alpha(Theme.fg, 0.06)
            border.width: 1
            border.color: field.activeFocus ? Theme.accent : Theme.alpha(Theme.accent, 0.35)
        }

        onAccepted: submit()
        Keys.onEscapePressed: root.flow?.cancelAuthenticationRequest()

        function submit() {
            if (!root.flow || !text)
                return;
            root.flow.submit(text);
            text = "";
        }
    }

    Row {
        anchors.right: parent.right
        spacing: 8

        Repeater {
            model: [
                { label: "Cancel", primary: false },
                { label: "Authenticate", primary: true }
            ]

            delegate: Rectangle {
                required property var modelData

                width: btn.implicitWidth + 28
                height: 30
                radius: 9
                color: modelData.primary ? (area.containsMouse ? Theme.accent : Theme.alpha(Theme.accent, 0.8)) : (area.containsMouse ? Theme.alpha(Theme.fg, 0.16) : Theme.alpha(Theme.fg, 0.08))

                Text {
                    id: btn
                    anchors.centerIn: parent
                    text: modelData.label
                    color: modelData.primary ? Theme.bg : Theme.fg
                    font.family: Theme.fontSans
                    font.pixelSize: 13
                    font.weight: modelData.primary ? Font.DemiBold : Font.Normal
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modelData.primary ? field.submit() : root.flow?.cancelAuthenticationRequest()
                }
            }
        }
    }
}
