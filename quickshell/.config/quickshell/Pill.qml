import QtQuick

Rectangle {
    id: root

    property string text: ""
    property string tooltip: ""
    property color foreground: "#c6d0f5"
    property color background: "#1a1b26"
    property color hoverBackground: "#80669970"
    property int horizontalPadding: 12
    property int maximumWidth: 0

    signal clicked(int button)
    signal wheel(int delta)

    implicitWidth: maximumWidth > 0
        ? Math.min(label.implicitWidth + horizontalPadding * 2, maximumWidth)
        : label.implicitWidth + horizontalPadding * 2
    implicitHeight: 30
    radius: 15
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
        font.pixelSize: 13
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
