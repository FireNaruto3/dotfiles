import QtQuick
import Quickshell

PanelWindow {
    id: window

    required property var systemData

    anchors {
        top: true
        right: true
    }
    margins {
        top: 0
        right: 7
    }

    implicitWidth: 606
    implicitHeight: 315
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: 5
        color: "#e6131819"
        border.width: 1
        border.color: "#29b4dcdc"

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.top: parent.top
            anchors.topMargin: 10
            spacing: 7

            Text {
                text: "󰒋"
                color: "#cfeaff"
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 18
            }

            Text {
                text: "System Resource Monitor"
                color: "#c9d3d6"
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 19
                font.bold: true
                font.letterSpacing: 1
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            y: 52
            height: 2
            color: "#2ec8e6e6"
        }

        Row {
            id: grid

            x: 10
            y: 64
            width: parent.width - 20
            height: parent.height - 76

            Item {
                width: 194
                height: grid.height

                ArcGauge {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    value: window.systemData.cpu
                    accent: "#a9f3d1"
                    icon: "󰍛"
                }

                Text {
                    anchors.top: parent.top
                    anchors.topMargin: 112
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "CPU"
                    color: "#758083"
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 15
                    font.bold: true
                    font.letterSpacing: 5
                }

                Row {
                    anchors.top: parent.top
                    anchors.topMargin: 145
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 5

                    Repeater {
                        model: 8

                        Rectangle {
                            width: 9
                            height: 54
                            radius: 2
                            color: "#385f6a6a"

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: Math.max(8, parent.height * window.systemData.cpu / 100)
                                radius: 2
                                color: "#a9f3d1"
                            }
                        }
                    }
                }

                MetricRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.top: parent.top
                    anchors.topMargin: 205
                    name: "Temp"
                    value: `${window.systemData.cpuTemp}°C`
                    valueColor: "#a9f3d1"
                }

                MetricRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.top: parent.top
                    anchors.topMargin: 226
                    name: "Load"
                    value: `${window.systemData.load1}  ${window.systemData.load5}  ${window.systemData.load15}`
                }
            }

            Rectangle {
                width: 1
                height: grid.height - 8
                color: "#2178878a"
            }

            Item {
                width: 194
                height: grid.height

                ArcGauge {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    value: window.systemData.gpu
                    accent: "#a9f3d1"
                    icon: "󰢮"
                }

                Text {
                    anchors.top: parent.top
                    anchors.topMargin: 112
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "GPU"
                    color: "#758083"
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 15
                    font.bold: true
                    font.letterSpacing: 5
                }

                MetricRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.top: parent.top
                    anchors.topMargin: 157
                    name: "Clock"
                    value: window.systemData.gpuClock
                }

                MetricRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.top: parent.top
                    anchors.topMargin: 181
                    name: "Max"
                    value: window.systemData.gpuMaxClock
                }
            }

            Rectangle {
                width: 1
                height: grid.height - 8
                color: "#2178878a"
            }

            Item {
                width: 194
                height: grid.height

                ArcGauge {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    value: window.systemData.memoryPercent
                    accent: "#ffe7a8"
                    icon: "󰘚"
                }

                Text {
                    anchors.top: parent.top
                    anchors.topMargin: 112
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "MEM"
                    color: "#758083"
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 15
                    font.bold: true
                    font.letterSpacing: 5
                }

                MetricRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.top: parent.top
                    anchors.topMargin: 151
                    name: "Used"
                    value: `${window.systemData.memoryUsed.toFixed(2)} / ${window.systemData.memoryTotal.toFixed(2)}G`
                }

                MetricRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.top: parent.top
                    anchors.topMargin: 175
                    name: "Cache"
                    value: window.systemData.memoryCache.toFixed(2)
                }

                MetricRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.top: parent.top
                    anchors.topMargin: 199
                    name: "Swap"
                    value: `${window.systemData.swapUsed.toFixed(2)} / ${window.systemData.swapTotal.toFixed(2)}`
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.top: parent.top
                    anchors.topMargin: 228
                    height: 7
                    radius: 2
                    color: "#4078878a"

                    Rectangle {
                        width: parent.width * window.systemData.memoryPercent / 100
                        height: parent.height
                        radius: 2
                        color: "#a9f3d1"
                    }
                }
            }

        }
    }
}
