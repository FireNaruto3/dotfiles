import QtQuick

Rectangle {
    id: root

    property string text: ""
    property string tooltip: ""
    property color foreground: "#c6d0f5"
    property color hoverBackground: "#80669970"
    property int horizontalPadding: 15
    property bool tooltipSuppressed: false

    signal clicked(int button)
    signal wheel(int delta)

    implicitWidth: label.implicitWidth + horizontalPadding * 2
    implicitHeight: 30
    color: mouse.containsMouse ? hoverBackground : "transparent"

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    Text {
        id: label

        anchors.centerIn: parent
        text: root.text
        color: root.foreground
        font.family: "JetBrains Mono Nerd Font"
        font.pixelSize: 13
        verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            root.tooltipSuppressed = true
            root.clicked(event.button)
        }
        onExited: root.tooltipSuppressed = false
        onWheel: event => {
            root.wheel(event.angleDelta.y)
            event.accepted = true
        }
    }

    HoverTooltip {
        target: root
        shown: mouse.containsMouse && !root.tooltipSuppressed && root.tooltip.length > 0
        text: root.tooltip
    }
}
