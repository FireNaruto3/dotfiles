import QtQuick
import Quickshell

Item {
    id: window

    required property var powerData

    ShellTheme { id: theme }

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
            return theme.error
        return fan.rpm > 0 ? theme.accent : theme.textMuted
    }

    implicitWidth: 350
    implicitHeight: 176

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: theme.background
        border.width: 1
        border.color: theme.border

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
                    color: theme.text
                    font.family: theme.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                }

                Text {
                    width: parent.width / 2
                    horizontalAlignment: Text.AlignRight
                    text: window.powerData.fanProfile
                    color: theme.accent
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                }
            }

            Rectangle { width: parent.width; height: 1; color: theme.border }

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
                        color: theme.card

                        Column {
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: fanCard.fanLabel
                                color: theme.textMuted
                                font.family: theme.fontFamily
                                font.pixelSize: 10
                                font.bold: true
                                font.letterSpacing: 2
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: window.fanRpmValue(fanCard)
                                color: window.fanRpmColor(fanCard)
                                font.family: theme.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: window.fanCurveDetail(fanCard)
                                color: theme.textMuted
                                font.family: theme.fontFamily
                                font.pixelSize: 9
                            }
                        }
                    }
                }
            }

        }
    }
}
