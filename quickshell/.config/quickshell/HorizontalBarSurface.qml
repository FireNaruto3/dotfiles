import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Item {
    id: root

    required property var panel

    ShellTheme { id: theme }

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            leftMargin: 10
            rightMargin: 10
        }
        height: 46
        radius: 18
        color: theme.background
        border.width: 1
        border.color: theme.border

        Rectangle {
            id: workspaceCard
            anchors {
                left: parent.left
                leftMargin: 18
                verticalCenter: parent.verticalCenter
            }
            width: leftModules.implicitWidth + 8
            height: 36
            radius: 12
            color: "#12ffffff"
            border.width: 1
            border.color: "#1affffff"

            Row {
                id: leftModules
                anchors.centerIn: parent

                Item {
                    width: workspaceRow.implicitWidth
                    height: 34

                    Row {
                        id: workspaceRow
                        anchors.centerIn: parent

                        Repeater {
                            model: root.panel.niriData.workspacesFor(root.panel.screen.name)

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
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.panel.focusWorkspace(parent.modelData)
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

            }
        }

        Rectangle {
            id: clockCard
            anchors {
                left: workspaceCard.right
                leftMargin: 7
                verticalCenter: parent.verticalCenter
            }
            width: clockButton.implicitWidth + 8
            height: 36
            radius: 12
            color: "#12ffffff"
            border.width: 1
            border.color: "#1affffff"

            SystemButton {
                id: clockButton
                anchors.centerIn: parent
                text: Qt.formatDateTime(clock.date, "hh:mm AP  ·  MMM dd")
                active: root.panel.activeView === "clock"
                horizontalPadding: 11
                tooltip: Qt.formatDateTime(clock.date, "dddd, MMMM dd")
                tooltipRight: false
                onClicked: root.panel.toggleDrawer("clock", root.panel.anchorFor(clockButton))
            }
        }

        Rectangle {
            id: trayCard
            anchors {
                left: clockCard.right
                leftMargin: 7
                verticalCenter: parent.verticalCenter
            }
            visible: trayRow.implicitWidth > 0
            width: trayRow.implicitWidth + 8
            height: 36
            radius: 12
            color: "#12ffffff"
            border.width: 1
            border.color: "#1affffff"

            Row {
                id: trayRow
                anchors.centerIn: parent

                Repeater {
                    id: trayRepeater
                    model: SystemTray.items

                    TrayItem {
                        required property var modelData
                        visible: shown
                        width: shown ? 28 : 0
                        height: shown ? 34 : 0
                        hostWindow: root.panel
                        trayItem: modelData
                        vertical: false
                    }
                }
            }
        }

        Rectangle {
            id: activeWindowCard
            anchors.centerIn: parent
            visible: root.panel.currentWindow !== null
            width: Math.min(280, Math.max(46, activeWindowRow.implicitWidth + 20))
            height: 36
            radius: 12
            color: activeWindowMouse.containsMouse ? theme.cardHover : "#12ffffff"
            border.width: 1
            border.color: activeWindowMouse.containsMouse ? theme.border : "#1affffff"
            clip: true

            Row {
                id: activeWindowRow
                anchors.centerIn: parent
                spacing: 8

                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 18
                    source: root.panel.applicationIcon(root.panel.currentWindow ? root.panel.currentWindow.app_id : "")
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(230, implicitWidth)
                    text: root.panel.currentWindow ? (root.panel.currentWindow.title || root.panel.currentWindow.app_id || "") : ""
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
                text: root.panel.currentWindow ? (root.panel.currentWindow.title || "") : ""
                openRight: false
            }
        }

        Rectangle {
            id: resourceCard
            anchors {
                right: controlsCard.left
                rightMargin: 7
                verticalCenter: parent.verticalCenter
            }
            width: resourceModules.implicitWidth + 8
            height: 36
            radius: 12
            color: "#12ffffff"
            border.width: 1
            border.color: "#1affffff"

            Row {
                id: resourceModules
                anchors.centerIn: parent

                SystemButton {
                    text: "󰒋"
                    tooltip: "Toggle Resources"
                    tooltipRight: false
                    onClicked: root.panel.openResources()
                }

                SystemButton {
                    id: fanButton
                    text: "󰈐"
                    active: root.panel.activeView === "fan"
                    tooltip: "Fan monitor"
                    tooltipRight: false
                    onClicked: root.panel.toggleDrawer("fan", root.panel.anchorFor(fanButton))
                }

                SystemButton {
                    text: ` ${root.panel.systemData.cpuUsage}%`
                    tooltip: `CPU usage: ${root.panel.systemData.cpuUsage}%`
                    tooltipRight: false
                    onClicked: root.panel.openResources()
                }

                SystemButton {
                    text: ` ${root.panel.systemData.memoryPercent}%`
                    tooltip: `RAM: ${root.panel.systemData.memoryUsed.toFixed(1)} / ${root.panel.systemData.memoryTotal.toFixed(1)} GB`
                    tooltipRight: false
                    onClicked: root.panel.openResources()
                }

            }
        }

        Rectangle {
            id: controlsCard
            anchors {
                right: parent.right
                rightMargin: 18
                verticalCenter: parent.verticalCenter
            }
            width: rightModules.implicitWidth + 8
            height: 36
            radius: 12
            color: "#12ffffff"
            border.width: 1
            border.color: "#1affffff"

            Row {
                id: rightModules
                anchors.centerIn: parent

                SystemButton {
                    text: "⇅"
                    fontPixelSize: 17
                    tooltip: "Move bar to left"
                    tooltipRight: false
                    onClicked: root.panel.toggleOrientation()
                }

                SystemButton {
                    text: "󰅌"
                    tooltip: "Clipboard history"
                    tooltipRight: false
                    onClicked: Quickshell.execDetached(["sh", root.panel.clipboardScriptPath])
                }

                SystemButton {
                    text: root.panel.systemData.bluetooth === "connected" ? "󰂱" : (root.panel.systemData.bluetooth === "on" ? "󰂯" : "󰂲")
                    tooltip: root.panel.systemData.bluetooth === "connected"
                        ? `Bluetooth: ${root.panel.systemData.bluetoothDevice}`
                        : `Bluetooth ${root.panel.systemData.bluetooth}`
                    tooltipRight: false
                    onClicked: Quickshell.execDetached(["blueman-manager"])
                }

                SystemButton {
                    text: root.panel.systemData.network === "wifi" ? "󰤢" : (root.panel.systemData.network === "ethernet" ? "󰈀" : "󰤠")
                    tooltip: root.panel.systemData.network === "wifi"
                        ? `${root.panel.systemData.ssid} (${root.panel.systemData.signal}%)`
                        : root.panel.systemData.network
                    tooltipRight: false
                    onClicked: Quickshell.execDetached(["ghostty", "-e", "nmtui"])
                }

                SystemButton {
                    text: root.panel.volumeIcon()
                    tooltip: root.panel.systemData.muted
                        ? `Volume: ${root.panel.systemData.volume}% (muted)`
                        : `Volume: ${root.panel.systemData.volume}%`
                    tooltipRight: false
                    onClicked: Quickshell.execDetached(["pavucontrol"])
                    onWheel: delta => Quickshell.execDetached([
                        "bash", root.panel.osdScriptPath, "volume", delta > 0 ? "raise" : "lower"
                    ])
                }

                SystemButton {
                    text: root.panel.brightnessIcon()
                    tooltip: `Brightness: ${root.panel.systemData.brightness}%`
                    tooltipRight: false
                    onWheel: delta => Quickshell.execDetached([
                        "bash", root.panel.osdScriptPath, "brightness", delta > 0 ? "raise" : "lower"
                    ])
                }

                SystemButton {
                    id: batteryButton
                    text: `${root.panel.batteryIcon()} ${root.panel.systemData.battery}%`
                    active: root.panel.activeView === "power"
                    tooltip: `${root.panel.systemData.batteryState}\n${root.panel.systemData.batteryTime}\n${root.panel.systemData.batteryPower.toFixed(1)} W`
                    tooltipRight: false
                    onClicked: root.panel.toggleDrawer("power", root.panel.anchorFor(batteryButton))
                }

                SystemButton {
                    text: "󰐥"
                    tooltip: "Power menu"
                    tooltipRight: false
                    onClicked: Quickshell.execDetached(["wlogout", "--buttons-per-row", "2"])
                }
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}
