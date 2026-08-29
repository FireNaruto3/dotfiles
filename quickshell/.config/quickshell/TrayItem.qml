import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Rectangle {
    id: root

    required property var trayItem
    required property var hostWindow
    property bool vertical: true
    property bool shown: false

    function refreshShown() {
        shown = trayItem.status !== Status.Passive || trayItem.id === "software-update-available"
    }

    Component.onCompleted: refreshShown()

    Connections {
        target: root.trayItem

        function onReady() {
            root.refreshShown()
        }

        function onStatusChanged() {
            root.refreshShown()
        }
    }

    implicitWidth: 28
    implicitHeight: 34
    radius: 10
    color: mouse.containsMouse ? "#26343d40" : "transparent"

    function showMenu() {
        if (!trayItem.hasMenu)
            return

        const position = root.vertical
            ? root.mapToItem(null, root.width, 0)
            : root.mapToItem(null, 0, root.height)
        trayItem.display(hostWindow, position.x, position.y)
    }

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    IconImage {
        anchors.centerIn: parent
        implicitSize: 18
        source: !root.visible
            ? ""
            : (root.trayItem.id === "software-update-available"
                ? Quickshell.iconPath("software-update-available", true)
                : root.trayItem.icon)
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
            if (root.trayItem.id === "software-update-available")
                Quickshell.execDetached(["update-manager"])
            else if (root.trayItem.title === "warp-taskbar")
                Quickshell.execDetached(["warp-taskbar"])
            else if (event.button === Qt.RightButton || root.trayItem.onlyMenu)
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
        openRight: root.vertical
    }
}
