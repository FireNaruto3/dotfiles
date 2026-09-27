import QtQuick

Rectangle {
    id: root

    ShellTheme { id: theme }

    property string text: ""
    property string tooltip: ""
    property color foreground: theme.accent
    property color background: theme.card
    property color hoverBackground: theme.cardHover
    property int horizontalPadding: 12
    property int maximumWidth: 0

    signal clicked(int button)
    signal wheel(int delta)

    implicitWidth: maximumWidth > 0
        ? Math.min(label.implicitWidth + horizontalPadding * 2, maximumWidth)
        : label.implicitWidth + horizontalPadding * 2
    implicitHeight: 34
    radius: 11
    color: mouse.containsMouse ? hoverBackground : background

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    Text {
        id: label

        anchors.centerIn: parent
        width: root.maximumWidth > 0
            ? Math.min(implicitWidth, root.maximumWidth - root.horizontalPadding * 2)
            : implicitWidth
        text: root.text
        color: root.foreground
        elide: Text.ElideRight
        font.family: "JetBrains Mono Nerd Font"
        font.pixelSize: 12
        font.bold: true
        verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => root.clicked(event.button)
        onWheel: event => {
            root.wheel(event.angleDelta.y)
            event.accepted = true
        }
    }

    HoverTooltip {
        target: root
        shown: mouse.containsMouse
        text: root.tooltip
    }
}
