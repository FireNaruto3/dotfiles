import QtQuick
import Quickshell

PopupWindow {
    id: root

    required property Item target
    property string text: ""
    property bool shown: false

    anchor.item: target
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    visible: shown && text !== ""
    implicitWidth: tooltipText.implicitWidth + 24
    implicitHeight: tooltipText.implicitHeight + 14
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: 15
        color: "#1a1b26"
        border.width: 1
        border.color: "#1affffff"

        Text {
            id: tooltipText

            anchors.centerIn: parent
            text: root.text
            color: "#dddddd"
            font.family: "JetBrains Mono Nerd Font"
            font.pixelSize: 12
        }
    }
}
