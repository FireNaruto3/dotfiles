import QtQuick
import Quickshell

PanelWindow {
    id: window

    required property var powerData

    function fanRpmValue(fan) {
        if (!fan.rpmAvailable)
            return "Unavailable"
        if (fan.rpm <= 0)
            return "Off"
        return `${fan.rpm} RPM`
    }

    function fanCurveDetail(fan) {
        if (fan.rpmOnly)
            return "RPM only"
        if (!fan.curveAvailable)
            return "Curve unavailable"
        if (!fan.curveEnabled)
            return "Firmware auto"
        if (!fan.temperatureAvailable) {
            if (fan.temperatureState === "suspended")
                return "dGPU suspended"
            if (fan.temperatureState === "disabled")
                return "dGPU disabled"
            if (fan.temperatureState === "active")
                return "dGPU active"
            return "Target unavailable"
        }

        const target = powerData.fanCurvePercent(
            fan.curve,
            fan.temperature,
            fan.curveEnabled
        )
        return target >= 0 ? `${target}% @ ${fan.temperature}°C` : "Target unavailable"
    }

    function fanRpmColor(fan) {
        if (!fan.rpmAvailable)
            return "#e78284"
        return fan.rpm > 0 ? "#99d1db" : "#596468"
    }

    anchors {
        top: true
        right: true
    }
    margins {
        top: -4
        right: 7
    }

    implicitWidth: 350
    implicitHeight: 176
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false
    color: "transparent"

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
                    text: window.powerData.fanProfile
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
                    model: 3

                    Rectangle {
                        id: fanCard

                        required property int index

                        readonly property string fanLabel: index === 0 ? "CPU" : (index === 1 ? "GPU" : "MID")
                        readonly property int rpm: index === 0
                            ? window.powerData.cpuFan
                            : (index === 1 ? window.powerData.gpuFan : window.powerData.midFan)
                        readonly property bool rpmAvailable: index === 0
                            ? window.powerData.cpuFanAvailable
                            : (index === 1 ? window.powerData.gpuFanAvailable : window.powerData.midFanAvailable)
                        readonly property bool rpmOnly: index === 2
                        readonly property int temperature: index === 0
                            ? window.powerData.cpuTemp
                            : (index === 1 ? window.powerData.gpuTemp : 0)
                        readonly property bool temperatureAvailable: index === 0
                            ? window.powerData.cpuTempAvailable
                            : (index === 1 ? window.powerData.gpuTempAvailable : false)
                        readonly property string temperatureState: index === 0
                            ? (window.powerData.cpuTempAvailable ? "active" : "unavailable")
                            : (index === 1 ? window.powerData.gpuTempState : "")
                        readonly property bool curveAvailable: index === 0
                            ? window.powerData.cpuFanCurveAvailable
                            : (index === 1 ? window.powerData.gpuFanCurveAvailable : false)
                        readonly property bool curveEnabled: index === 0
                            ? window.powerData.cpuFanCurveEnabled
                            : (index === 1 ? window.powerData.gpuFanCurveEnabled : false)
                        readonly property var curve: index === 0
                            ? window.powerData.cpuFanCurve
                            : (index === 1 ? window.powerData.gpuFanCurve : [])

                        width: (window.width - 44) / 3
                        height: 92
                        radius: 7
                        color: "#b31a1b26"

                        Column {
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: fanCard.fanLabel
                                color: "#758083"
                                font.family: "JetBrains Mono Nerd Font"
                                font.pixelSize: 10
                                font.bold: true
                                font.letterSpacing: 2
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: window.fanRpmValue(fanCard)
                                color: window.fanRpmColor(fanCard)
                                font.family: "JetBrains Mono Nerd Font"
                                font.pixelSize: 11
                                font.bold: true
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: window.fanCurveDetail(fanCard)
                                color: "#8c999d"
                                font.family: "JetBrains Mono Nerd Font"
                                font.pixelSize: 9
                            }
                        }
                    }
                }
            }

        }
    }
}
