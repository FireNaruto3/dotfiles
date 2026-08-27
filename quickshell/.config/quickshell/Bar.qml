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
    property string activeView: "none"
    property real drawerAnchorX: width / 2
    property string displayedView: "none"
    property real reveal: activeView === "none" ? 0 : 1
    readonly property var currentWindow: niriData.focusedWindowFor(screen ? screen.name : "")
    readonly property string osdScriptPath: Qt.resolvedUrl("scripts/osd-control.sh").toString().replace("file://", "")
    readonly property real drawerWidth: displayedView === "clock" ? 440 : 350
    readonly property real drawerHeight: displayedView === "clock"
        ? 478
        : (displayedView === "fan" ? 176 : (drawerLoader.item ? drawerLoader.item.implicitHeight : 397))

    signal openResources()
    signal toggleDrawer(string view, real anchorX)
    signal closeDrawer()

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: screen ? screen.height : 1080
    exclusiveZone: 46
    color: "transparent"
    aboveWindows: true
    focusable: false

    WlrLayershell.namespace: "jonathan-shell-bar"

    mask: Region {
        Region { item: barSurface }
        Region { item: bar.activeView !== "none" ? dismissLayer : null }
        Region { item: drawerContainer.visible ? drawerContainer : null }
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
        return item.mapToItem(bar.contentItem, item.width / 2, 0).x
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
        if (systemData.brightness < 20)
            return "󰃜"
        if (systemData.brightness < 50)
            return "󰃝"
        if (systemData.brightness < 80)
            return "󰃟"
        return "󰃠"
    }

    function batteryIcon() {
        if (systemData.batteryState === "Charging")
            return "󰂄"
        if (systemData.batteryState === "Full")
            return "󰁹"
        const icons = ["󰂎", "󰁺", "󰁼", "󰁿", "󰂁", "󰁹"]
        return icons[Math.max(0, Math.min(5, Math.floor(systemData.battery / 20)))]
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
        x: Math.max(12, Math.min(bar.width - width - 12, bar.drawerAnchorX - width / 2))
        y: 46
        width: bar.drawerWidth
        height: bar.drawerHeight * Math.max(0, bar.reveal)
        visible: bar.displayedView !== "none" && bar.reveal > 0.005
        opacity: Math.min(1, bar.reveal * 1.25)

        Behavior on x {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        Rectangle {
            x: Math.max(20, Math.min(parent.width - width - 20, bar.drawerAnchorX - drawerContainer.x - width / 2))
            y: -10
            width: 58
            height: 20
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
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                height: bar.drawerHeight
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

    Rectangle {
        id: barSurface
        z: 10
        x: 12
        y: 0
        width: parent.width - 24
        height: 46
        radius: 18
        color: theme.background
        border.width: 1
        border.color: theme.border

        Rectangle {
            id: leftCard
            anchors {
                right: parent.right
                rightMargin: 18
                verticalCenter: parent.verticalCenter
            }
            implicitWidth: leftModules.implicitWidth + 8
            implicitHeight: 36
            radius: 12
            color: "#12ffffff"
            border.width: 1
            border.color: "#1affffff"
            clip: true

            Row {
                id: leftModules
                anchors.centerIn: parent

                SystemButton {
                    text: "󰒋"
                    tooltip: "Toggle Resources"
                    onClicked: bar.openResources()
                }

                SystemButton {
                    text: bar.systemData.bluetooth === "connected" ? "󰂱" : (bar.systemData.bluetooth === "on" ? "󰂯" : "󰂲")
                    foreground: theme.accent
                    tooltip: bar.systemData.bluetooth === "connected"
                        ? `Bluetooth: ${bar.systemData.bluetoothDevice}`
                        : `Bluetooth ${bar.systemData.bluetooth}`
                    onClicked: Quickshell.execDetached(["blueman-manager"])
                }

                SystemButton {
                    text: bar.systemData.network === "wifi" ? "󰤢" : (bar.systemData.network === "ethernet" ? "󰈀" : "󰤠")
                    foreground: theme.accent
                    tooltip: bar.systemData.network === "wifi"
                        ? `${bar.systemData.ssid} (${bar.systemData.signal}%)`
                        : bar.systemData.network
                    onClicked: Quickshell.execDetached(["ghostty", "-e", "nmtui"])
                }

                SystemButton {
                    text: bar.volumeIcon()
                    tooltip: bar.systemData.muted
                        ? `Volume: ${bar.systemData.volume}% (muted)`
                        : `Volume: ${bar.systemData.volume}%`
                    foreground: theme.accent
                    onClicked: Quickshell.execDetached(["pavucontrol"])
                    onWheel: delta => Quickshell.execDetached([
                        "bash", bar.osdScriptPath, "volume", delta > 0 ? "raise" : "lower"
                    ])
                }

                SystemButton {
                    text: bar.brightnessIcon()
                    tooltip: `Brightness: ${bar.systemData.brightness}%`
                    onWheel: delta => Quickshell.execDetached([
                        "bash", bar.osdScriptPath, "brightness", delta > 0 ? "raise" : "lower"
                    ])
                }

                SystemButton {
                    id: fanButton
                    text: "󰈐"
                    active: bar.activeView === "fan"
                    foreground: theme.accent
                    tooltip: "Fan monitor"
                    onClicked: bar.toggleDrawer("fan", bar.anchorFor(fanButton))
                }

                SystemButton {
                    id: batteryButton
                    text: `${bar.batteryIcon()} ${bar.systemData.battery}%`
                    active: bar.activeView === "power"
                    foreground: theme.accent
                    tooltip: `${bar.systemData.batteryState}\n${bar.systemData.batteryTime}\n${bar.systemData.batteryPower.toFixed(1)} W`
                    onClicked: bar.toggleDrawer("power", bar.anchorFor(batteryButton))
                }

                SystemButton {
                    text: "󰐥"
                    foreground: theme.accent
                    tooltip: "Power menu"
                    onClicked: Quickshell.execDetached(["wlogout", "--buttons-per-row", "2"])
                }
            }
        }

        Rectangle {
            id: activeWindowCard
            anchors.centerIn: parent
            visible: bar.currentWindow !== null
            width: Math.min(220, Math.max(46, activeWindowRow.implicitWidth + 20))
            height: 36
            radius: 12
            color: activeWindowMouse.containsMouse ? theme.cardHover : "#12ffffff"
            border.width: 1
            border.color: activeWindowMouse.containsMouse ? theme.border : "#1affffff"
            clip: true

            Behavior on width {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            Row {
                id: activeWindowRow
                anchors.centerIn: parent
                spacing: 8

                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 18
                    source: Quickshell.iconPath(bar.currentWindow ? bar.currentWindow.app_id : "", true)
                        || Quickshell.iconPath("application-x-executable", true)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(170, implicitWidth)
                    text: bar.currentWindow ? (bar.currentWindow.title || bar.currentWindow.app_id || "") : ""
                    color: theme.accent
                    font.family: theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: activeWindowMouse
                anchors.fill: parent
                hoverEnabled: true
            }

            HoverTooltip {
                target: activeWindowCard
                shown: activeWindowMouse.containsMouse
                text: bar.currentWindow ? (bar.currentWindow.title || "") : ""
            }
        }

        Rectangle {
            id: rightCard
            anchors {
                left: parent.left
                leftMargin: 18
                verticalCenter: parent.verticalCenter
            }
            implicitWidth: rightModules.implicitWidth + 8
            implicitHeight: 36
            radius: 12
            color: "#12ffffff"
            border.width: 1
            border.color: "#1affffff"
            clip: true

            Row {
                id: rightModules
                anchors.centerIn: parent

                Item {
                    id: workspaceArea
                    width: workspaceRow.implicitWidth
                    height: 34

                    Row {
                        id: workspaceRow
                        anchors.centerIn: parent

                        Repeater {
                            model: bar.niriData.workspacesFor(bar.screen.name)

                            Item {
                                required property var modelData
                                width: modelData.is_active ? 30 : 20
                                height: 34

                                Behavior on width {
                                    NumberAnimation { duration: 180; easing.type: Easing.OutBack }
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.modelData.is_active ? 24 : 8
                                    height: 8
                                    radius: 4
                                    color: theme.accent
                                    opacity: parent.modelData.is_active ? 1 : 0.65

                                    Behavior on width {
                                        NumberAnimation { duration: 180; easing.type: Easing.OutBack }
                                    }
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
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
                    y: 8
                    width: 1
                    height: 18
                    color: theme.border
                    visible: workspaceArea.width > 0
                }

                Row {
                    visible: trayRepeater.count > 0

                    Repeater {
                        id: trayRepeater
                        model: SystemTray.items.values.filter(item => item.status !== Status.Passive)

                        TrayItem {
                            required property var modelData
                            hostWindow: bar
                            trayItem: modelData
                        }
                    }
                }

                SystemButton {
                    id: clockButton
                    text: Qt.formatDateTime(clock.date, "hh:mm AP  ·  MMM dd")
                    active: bar.activeView === "clock"
                    foreground: theme.accent
                    horizontalPadding: 11
                    tooltip: Qt.formatDateTime(clock.date, "dddd, MMMM dd")
                    onClicked: bar.toggleDrawer("clock", bar.anchorFor(clockButton))
                }
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}
