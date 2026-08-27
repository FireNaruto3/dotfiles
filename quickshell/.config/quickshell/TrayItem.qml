import QtQuick
import Quickshell.Widgets

Rectangle {
    id: root

    required property var trayItem
    required property var hostWindow

    implicitWidth: 28
    implicitHeight: 34
    radius: 10
    color: mouse.containsMouse ? "#26343d40" : "transparent"

    function showMenu() {
        if (!trayItem.hasMenu)
            return

        const position = root.mapToItem(null, 0, root.height)
        trayItem.display(hostWindow, position.x, position.y)
    }

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    IconImage {
        anchors.centerIn: parent
        implicitSize: 18
        source: root.trayItem.icon
        scale: mouse.containsMouse ? 1.12 : 1

        Behavior on scale {
            NumberAnimation { duration: 160; easing.type: Easing.OutBack }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton || root.trayItem.onlyMenu)
                root.showMenu()
            else if (event.button === Qt.MiddleButton)
                root.trayItem.secondaryActivate()
            else
                root.trayItem.activate()
        }
        onWheel: event => {
            root.trayItem.scroll(event.angleDelta.y, false)
            event.accepted = true
        }
    }

    HoverTooltip {
        target: root
        shown: mouse.containsMouse
        text: root.trayItem.tooltipTitle || root.trayItem.title || root.trayItem.id
    }
}
