import QtQuick
import Quickshell

PanelWindow {
    id: window

    required property var systemData
    required property var powerData

    readonly property var fans: [
        { label: "CPU", rpm: powerData.cpuFan, detail: `${systemData.cpuTemp}°C` },
        { label: "GPU", rpm: powerData.gpuFan, detail: "Discrete" },
        { label: "MID", rpm: powerData.midFan, detail: "System" }
    ]

    anchors {
        top: true
        right: true
    }
    margins {
        top: -4
        right: 7
    }

    implicitWidth: 350
    implicitHeight: 226
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false
    color: "transparent"

    onVisibleChanged: {
        if (visible)
            powerData.refresh()
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: "#f0131819"
        border.width: 1
        border.color: "#29b4dcdc"

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Row {
                width: parent.width
                height: 28

                Text {
                    width: parent.width / 2
                    text: "󰈐  Fan Monitor"
                    color: "#d8e0e3"
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 15
                    font.bold: true
                }

                Text {
                    width: parent.width / 2
                    horizontalAlignment: Text.AlignRight
                    text: window.powerData.asusProfile
                    color: "#a9f3d1"
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 11
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#2ec8e6e6" }

            Row {
                width: parent.width
                spacing: 8

                Repeater {
                    model: window.fans

                    Rectangle {
                        required property var modelData

                        width: (window.width - 44) / 3
                        height: 92
                        radius: 7
                        color: "#b31a1b26"

                        Column {
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                color: "#758083"
                                font.family: "JetBrains Mono Nerd Font"
                                font.pixelSize: 10
                                font.bold: true
                                font.letterSpacing: 2
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.rpm > 0 ? `${modelData.rpm} RPM` : "Off"
                                color: modelData.rpm > 0 ? "#99d1db" : "#596468"
                                font.family: "JetBrains Mono Nerd Font"
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.detail
                                color: "#8c999d"
                                font.family: "JetBrains Mono Nerd Font"
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 38
                radius: 7
                color: editorMouse.containsMouse ? "#80669970" : "#293f4749"

                Text {
                    anchors.centerIn: parent
                    text: "󰒓  Open Fan Curves"
                    color: "#c9d3d6"
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 11
                    font.bold: true
                }

                MouseArea {
                    id: editorMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Quickshell.execDetached(["rog-control-center"])
                }
            }
        }
    }
}
