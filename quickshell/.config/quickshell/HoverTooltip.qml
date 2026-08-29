import QtQuick
import Quickshell

PopupWindow {
    id: root

    required property Item target
    property string text: ""
    property bool shown: false
    property bool openRight: true

    anchor.item: target
    anchor.edges: openRight ? Edges.Right : Edges.Bottom
    anchor.gravity: openRight ? Edges.Right : Edges.Bottom
    visible: shown && text !== ""
    implicitWidth: Math.min(360, tooltipText.implicitWidth + 24)
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
            width: parent.width - 24
            text: root.text
            color: "#dddddd"
            font.family: "JetBrains Mono Nerd Font"
            font.pixelSize: 12
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
