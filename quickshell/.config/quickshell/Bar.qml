import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: bar

    required property var systemData
    required property var powerData
    required property var niriData
    required property bool vertical
    property string activeView: "none"
    property real drawerAnchor: vertical ? height / 2 : width / 2
    property string displayedView: "none"
    property real reveal: activeView === "none" ? 0 : 1
    readonly property real railWidth: 46
    readonly property real edgeInputPadding: 10
    readonly property var currentWindow: niriData.focusedWindowFor(screen ? screen.name : "")
    readonly property string osdScriptPath: Qt.resolvedUrl("scripts/osd-control.sh").toString().replace("file://", "")
    readonly property string clipboardScriptPath: Qt.resolvedUrl("scripts/clipboard-history.sh").toString().replace("file://", "")
    readonly property real drawerWidth: displayedView === "clock" ? 440 : 350
    readonly property real drawerHeight: displayedView === "clock"
        ? 478
        : (displayedView === "fan" ? 176 : (drawerLoader.item ? drawerLoader.item.implicitHeight : 397))
    readonly property real drawerScale: Math.min(
        1,
        Math.max(0.1, (width - (vertical ? railWidth : 0)) / drawerWidth),
        Math.max(0.1, (height - (vertical ? 0 : railWidth)) / drawerHeight)
    )
    readonly property real renderedDrawerWidth: drawerWidth * drawerScale
    readonly property real renderedDrawerHeight: drawerHeight * drawerScale

    signal openResources()
    signal toggleDrawer(string view, real anchorY)
    signal closeDrawer()
    signal toggleOrientation()

    anchors {
        top: true
        bottom: bar.vertical
        left: true
        right: !bar.vertical
    }
    implicitWidth: bar.vertical && screen ? screen.width : 0
    implicitHeight: !bar.vertical && screen ? screen.height : 0
    exclusiveZone: railWidth
    color: "transparent"
    aboveWindows: true
    focusable: false

    WlrLayershell.namespace: "jonathan-shell-rail"

    mask: Region {
        Region { item: barInputRegion }
        Region { item: bar.activeView !== "none" ? dismissLayer : null }
        Region { item: drawerContainer.visible ? drawerContainer : null }
    }

    Item {
        id: barInputRegion
        width: bar.vertical ? bar.railWidth + bar.edgeInputPadding : bar.width
        height: bar.vertical ? bar.height : bar.railWidth + bar.edgeInputPadding
    }

    onActiveViewChanged: {
        if (activeView !== "none") {
            closeCleanup.stop()
            displayedView = activeView
        } else {
            closeCleanup.restart()
        }
    }

    Behavior on reveal {
        NumberAnimation {
            duration: bar.activeView === "none" ? 260 : 420
            easing.type: bar.activeView === "none" ? Easing.InBack : Easing.OutBack
            easing.overshoot: bar.activeView === "none" ? 0.6 : 0.45
        }
    }

    Timer {
        id: closeCleanup
        interval: 280
        onTriggered: bar.displayedView = "none"
    }

    ShellTheme { id: theme }

    function anchorFor(item) {
        const point = item.mapToItem(bar.contentItem, item.width / 2, item.height / 2)
        return bar.vertical ? point.y : point.x
    }

    function applicationIcon(appId) {
        const aliases = {
            "code": "vscode"
        }
        return Quickshell.iconPath(aliases[appId] || appId, true)
            || Quickshell.iconPath("application-x-executable", true)
    }

    function volumeIcon() {
        if (systemData.muted)
            return "󰝟"
        if (systemData.volume < 34)
            return "󰕿"
        if (systemData.volume < 67)
            return "󰖀"
        return "󰕾"
    }

    function brightnessIcon() {
        const icons = ["󰃙", "󰃚", "󰃛", "󰃜", "󰃝", "󰃟", "󰃠"]
        const index = Math.round(Math.max(0, Math.min(100, systemData.brightness)) * 6 / 100)
        return icons[index]
    }

    function batteryIcon() {
        if (systemData.batteryState === "Charging")
            return "󰂄"
        if (systemData.batteryState === "Full")
            return "󰁹"
        const icons = ["󰂎", "󰁺", "󰁼", "󰁿", "󰂁", "󰁹"]
        return icons[Math.max(0, Math.min(5, Math.floor(systemData.battery / 20)))]
    }

    function batteryColor() {
        if (systemData.batteryState === "Charging" || systemData.batteryState === "Full")
            return theme.success
        if (systemData.batteryState === "Discharging" || systemData.batteryState === "Pending discharge") {
            if (systemData.battery <= 15)
                return theme.error
            if (systemData.battery <= 30)
                return theme.warning
        }
        return theme.accent
    }

    function focusWorkspace(workspace) {
        Quickshell.execDetached([
            "niri", "msg", "action", "focus-workspace",
            String(workspace.name !== null ? workspace.name : workspace.idx)
        ])
    }

    Item {
        id: dismissLayer
        anchors.fill: parent
        z: 0
        visible: bar.activeView !== "none"

        MouseArea {
            anchors.fill: parent
            onClicked: bar.closeDrawer()
        }
    }

    Item {
        id: drawerContainer
        z: 5
        x: bar.vertical
            ? bar.railWidth
            : Math.max(12, Math.min(bar.width - bar.renderedDrawerWidth - 12, bar.drawerAnchor - bar.renderedDrawerWidth / 2))
        y: bar.vertical
            ? Math.max(0, Math.min(bar.height - bar.renderedDrawerHeight, bar.drawerAnchor - bar.renderedDrawerHeight / 2))
            : bar.railWidth
        width: bar.renderedDrawerWidth * (bar.vertical ? Math.min(1, Math.max(0, bar.reveal)) : 1)
        height: bar.renderedDrawerHeight * (bar.vertical ? 1 : Math.min(1, Math.max(0, bar.reveal)))
        visible: bar.displayedView !== "none" && bar.reveal > 0.005
        opacity: Math.min(1, bar.reveal * 1.25)

        Behavior on y {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        Behavior on x {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        Rectangle {
            x: bar.vertical
                ? -10
                : Math.max(20, Math.min(parent.width - width - 20, bar.drawerAnchor - drawerContainer.x - width / 2))
            y: bar.vertical
                ? Math.max(20, Math.min(parent.height - height - 20, bar.drawerAnchor - drawerContainer.y - height / 2))
                : -10
            width: bar.vertical ? 20 : 58
            height: bar.vertical ? 58 : 20
            radius: 10
            color: "#f0131819"
            border.width: 1
            border.color: theme.border
        }

        Item {
            anchors.fill: parent
            clip: true

            Loader {
                id: drawerLoader
                width: bar.drawerWidth
                height: bar.drawerHeight
                scale: bar.drawerScale
                transformOrigin: Item.TopLeft
                sourceComponent: bar.displayedView === "clock"
                    ? clockDrawer
                    : (bar.displayedView === "power" ? powerDrawer : (bar.displayedView === "fan" ? fanDrawer : null))
            }
        }
    }

    Component {
        id: clockDrawer
        ClockDashboard { systemData: bar.systemData }
    }

    Component {
        id: powerDrawer
        PowerControl {
            systemData: bar.systemData
            powerData: bar.powerData
        }
    }

    Component {
        id: fanDrawer
        FanControl { powerData: bar.powerData }
    }

    Item {
        id: railSurface
        z: 10
        x: 0
        y: 0
        width: bar.railWidth
        height: parent.height
        visible: bar.vertical

        Rectangle {
            anchors {
                top: parent.top
                bottom: parent.bottom
                topMargin: 10
                bottomMargin: 10
                horizontalCenter: parent.horizontalCenter
            }
            width: 46
            radius: 18
            color: theme.background
            border.width: 1
            border.color: theme.border
        }

        Item {
            id: topZone
            anchors.top: parent.top
            width: parent.width
            height: Math.max(0, controlsSegment.y - 7)
            clip: true

            Rectangle {
                id: workspaceSegment
                anchors {
                    top: parent.top
                    topMargin: 18
                    horizontalCenter: parent.horizontalCenter
                }
                width: 36
            height: workspaceColumn.implicitHeight + 8
            radius: 12
            color: "#12ffffff"
            border.width: 1
            border.color: "#1affffff"

            Column {
                id: workspaceColumn
                anchors.centerIn: parent

                Repeater {
                    model: bar.niriData.workspacesFor(bar.screen.name)

                    Item {
                        required property var modelData
                        width: 34
                        height: modelData.is_active ? 30 : 20

                        Behavior on height {
                            NumberAnimation { duration: 180; easing.type: Easing.OutBack }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 8
                            height: parent.modelData.is_active ? 24 : 8
                            radius: 4
                            color: theme.accent
                            opacity: parent.modelData.is_active ? 1 : 0.65

                            Behavior on height {
                                NumberAnimation { duration: 180; easing.type: Easing.OutBack }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: bar.focusWorkspace(parent.modelData)
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: event => {
                    Quickshell.execDetached([
                        "niri", "msg", "action",
                        event.angleDelta.y > 0 ? "focus-workspace-up" : "focus-workspace-down"
                    ])
                    event.accepted = true
                }
            }
            }

            Rectangle {
                id: activeAppSegment
                anchors {
                    top: workspaceSegment.bottom
                    topMargin: 7
                    horizontalCenter: parent.horizontalCenter
                }
                visible: bar.currentWindow !== null
                width: 36
                height: 46
                radius: 12
                color: "#12ffffff"
                border.width: 1
                border.color: "#1affffff"

                Rectangle {
                    id: activeAppButton
                    anchors.centerIn: parent
                    width: 34
                    height: 38
                    radius: 11
                    color: activeAppMouse.containsMouse ? theme.cardHover : "transparent"

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 20
                        source: bar.applicationIcon(bar.currentWindow ? bar.currentWindow.app_id : "")
                        scale: activeAppMouse.containsMouse ? 1.12 : 1

                        Behavior on scale {
                            NumberAnimation { duration: 160; easing.type: Easing.OutBack }
                        }
                    }

                    MouseArea {
                        id: activeAppMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    HoverTooltip {
                        target: activeAppButton
                        shown: activeAppMouse.containsMouse
                        text: bar.currentWindow ? (bar.currentWindow.title || bar.currentWindow.app_id || "") : ""
                    }
                }
            }

            Rectangle {
                id: traySegment
                anchors {
                    top: activeAppSegment.visible ? activeAppSegment.bottom : workspaceSegment.bottom
                    topMargin: 7
                    horizontalCenter: parent.horizontalCenter
                }
                visible: trayColumn.implicitHeight > 0
                width: 36
                height: trayColumn.implicitHeight + 8
                radius: 12
                color: "#12ffffff"
                border.width: 1
                border.color: "#1affffff"

                Column {
                    id: trayColumn
                    anchors.centerIn: parent

                    Repeater {
                        id: trayRepeater
                        model: SystemTray.items

                        TrayItem {
                            required property var modelData
                            visible: shown
                            width: shown ? 34 : 0
                            height: shown ? 34 : 0
                            hostWindow: bar
                            trayItem: modelData
                        }
                    }
                }
            }
        }

        Rectangle {
            id: controlsSegment
            anchors {
                bottom: resourceSegment.top
                bottomMargin: 7
                horizontalCenter: parent.horizontalCenter
            }
            width: 36
            height: controlsColumn.implicitHeight + 8
            radius: 12
            color: "#12ffffff"
            border.width: 1
            border.color: "#1affffff"

            Column {
                id: controlsColumn
                anchors.centerIn: parent

                SystemButton {
                    width: 34
                    text: "⇄"
                    fontPixelSize: 17
                    tooltip: "Move bar to top"
                    onClicked: bar.toggleOrientation()
                }

                SystemButton {
                    width: 34
                    text: "󰅌"
                    tooltip: "Clipboard history"
                    onClicked: Quickshell.execDetached(["sh", bar.clipboardScriptPath])
                }

                SystemButton {
                    width: 34
                    text: bar.systemData.bluetooth === "connected" ? "󰂱" : (bar.systemData.bluetooth === "on" ? "󰂯" : "󰂲")
                    tooltip: bar.systemData.bluetooth === "connected"
                        ? `Bluetooth: ${bar.systemData.bluetoothDevice}`
                        : `Bluetooth ${bar.systemData.bluetooth}`
                    onClicked: Quickshell.execDetached(["blueman-manager"])
                }

                SystemButton {
                    width: 34
                    text: bar.systemData.network === "wifi" ? "󰤢" : (bar.systemData.network === "ethernet" ? "󰈀" : "󰤠")
                    tooltip: bar.systemData.network === "wifi"
                        ? `${bar.systemData.ssid} (${bar.systemData.signal}%)`
                        : bar.systemData.network
                    onClicked: Quickshell.execDetached(["ghostty", "-e", "nmtui"])
                }

                SystemButton {
                    width: 34
                    text: bar.volumeIcon()
                    tooltip: bar.systemData.muted
                        ? `Volume: ${bar.systemData.volume}% (muted)`
                        : `Volume: ${bar.systemData.volume}%`
                    onClicked: Quickshell.execDetached(["pavucontrol"])
                    onWheel: delta => Quickshell.execDetached([
                        "bash", bar.osdScriptPath, "volume", delta > 0 ? "raise" : "lower"
                    ])
                }

                SystemButton {
                    width: 34
                    text: bar.brightnessIcon()
                    tooltip: `Brightness: ${bar.systemData.brightness}%`
                    onWheel: delta => Quickshell.execDetached([
                        "bash", bar.osdScriptPath, "brightness", delta > 0 ? "raise" : "lower"
                    ])
                }

            }
        }

        Rectangle {
            id: resourceSegment
            anchors {
                bottom: statusSegment.top
                bottomMargin: 7
                horizontalCenter: parent.horizontalCenter
            }
            width: 36
            height: resourceColumn.implicitHeight + 8
            radius: 12
            color: "#12ffffff"
            border.width: 1
            border.color: "#1affffff"

            Column {
                id: resourceColumn
                anchors.centerIn: parent

                SystemButton {
                    width: 34
                    text: "󰒋"
                    tooltip: "Toggle Resources"
                    onClicked: bar.openResources()
                }

                SystemButton {
                    id: fanButton
                    width: 34
                    text: "󰈐"
                    active: bar.activeView === "fan"
                    tooltip: "Fan monitor"
                    onClicked: bar.toggleDrawer("fan", bar.anchorFor(fanButton))
                }

                SystemButton {
                    width: 34
                    height: 46
                    text: `\n${bar.systemData.cpuUsage}%`
                    tooltip: `CPU usage: ${bar.systemData.cpuUsage}%`
                    onClicked: bar.openResources()
                }

                SystemButton {
                    width: 34
                    height: 46
                    text: `\n${bar.systemData.memoryPercent}%`
                    tooltip: `RAM: ${bar.systemData.memoryUsed.toFixed(1)} / ${bar.systemData.memoryTotal.toFixed(1)} GB`
                    onClicked: bar.openResources()
                }

            }
        }

        Rectangle {
            id: statusSegment
            anchors {
                bottom: parent.bottom
                bottomMargin: 18
                horizontalCenter: parent.horizontalCenter
            }
            width: 36
            height: statusColumn.implicitHeight + 8
            radius: 12
            color: "#12ffffff"
            border.width: 1
            border.color: "#1affffff"

            Column {
                id: statusColumn
                anchors.centerIn: parent

                SystemButton {
                    id: batteryButton
                    width: 34
                    height: 48
                    text: `${bar.batteryIcon()}\n${bar.systemData.battery}%`
                    foreground: bar.batteryColor()
                    active: bar.activeView === "power"
                    tooltip: `${bar.systemData.batteryState}\n${bar.systemData.batteryTime}\n${bar.systemData.batteryPower.toFixed(1)} W`
                    onClicked: bar.toggleDrawer("power", bar.anchorFor(batteryButton))
                }

                SystemButton {
                    id: clockButton
                    width: 34
                    height: 48
                    text: Qt.formatDateTime(clock.date, "hh\nmm\nAP")
                    active: bar.activeView === "clock"
                    tooltip: Qt.formatDateTime(clock.date, "dddd, MMMM dd")
                    onClicked: bar.toggleDrawer("clock", bar.anchorFor(clockButton))
                }

                SystemButton {
                    width: 34
                    text: "󰐥"
                    tooltip: "Power menu"
                    onClicked: Quickshell.execDetached(["wlogout", "--buttons-per-row", "2"])
                }
            }
        }
    }

    HorizontalBarSurface {
        id: horizontalSurface
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: bar.railWidth
        panel: bar
        visible: !bar.vertical
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}
