import QtQuick

Rectangle {
    id: root

    required property string label
    property bool selected: false

    ShellTheme { id: theme }

    signal clicked()

    implicitWidth: 96
    implicitHeight: 34
    radius: 8
    color: !enabled
        ? theme.card
        : (selected ? theme.cardActive : (mouse.containsMouse ? theme.cardHover : theme.card))
    border.width: selected ? 1 : 0
    border.color: theme.border
    opacity: enabled ? 1 : 0.42

    Behavior on color { ColorAnimation { duration: 130 } }

    Text {
        anchors.centerIn: parent
        text: root.label
        color: root.selected ? theme.accent : theme.text
        font.family: theme.fontFamily
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
