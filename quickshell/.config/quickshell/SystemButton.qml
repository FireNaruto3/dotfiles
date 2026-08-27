import QtQuick

Rectangle {
    id: root

    property string text: ""
    property string tooltip: ""
    property color foreground: "#99d1db"
    property color accent: "#99d1db"
    property color hoverBackground: "#26343d40"
    property color activeBackground: "#334f6b75"
    property int horizontalPadding: 9
    property bool active: false
    property bool tooltipSuppressed: false

    signal clicked(int button)
    signal wheel(int delta)

    implicitWidth: label.implicitWidth + horizontalPadding * 2
    implicitHeight: 34
    radius: 10
    color: active ? activeBackground : (mouse.containsMouse ? hoverBackground : "transparent")

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    Text {
        id: label

        anchors.centerIn: parent
        text: root.text
        color: root.foreground
        font.family: "JetBrains Mono Nerd Font"
        font.pixelSize: 12
        font.bold: true
        verticalAlignment: Text.AlignVCenter
        scale: mouse.containsMouse ? 1.14 : 1

        Behavior on scale {
            NumberAnimation { duration: 160; easing.type: Easing.OutBack }
        }
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
