import QtQuick
import Quickshell

PanelWindow {
    id: window

    required property var systemData
    required property var powerData
    property int chargeLimitPreview: -1
    property int keyboardPreview: -1
    readonly property int displayedChargeLimit: chargeLimitPreview >= 0
        ? chargeLimitPreview
        : powerData.chargeLimit
    readonly property int displayedKeyboardBrightness: keyboardPreview >= 0
        ? keyboardPreview
        : powerData.keyboardBrightness

    readonly property var powerProfiles: [
        { label: "Power Saver", value: "power-saver" },
        { label: "Balanced", value: "balanced" },
        { label: "Performance", value: "performance" }
    ]
    readonly property var displayModes: [
        { label: "60 Hz", refresh: 60 },
        { label: "120 Hz", refresh: 120 }
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
    implicitHeight: 397
        + (powerData.errorMessage.length > 0 ? 56 : 0)
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false
    color: "transparent"

    onVisibleChanged: {
        if (visible)
            powerData.refresh()
        chargeLimitPreview = -1
        keyboardPreview = -1
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
            spacing: 10

            Row {
                width: parent.width
                height: 54
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰁹"
                    color: "#99d1db"
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 28
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 48
                    spacing: 2

                    Text {
                        text: `${window.systemData.battery}% · ${window.systemData.batteryState}`
                        color: "#d8e0e3"
                        font.family: "JetBrains Mono Nerd Font"
                        font.pixelSize: 15
                        font.bold: true
                    }

                    Text {
                        text: `${window.systemData.batteryTime} · ${window.systemData.batteryPower.toFixed(1)} W`
                        color: "#758083"
                        font.family: "JetBrains Mono Nerd Font"
                        font.pixelSize: 11
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#2ec8e6e6" }

            Text {
                text: "DISPLAY REFRESH RATE"
                color: "#758083"
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 10
                font.bold: true
            }

            Row {
                width: parent.width
                spacing: 7

                Repeater {
                    model: window.displayModes

                    PowerChoice {
                        required property var modelData

                        width: (window.width - 35) / 2
                        label: modelData.label
                        selected: window.powerData.displayRefresh === modelData.refresh
                        enabled: !window.powerData.busy
                            && window.powerData.displayRefreshRates.indexOf(modelData.refresh) !== -1
                        onClicked: window.powerData.setDisplayRefresh(modelData.refresh)
                    }
                }
            }

            Text {
                text: "ACTIVE POWER PROFILE"
                color: "#758083"
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 10
                font.bold: true
            }

            Row {
                width: parent.width
                spacing: 7

                Repeater {
                    model: window.powerProfiles

                    PowerChoice {
                        required property var modelData

                        width: (window.width - 42) / 3
                        label: modelData.label
                        selected: window.powerData.powerProfile === modelData.value
                        enabled: !window.powerData.busy
                        onClicked: window.powerData.setPowerProfile(modelData.value)
                    }
                }
            }

            Item {
                width: parent.width
                height: 66

                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    text: "CHARGE LIMIT"
                    color: "#758083"
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 10
                    font.bold: true
                }

                Text {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    text: window.powerData.chargeLimit === 0
                        ? "Unavailable"
                        : `${window.displayedChargeLimit}%`
                    color: window.powerData.chargeLimit === 0 ? "#758083" : "#a9f3d1"
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 10
                }

                Rectangle {
                    id: chargeLimitTrack

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    height: 6
                    radius: 3
                    color: "#293f4749"
                    opacity: window.powerData.chargeLimit > 0 ? 1 : 0.4

                    Rectangle {
                        width: chargeLimitHandle.x + chargeLimitHandle.width / 2
                        height: parent.height
                        radius: parent.radius
                        color: "#63758d"
                    }

                    Repeater {
                        model: 5

                        Rectangle {
                            required property int index

                            x: chargeLimitHandle.width / 2 - width / 2
                                + index / 4 * (chargeLimitTrack.width - chargeLimitHandle.width)
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 10
                            radius: 1
                            color: "#8c999d"
                        }
                    }

                    Rectangle {
                        id: chargeLimitHandle

                        x: (Math.max(20, window.displayedChargeLimit) - 20) / 80
                            * (parent.width - width)
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        radius: 9
                        color: chargeLimitMouse.pressed ? "#a8c7f0" : "#99d1db"
                    }

                    MouseArea {
                        id: chargeLimitMouse

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 30
                        enabled: window.powerData.chargeLimit > 0 && !window.powerData.busy

                        function updateLimit(mouseX) {
                            const ratio = Math.max(0, Math.min(1, mouseX / width))
                            window.chargeLimitPreview = Math.round((20 + ratio * 80) / 5) * 5
                        }

                        onPressed: event => updateLimit(event.x)
                        onPositionChanged: event => {
                            if (pressed)
                                updateLimit(event.x)
                        }
                        onReleased: event => {
                            updateLimit(event.x)
                            window.powerData.setChargeLimit(window.chargeLimitPreview)
                            window.chargeLimitPreview = -1
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 66

                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    text: "KEYBOARD BACKLIGHT"
                    color: "#758083"
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 10
                    font.bold: true
                }

                Text {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    text: window.powerData.keyboardMax === 0
                        ? "Unavailable"
                        : (window.displayedKeyboardBrightness === 0
                            ? "Off"
                            : `${window.displayedKeyboardBrightness} / ${window.powerData.keyboardMax}`)
                    color: window.displayedKeyboardBrightness === 0 ? "#758083" : "#a9f3d1"
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 10
                }

                Rectangle {
                    id: keyboardTrack

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    height: 6
                    radius: 3
                    color: "#293f4749"
                    opacity: window.powerData.keyboardMax > 0 ? 1 : 0.4

                    Rectangle {
                        width: keyboardHandle.x + keyboardHandle.width / 2
                        height: parent.height
                        radius: parent.radius
                        color: "#63758d"
                    }

                    Repeater {
                        model: window.powerData.keyboardMax + 1

                        Rectangle {
                            required property int index

                            x: keyboardHandle.width / 2 - width / 2
                                + index / Math.max(1, window.powerData.keyboardMax)
                                    * (keyboardTrack.width - keyboardHandle.width)
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 10
                            radius: 1
                            color: "#8c999d"
                        }
                    }

                    Rectangle {
                        id: keyboardHandle

                        x: window.displayedKeyboardBrightness / Math.max(1, window.powerData.keyboardMax)
                            * (parent.width - width)
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        radius: 9
                        color: keyboardMouse.pressed ? "#a8c7f0" : "#99d1db"
                    }

                    MouseArea {
                        id: keyboardMouse

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 30
                        enabled: window.powerData.keyboardMax > 0 && !window.powerData.busy

                        function updateLevel(mouseX) {
                            const ratio = Math.max(0, Math.min(1, mouseX / width))
                            window.keyboardPreview = Math.round(ratio * window.powerData.keyboardMax)
                        }

                        onPressed: event => updateLevel(event.x)
                        onPositionChanged: event => {
                            if (pressed)
                                updateLevel(event.x)
                        }
                        onReleased: event => {
                            updateLevel(event.x)
                            window.powerData.setKeyboardBrightness(window.keyboardPreview)
                            window.keyboardPreview = -1
                        }
                    }
                }
            }

            Text {
                width: parent.width
                visible: window.powerData.errorMessage.length > 0
                text: window.powerData.errorMessage
                color: "#e78284"
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 10
            }
        }

    }
}
