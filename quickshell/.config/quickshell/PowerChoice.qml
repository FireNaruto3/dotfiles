import QtQuick

Rectangle {
    id: root

    required property string label
    property bool selected: false

    signal clicked()

    implicitWidth: 96
    implicitHeight: 34
    radius: 8
    color: !enabled
        ? "#1f2327"
        : (selected ? "#334f6b75" : (mouse.containsMouse ? "#80669970" : "#293f4749"))
    border.width: selected ? 1 : 0
    border.color: "#6699d1db"
    opacity: enabled ? 1 : 0.42

    Behavior on color { ColorAnimation { duration: 130 } }

    Text {
        anchors.centerIn: parent
        text: root.label
        color: root.selected ? "#a9f3d1" : "#c9d3d6"
        font.family: "JetBrains Mono Nerd Font"
        font.pixelSize: 11
        font.bold: root.selected
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
