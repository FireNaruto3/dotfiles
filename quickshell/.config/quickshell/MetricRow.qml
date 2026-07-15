import QtQuick

Item {
    id: root

    property string name: ""
    property string value: ""
    property color valueColor: "#c9d3d6"

    implicitHeight: 19

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.name
        color: "#758083"
        font.family: "JetBrains Mono Nerd Font"
        font.pixelSize: 13
        font.bold: true
        font.letterSpacing: 1
    }

    Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.value
        color: root.valueColor
        font.family: "JetBrains Mono Nerd Font"
        font.pixelSize: 13
        font.bold: true
    }
}
