import QtQuick
import Quickshell

PanelWindow {
    id: bar

    required property var systemData
    required property var niriData

    signal toggleSystemMonitor()
    signal toggleClockDashboard()
    signal togglePowerControl()
    signal toggleFanControl()

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 38
    exclusiveZone: 38
    color: "transparent"

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

    function batteryColor() {
        if (systemData.batteryState === "Charging")
            return "#a6d189"
        if (systemData.battery <= 15)
            return "#e78284"
        if (systemData.battery <= 30)
            return "#e5c890"
        return "#99d1db"
    }

    function focusWorkspace(workspace) {
        Quickshell.execDetached([
            "niri", "msg", "action", "focus-workspace",
            String(workspace.name !== null ? workspace.name : workspace.idx)
        ])
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Row {
        id: leftModules

        anchors.left: parent.left
        anchors.leftMargin: 7
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Rectangle {
            id: workspaces

            implicitWidth: workspaceRow.implicitWidth + 8
            implicitHeight: 30
            radius: 15
            color: "#1a1b26"

            Row {
                id: workspaceRow

                anchors.centerIn: parent

                Repeater {
                    model: bar.niriData.workspacesFor(bar.screen.name)

                    Rectangle {
                        required property var modelData

                        implicitWidth: 22
                        implicitHeight: 26
                        radius: 13
                        color: workspaceMouse.containsMouse
                            ? "#1a99d1db"
                            : (modelData.is_active ? "#12c6d0f5" : "transparent")

                        Text {
                            anchors.centerIn: parent
                            text: "●"
                            color: modelData.is_urgent
                                ? "#e78284"
                                : (modelData.is_focused
                                    ? "#bd93f9"
                                    : (modelData.is_active ? "#c6d0f5" : "#44475a"))
                            font.pixelSize: 8
                        }

                        MouseArea {
                            id: workspaceMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: bar.focusWorkspace(modelData)
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
                        event.angleDelta.y > 0
                            ? "focus-workspace-up"
                            : "focus-workspace-down"
                    ])
                    event.accepted = true
                }
            }
        }

        Pill {
            maximumWidth: 190
            visible: bar.niriData.focusedWindow !== null
            text: bar.niriData.focusedWindow
                ? (bar.niriData.focusedWindow.title || bar.niriData.focusedWindow.app_id || "")
                : ""
            tooltip: text
        }
    }

    Pill {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        foreground: "#99d1db"
        text: Qt.formatDateTime(clock.date, "hh:mm:ss AP  -  MMMM dd, dddd")
        onClicked: bar.toggleClockDashboard()
    }

    Rectangle {
        id: rightGroup

        anchors.right: parent.right
        anchors.rightMargin: 7
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: rightModules.implicitWidth
        implicitHeight: 30
        radius: 15
        color: "#1a1b26"
        clip: true

        Row {
            id: rightModules

            SystemButton {
                text: "󰒋"
                tooltip: "Toggle System Resource Monitor"
                onClicked: bar.toggleSystemMonitor()
            }

            SystemButton {
                text: bar.systemData.bluetooth === "connected"
                    ? "󰂱"
                    : (bar.systemData.bluetooth === "on" ? "󰂯" : "󰂲")
                foreground: bar.systemData.bluetooth === "connected"
                    ? "#99d1db"
                    : (bar.systemData.bluetooth === "on" ? "#2196f3" : "#888888")
                tooltip: bar.systemData.bluetooth === "connected"
                    ? `Bluetooth: ${bar.systemData.bluetoothDevice}`
                    : `Bluetooth ${bar.systemData.bluetooth}`
                onClicked: Quickshell.execDetached(["blueman-manager"])
            }

            SystemButton {
                text: bar.systemData.network === "wifi"
                    ? "󰤢"
                    : (bar.systemData.network === "ethernet" ? "󰈀" : "󰤠")
                foreground: bar.systemData.network === "disconnected" ? "#e78284" : "#c6d0f5"
                tooltip: bar.systemData.network === "wifi"
                    ? `${bar.systemData.ssid} (${bar.systemData.signal}%)`
                    : bar.systemData.network
                onClicked: Quickshell.execDetached(["ghostty", "-e", "nmtui"])
            }

            SystemButton {
                text: bar.systemData.muted
                    ? `${bar.volumeIcon()} muted`
                    : `${bar.volumeIcon()} ${bar.systemData.volume}%`
                tooltip: bar.systemData.muted ? "Audio muted" : `Volume: ${bar.systemData.volume}%`
                onClicked: Quickshell.execDetached(["pavucontrol"])
                onWheel: delta => Quickshell.execDetached([
                    "wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@",
                    delta > 0 ? "5%+" : "5%-"
                ])
            }

            SystemButton {
                text: `${bar.brightnessIcon()}  ${bar.systemData.brightness}%`
                tooltip: `Brightness: ${bar.systemData.brightness}%`
                onWheel: delta => Quickshell.execDetached([
                    "brightnessctl", "set", delta > 0 ? "+5%" : "5%-"
                ])
            }

            SystemButton {
                text: "󰈐"
                foreground: "#758083"
                tooltip: "Fan monitor"
                onClicked: bar.toggleFanControl()
            }

            SystemButton {
                text: `${bar.batteryIcon()} ${bar.systemData.battery}%`
                foreground: bar.batteryColor()
                tooltip: `${bar.systemData.batteryState}\n${bar.systemData.batteryTime}\n${bar.systemData.batteryPower.toFixed(1)} W`
                onClicked: bar.togglePowerControl()
            }

            SystemButton {
                text: "󰐥"
                foreground: "#babbf1"
                tooltip: "Power menu"
                onClicked: Quickshell.execDetached(["wlogout", "--buttons-per-row", "2"])
            }
        }
    }
}
