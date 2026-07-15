import QtQuick
import Quickshell
import Quickshell.Wayland

WlSessionLockSurface {
    id: surface

    property bool authenticating: false
    property string authMessage: ""
    property string passwordText: ""
    property bool hidePassword: true
    property int revealDelay: 800
    property string pendingPowerAction: ""
    property url backgroundSource: ""
    property var wallpaperModel: null
    property bool settingsExpanded: false

    signal authenticate(string response)
    signal passwordEdited(string text)
    signal hidePasswordChangedByUser(bool hidden)
    signal revealDelayChangedByUser(int delay)
    signal wallpaperSelected(url source)
    signal powerActionRequested(string action)

    color: "#34383e"

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Rectangle {
        id: background

        anchors.fill: parent
        color: "#34383e"
        clip: true

        Image {
            anchors.fill: parent
            source: surface.backgroundSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        Rectangle {
            anchors.fill: parent
            color: "#5934383e"
        }

        Repeater {
            model: [0.34, 0.52, 0.72, 0.96, 1.26, 1.62]

            Rectangle {
                required property real modelData

                anchors.centerIn: parent
                width: Math.max(background.width, background.height) * modelData
                height: width
                radius: width / 2
                color: "transparent"
                border.width: Math.max(1, width * 0.0012)
                border.color: "#0dffffff"
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.max(parent.width, parent.height) * 1.25
            height: width
            radius: width / 2
            color: "transparent"
            border.width: Math.max(parent.width, parent.height) * 0.17
            border.color: "#16303439"
        }

        Column {
            id: clockColumn

            anchors.centerIn: parent
            anchors.verticalCenterOffset: -24
            spacing: -4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: "#f0eef2"
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: Math.max(74, Math.min(surface.width, surface.height) * 0.13)
                font.weight: Font.DemiBold
                style: Text.Raised
                styleColor: "#40000000"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
                color: "#a8c7f0"
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: Math.max(15, Math.min(surface.width, surface.height) * 0.021)
                font.weight: Font.DemiBold
                style: Text.Raised
                styleColor: "#40000000"
            }

            Item {
                width: 430
                height: 74
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: 430
                    height: 52
                    radius: 26
                    color: "#cc202226"
                    border.width: 1
                    border.color: passwordInput.activeFocus ? "#669bc7ff" : "#26ffffff"
                    opacity: passwordInput.text.length > 0 || surface.authenticating || surface.authMessage.length > 0 ? 1 : 0

                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    TextInput {
                        id: passwordInput

                        anchors.fill: parent
                        anchors.leftMargin: 24
                        anchors.rightMargin: 54
                        verticalAlignment: TextInput.AlignVCenter
                        color: "#f0eef2"
                        selectionColor: "#668ab4e8"
                        selectedTextColor: "#ffffff"
                        font.family: "JetBrains Mono Nerd Font"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        echoMode: surface.hidePassword ? TextInput.Password : TextInput.Normal
                        passwordMaskDelay: surface.revealDelay
                        maximumLength: 256
                        enabled: !surface.authenticating
                        focus: true

                        Component.onCompleted: forceActiveFocus()

                        onTextChanged: {
                            if (text !== surface.passwordText)
                                surface.passwordEdited(text)
                        }

                        onAccepted: {
                            if (text.length > 0) {
                                surface.authenticate(text)
                            }
                        }
                    }

                    Connections {
                        target: surface

                        function onPasswordTextChanged() {
                            if (passwordInput.text !== surface.passwordText)
                                passwordInput.text = surface.passwordText
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: surface.authenticating ? "..." : "↵"
                        color: "#8fa1b7"
                        font.family: "JetBrains Mono Nerd Font"
                        font.pixelSize: 17
                    }
                }

                Text {
                    anchors.top: parent.verticalCenter
                    anchors.topMargin: 34
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: surface.authMessage
                    color: "#ef9a9a"
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    opacity: text.length > 0 ? 1 : 0
                }
            }
        }

        Rectangle {
            id: settingsPanel

            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: Math.max(24, parent.width * 0.022)
            anchors.bottomMargin: Math.max(24, parent.height * 0.055)
            width: surface.settingsExpanded ? 276 : 48
            height: surface.settingsExpanded ? 540 : 48
            radius: surface.settingsExpanded ? 18 : 24
            color: "#e81b1d21"
            border.width: 1
            border.color: "#303b4149"
            clip: true

            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on radius { NumberAnimation { duration: 180 } }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 0
                opacity: surface.settingsExpanded ? 1 : 0
                enabled: surface.settingsExpanded

                Behavior on opacity { NumberAnimation { duration: 120 } }

                Text {
                    text: "SETTINGS"
                    color: "#aeb8c6"
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }

                Item {
                    width: parent.width
                    height: 46

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Hide password"
                        color: "#d7dce4"
                        font.family: "JetBrains Mono Nerd Font"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        id: passwordToggle

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 22
                        radius: 11
                        color: surface.hidePassword ? "#a8c7f0" : "#434850"

                        Rectangle {
                            x: surface.hidePassword ? parent.width - width - 3 : 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            radius: 8
                            color: "#15171a"

                            Behavior on x { NumberAnimation { duration: 140 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: surface.hidePasswordChangedByUser(!surface.hidePassword)
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 64

                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        text: "Reveal delay"
                        color: "#7f858e"
                        font.family: "JetBrains Mono Nerd Font"
                        font.pixelSize: 11
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        text: `${surface.revealDelay} ms`
                        color: "#7f858e"
                        font.family: "JetBrains Mono Nerd Font"
                        font.pixelSize: 11
                    }

                    Rectangle {
                        id: sliderTrack

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 15
                        height: 6
                        radius: 3
                        color: "#292c31"

                        Rectangle {
                            width: sliderHandle.x + sliderHandle.width / 2
                            height: parent.height
                            radius: parent.radius
                            color: "#63758d"
                        }

                        Rectangle {
                            id: sliderHandle

                            x: Math.max(0, Math.min(parent.width - width,
                                (surface.revealDelay - 200) / 1800 * (parent.width - width)))
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            radius: 8
                            color: sliderMouse.pressed ? "#a8c7f0" : "#777083"
                        }

                        MouseArea {
                            id: sliderMouse

                            anchors.fill: parent

                            function setDelay(mouseX) {
                                const ratio = Math.max(0, Math.min(1, mouseX / width))
                                surface.revealDelayChangedByUser(Math.round((200 + ratio * 1800) / 100) * 100)
                            }

                            onPressed: event => setDelay(event.x)
                            onPositionChanged: event => {
                                if (pressed)
                                    setDelay(event.x)
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 98

                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        text: "Wallpaper"
                        color: "#aeb8c6"
                        font.family: "JetBrains Mono Nerd Font"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    ListView {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 70
                        orientation: ListView.Horizontal
                        spacing: 8
                        clip: true
                        model: surface.wallpaperModel

                        delegate: Rectangle {
                            id: wallpaperTile

                            required property var modelData

                            width: 88
                            height: 62
                            radius: 8
                            color: "#292d33"
                            border.width: modelData.source === String(surface.backgroundSource) ? 2 : 1
                            border.color: modelData.source === String(surface.backgroundSource)
                                ? "#a8c7f0"
                                : "#303740"
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: 3
                                source: wallpaperTile.modelData.source
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 18
                                color: "#b314171b"

                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 5
                                    anchors.rightMargin: 5
                                    text: wallpaperTile.modelData.name
                                    color: "#e0e4ea"
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                    font.family: "JetBrains Mono Nerd Font"
                                    font.pixelSize: 9
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: surface.wallpaperSelected(wallpaperTile.modelData.source)
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#30343a"
                }

                Repeater {
                    model: [
                        { icon: "󰜉", label: "Restart", action: "restart", destructive: false },
                        { icon: "󰤄", label: "Suspend", action: "suspend", destructive: false },
                        { icon: "󰍃", label: "Log out", action: "logout", destructive: false },
                        { icon: "󰐥", label: "Power off", action: "poweroff", destructive: true }
                    ]

                    Rectangle {
                        required property var modelData

                        width: settingsPanel.width - 32
                        height: 58
                        radius: 10
                        color: actionMouse.containsMouse
                            ? (modelData.destructive ? "#302724" : "#282b30")
                            : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.icon
                            color: modelData.destructive ? "#d58d8a" : "#91a3be"
                            font.family: "JetBrains Mono Nerd Font"
                            font.pixelSize: 17
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: modelData.destructive ? "#d58d8a" : "#9da9be"
                            font.family: "JetBrains Mono Nerd Font"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: actionMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: surface.pendingPowerAction = modelData.action
                        }
                    }
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 48
                height: 48
                color: settingsMouse.containsMouse ? "#282c31" : "transparent"
                radius: 24

                Text {
                    anchors.centerIn: parent
                    text: "󰒓"
                    color: "#c6d0df"
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 18
                }

                MouseArea {
                    id: settingsMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: surface.settingsExpanded = !surface.settingsExpanded
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "#99000000"
            visible: surface.pendingPowerAction.length > 0

            MouseArea { anchors.fill: parent }

            Rectangle {
                anchors.centerIn: parent
                width: 360
                height: 178
                radius: 18
                color: "#f21b1d21"
                border.width: 1
                border.color: "#40464f"

                Column {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 18

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: surface.pendingPowerAction === "poweroff"
                            ? "Power off this computer?"
                            : (surface.pendingPowerAction === "restart"
                                ? "Restart this computer?"
                                : (surface.pendingPowerAction === "logout"
                                    ? "Log out of this session?"
                                    : "Suspend this computer?"))
                        color: "#e2e5ea"
                        font.family: "JetBrains Mono Nerd Font"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: surface.pendingPowerAction === "logout"
                            ? "All applications in this session will close."
                            : "Your session will remain locked."
                        color: "#858d98"
                        font.family: "JetBrains Mono Nerd Font"
                        font.pixelSize: 11
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12

                        Repeater {
                            model: ["Cancel", "Confirm"]

                            Rectangle {
                                required property string modelData

                                width: 132
                                height: 40
                                radius: 10
                                color: confirmMouse.containsMouse
                                    ? (modelData === "Confirm" ? "#9e5555" : "#343941")
                                    : (modelData === "Confirm" ? "#773f3f" : "#292d33")

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: "#e2e5ea"
                                    font.family: "JetBrains Mono Nerd Font"
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    id: confirmMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (modelData === "Confirm")
                                            surface.powerActionRequested(surface.pendingPowerAction)
                                        surface.pendingPowerAction = ""
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
