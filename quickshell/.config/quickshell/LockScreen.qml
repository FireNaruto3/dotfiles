import QtQuick
import Quickshell
import Quickshell.Wayland

WlSessionLockSurface {
    id: surface

    property bool authenticating: false
    property string authMessage: ""
    property string passwordText: ""
    property bool hidePassword: true
    property bool capsLock: false
    property string pendingPowerAction: ""
    property string powerPasswordText: ""
    property string powerMessage: ""
    property bool powerAuthenticating: false
    property bool powerBusy: false
    property url backgroundSource: ""
    property var wallpaperModel: null
    property bool settingsExpanded: false
    property bool batteryAvailable: false
    property int batteryPercentage: 0
    property string batteryState: "unknown"
    required property var theme

    signal authenticate(string response)
    signal passwordEdited(string text)
    signal hidePasswordChangedByUser(bool hidden)
    signal wallpaperSelected(url source)
    signal powerStateReset()
    signal powerActionRequested(string action, string response)

    color: withAlpha(theme.background, 1)

    onAuthMessageChanged: {
        if (authMessage === "Incorrect password")
            failureAnimation.restart()
    }

    onPowerBusyChanged: {
        if (!powerBusy && powerMessage.length === 0) {
            pendingPowerAction = ""
            powerPasswordText = ""
        }
    }

    onPowerAuthenticatingChanged: {
        if (!powerAuthenticating) {
            powerPasswordText = ""
            powerPasswordInput.clear()
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    function batteryIcon() {
        if (batteryState === "charging" || batteryState === "pending-charge")
            return "󰂄"
        if (batteryState === "fully-charged")
            return "󰁹"
        const icons = ["󰂎", "󰁺", "󰁼", "󰁿", "󰂁", "󰁹"]
        return icons[Math.max(0, Math.min(5, Math.floor(batteryPercentage / 20)))]
    }

    function batteryColor() {
        if (batteryState === "charging" || batteryState === "pending-charge"
                || batteryState === "fully-charged")
            return theme.success
        if (batteryPercentage <= 15)
            return theme.error
        if (batteryPercentage <= 30)
            return theme.warning
        return theme.accent
    }

    function withAlpha(value, alpha) {
        return Qt.rgba(value.r, value.g, value.b, alpha)
    }

    SequentialAnimation {
        id: failureAnimation

        NumberAnimation { target: authShake; property: "x"; from: 0; to: -10; duration: 45 }
        NumberAnimation { target: authShake; property: "x"; from: -10; to: 10; duration: 70 }
        NumberAnimation { target: authShake; property: "x"; from: 10; to: -6; duration: 60 }
        NumberAnimation { target: authShake; property: "x"; from: -6; to: 6; duration: 55 }
        NumberAnimation { target: authShake; property: "x"; from: 6; to: 0; duration: 45 }
    }

    Rectangle {
        id: background

        anchors.fill: parent
        color: surface.withAlpha(theme.background, 1)
        clip: true

        Image {
            anchors.fill: parent
            source: surface.backgroundSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: {
                const edge = Math.ceil(Math.max(surface.width, surface.height)
                    * Math.max(1, surface.screen ? surface.screen.devicePixelRatio : 1))
                return Qt.size(edge, edge)
            }
        }

        Rectangle {
            anchors.fill: parent
            color: surface.withAlpha(theme.background, 0.38)
        }

        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Math.max(24, parent.height * 0.035)
            anchors.rightMargin: Math.max(24, parent.width * 0.022)
            width: 92
            height: 38
            radius: 19
            color: surface.withAlpha(theme.card, 0.82)
            border.width: 1
            border.color: surface.withAlpha(theme.border, 0.65)
            visible: surface.batteryAvailable

            Text {
                anchors.centerIn: parent
                text: `${surface.batteryIcon()} ${surface.batteryPercentage}%`
                color: surface.batteryColor()
                font.family: theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
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
                border.color: surface.withAlpha(theme.text, 0.05)
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.max(parent.width, parent.height) * 1.25
            height: width
            radius: width / 2
            color: "transparent"
            border.width: Math.max(parent.width, parent.height) * 0.17
            border.color: surface.withAlpha(theme.background, 0.18)
        }

        Column {
            id: clockColumn

            anchors.centerIn: parent
            anchors.verticalCenterOffset: -24
            spacing: -4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "hh:mm AP")
                color: theme.text
                font.family: theme.fontFamily
                font.pixelSize: Math.max(52, Math.min(220,
                    Math.min(surface.width, surface.height) * 0.13))
                font.weight: Font.DemiBold
                style: Text.Raised
                styleColor: surface.withAlpha(theme.background, 0.65)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
                color: theme.accent
                font.family: theme.fontFamily
                font.pixelSize: Math.max(14, Math.min(30,
                    Math.min(surface.width, surface.height) * 0.021))
                font.weight: Font.DemiBold
                style: Text.Raised
                styleColor: surface.withAlpha(theme.background, 0.65)
            }

            Item {
                width: Math.max(220, Math.min(430, surface.width - 48))
                height: 98
                anchors.horizontalCenter: parent.horizontalCenter
                transform: Translate { id: authShake }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 52
                    radius: 26
                    color: surface.withAlpha(theme.card, 0.84)
                    border.width: 1
                    border.color: surface.authMessage.length > 0
                        ? surface.withAlpha(theme.error, 0.85)
                        : (passwordInput.activeFocus
                            ? surface.withAlpha(theme.accent, 0.85)
                            : surface.withAlpha(theme.border, 0.65))
                    opacity: passwordInput.text.length > 0 || surface.authenticating || surface.authMessage.length > 0 ? 1 : 0

                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    TextInput {
                        id: passwordInput

                        anchors.fill: parent
                        anchors.leftMargin: 24
                        anchors.rightMargin: 54
                        verticalAlignment: TextInput.AlignVCenter
                        color: theme.text
                        selectionColor: surface.withAlpha(theme.accent, 0.45)
                        selectedTextColor: theme.text
                        font.family: theme.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        echoMode: surface.hidePassword ? TextInput.Password : TextInput.Normal
                        passwordMaskDelay: 0
                        maximumLength: 256
                        clip: true
                        autoScroll: true
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

                    Item {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 52
                        height: parent.height

                        Text {
                            id: submitIcon

                            anchors.centerIn: parent
                            text: surface.authenticating ? "󰔟" : "↵"
                            color: theme.textMuted
                            font.family: theme.fontFamily
                            font.pixelSize: 17
                        }

                        RotationAnimator {
                            target: submitIcon
                            from: 0
                            to: 360
                            duration: 850
                            loops: Animation.Infinite
                            running: surface.authenticating
                        }
                    }
                }

                Text {
                    anchors.top: parent.verticalCenter
                    anchors.topMargin: 34
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: surface.authMessage.length > 0
                        ? surface.authMessage
                        : (surface.capsLock ? "󰪛 CAPS LOCK IS ON" : "")
                    color: surface.authMessage.length > 0 ? theme.error : theme.warning
                    font.family: theme.fontFamily
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
            width: surface.settingsExpanded
                ? Math.max(220, Math.min(276, surface.width - 48))
                : 48
            height: surface.settingsExpanded
                ? Math.max(300, Math.min(476, surface.height - 48))
                : 48
            radius: surface.settingsExpanded ? 18 : 24
            color: surface.withAlpha(theme.card, 0.93)
            border.width: 1
            border.color: surface.withAlpha(theme.border, 0.72)
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
                    color: theme.textMuted
                    font.family: theme.fontFamily
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
                        color: theme.text
                        font.family: theme.fontFamily
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
                        color: surface.hidePassword ? theme.accent : theme.cardActive

                        Rectangle {
                            x: surface.hidePassword ? parent.width - width - 3 : 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            radius: 8
                            color: theme.background

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
                    height: 98

                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        text: "Wallpaper"
                        color: theme.textMuted
                        font.family: theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    Loader {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 70
                        active: surface.settingsExpanded

                        sourceComponent: ListView {
                            orientation: ListView.Horizontal
                            spacing: 8
                            clip: true
                            model: surface.wallpaperModel || []

                            delegate: Rectangle {
                                id: wallpaperTile

                                required property var modelData

                                width: 88
                                height: 62
                                radius: 8
                                color: theme.cardHover
                                border.width: modelData.source === String(surface.backgroundSource) ? 2 : 1
                                border.color: modelData.source === String(surface.backgroundSource)
                                    ? theme.accent
                                    : theme.border
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    source: wallpaperTile.modelData.source
                                    sourceSize: Qt.size(192, 192)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 18
                                    color: surface.withAlpha(theme.background, 0.78)

                                    Text {
                                        anchors.fill: parent
                                        anchors.leftMargin: 5
                                        anchors.rightMargin: 5
                                        text: wallpaperTile.modelData.name
                                        color: theme.text
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                        font.family: theme.fontFamily
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
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: theme.border
                }

                Repeater {
                    model: [
                        { icon: "󰜉", label: "Restart", action: "restart", destructive: false },
                        { icon: "󰤄", label: "Sleep", action: "suspend", destructive: false },
                        { icon: "󰍃", label: "Log out", action: "logout", destructive: false },
                        { icon: "󰐥", label: "Power off", action: "poweroff", destructive: true }
                    ]

                    Rectangle {
                        required property var modelData

                        width: settingsPanel.width - 32
                        height: 58
                        radius: 10
                        color: actionMouse.containsMouse
                            ? (modelData.destructive
                                ? surface.withAlpha(theme.error, 0.16)
                                : theme.cardHover)
                            : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.icon
                            color: modelData.destructive ? theme.error : theme.accent
                            font.family: theme.fontFamily
                            font.pixelSize: 17
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: modelData.destructive ? theme.error : theme.textMuted
                            font.family: theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: actionMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                surface.powerStateReset()
                                surface.powerPasswordText = ""
                                powerPasswordInput.clear()
                                surface.pendingPowerAction = modelData.action
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 48
                height: 48
                color: settingsMouse.containsMouse ? theme.cardHover : "transparent"
                radius: 24

                Text {
                    anchors.centerIn: parent
                    text: "󰒓"
                    color: theme.text
                    font.family: theme.fontFamily
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
            color: surface.withAlpha(theme.background, 0.72)
            visible: surface.pendingPowerAction.length > 0

            MouseArea { anchors.fill: parent }

            Rectangle {
                id: confirmationDialog

                anchors.centerIn: parent
                width: Math.max(280, Math.min(360, surface.width - 48))
                height: surface.pendingPowerAction === "suspend" ? 178 : 260
                radius: 18
                color: surface.withAlpha(theme.card, 0.96)
                border.width: 1
                border.color: theme.border

                Column {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 18

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        text: surface.pendingPowerAction === "poweroff"
                            ? "Power off this computer?"
                            : (surface.pendingPowerAction === "restart"
                                ? "Restart this computer?"
                                : (surface.pendingPowerAction === "logout"
                                    ? "Log out of this session?"
                                    : "Suspend this computer?"))
                        color: theme.text
                        horizontalAlignment: Text.AlignHCenter
                        font.family: theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        text: surface.pendingPowerAction === "poweroff"
                            ? "The computer will shut down."
                            : (surface.pendingPowerAction === "restart"
                                ? "The computer will restart."
                                : (surface.pendingPowerAction === "logout"
                                    ? "All applications in this session will close."
                                    : "Your session will remain locked."))
                        color: theme.textMuted
                        horizontalAlignment: Text.AlignHCenter
                        font.family: theme.fontFamily
                        font.pixelSize: 11
                    }

                    Rectangle {
                        width: parent.width
                        height: surface.pendingPowerAction === "suspend" ? 0 : 42
                        radius: 10
                        color: surface.withAlpha(theme.background, 0.62)
                        border.width: 1
                        border.color: powerPasswordInput.activeFocus ? theme.accent : theme.border
                        visible: height > 0

                        TextInput {
                            id: powerPasswordInput

                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            verticalAlignment: TextInput.AlignVCenter
                            color: theme.text
                            selectionColor: surface.withAlpha(theme.accent, 0.45)
                            selectedTextColor: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 13
                            echoMode: TextInput.Password
                            passwordMaskDelay: 0
                            maximumLength: 256
                            clip: true
                            autoScroll: true
                            enabled: !surface.powerBusy

                            onTextChanged: surface.powerPasswordText = text
                            onAccepted: {
                                if (text.length > 0)
                                    surface.powerActionRequested(surface.pendingPowerAction, text)
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        height: surface.pendingPowerAction === "suspend" ? 0 : 16
                        visible: height > 0
                        text: surface.powerMessage.length > 0
                            ? surface.powerMessage
                            : (surface.powerAuthenticating ? "Authenticating..." : "Password required")
                        color: surface.powerMessage.length > 0 ? theme.error : theme.textMuted
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        font.family: theme.fontFamily
                        font.pixelSize: 10
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        spacing: 12

                        Repeater {
                            model: ["Cancel", "Confirm"]

                            Rectangle {
                                required property string modelData

                                width: (parent.width - parent.spacing) / 2
                                height: 40
                                radius: 10
                                color: confirmMouse.containsMouse
                                    ? (modelData === "Confirm"
                                        ? surface.withAlpha(theme.error, 0.78)
                                        : theme.cardActive)
                                    : (modelData === "Confirm"
                                        ? surface.withAlpha(theme.error, 0.55)
                                        : theme.cardHover)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData === "Confirm" && surface.powerBusy
                                        ? "Working..."
                                        : modelData
                                    color: theme.text
                                    font.family: theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    id: confirmMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !surface.powerBusy
                                    onClicked: {
                                        if (modelData === "Confirm") {
                                            surface.powerActionRequested(
                                                surface.pendingPowerAction,
                                                surface.powerPasswordText)
                                        } else {
                                            surface.pendingPowerAction = ""
                                            surface.powerPasswordText = ""
                                            powerPasswordInput.clear()
                                            surface.powerStateReset()
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
}
