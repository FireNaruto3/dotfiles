import QtQuick

Item {
    id: root

    required property var quickData
    required property var systemData
    property string requestedPage: "bluetooth"
    property string currentPage: requestedPage
    property var pendingWifi: null
    readonly property int enabledDisplayCount: quickData.displays.filter(display => display.enabled).length

    implicitWidth: 460
    implicitHeight: 590

    ShellTheme { id: theme }

    onRequestedPageChanged: currentPage = requestedPage
    onVisibleChanged: {
        if (visible) {
            currentPage = requestedPage
            quickData.refresh()
        }
    }

    component SectionLabel: Text {
        color: theme.textMuted
        font.family: theme.fontFamily
        font.pixelSize: 10
        font.bold: true
    }

    component CategoryButton: Rectangle {
        id: category
        required property string label
        required property string icon
        property bool selected: false
        signal clicked()

        width: 78
        height: 54
        radius: 10
        color: selected ? theme.cardActive : (mouse.containsMouse ? theme.cardHover : theme.card)
        border.width: selected ? 1 : 0
        border.color: theme.border

        Column {
            anchors.centerIn: parent
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: category.icon
                color: category.selected ? theme.accent : theme.text
                font.family: theme.fontFamily
                font.pixelSize: 18
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: category.label
                color: category.selected ? theme.accent : theme.textMuted
                font.family: theme.fontFamily
                font.pixelSize: 9
                font.bold: category.selected
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: category.clicked()
        }
    }

    component ActionRow: Rectangle {
        id: row
        required property string label
        property string detail: ""
        property string icon: ""
        property bool active: false
        property bool showSwitch: false
        signal clicked()

        width: parent ? parent.width : 400
        height: 52
        radius: 9
        color: mouse.containsMouse && enabled ? theme.cardHover : theme.card
        opacity: enabled ? 1 : 0.45

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: row.icon
            color: row.active ? theme.accent : theme.textMuted
            font.family: theme.fontFamily
            font.pixelSize: 18
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: row.icon.length > 0 ? 44 : 12
            anchors.right: switchTrack.visible ? switchTrack.left : parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: row.label
                color: theme.text
                elide: Text.ElideRight
                font.family: theme.fontFamily
                font.pixelSize: 12
                font.bold: row.active
            }
            Text {
                width: parent.width
                visible: text.length > 0
                text: row.detail
                color: row.active ? theme.accent : theme.textMuted
                elide: Text.ElideRight
                font.family: theme.fontFamily
                font.pixelSize: 9
            }
        }

        Rectangle {
            id: switchTrack
            visible: row.showSwitch
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 18
            radius: 9
            color: row.active ? theme.cardActive : theme.cardHover
            border.width: 1
            border.color: row.active ? theme.accent : theme.border

            Rectangle {
                x: row.active ? parent.width - width - 3 : 3
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                height: 12
                radius: 6
                color: row.active ? theme.accent : theme.textMuted
                Behavior on x { NumberAnimation { duration: 130 } }
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: row.enabled
            onClicked: row.clicked()
        }
    }

    component ChoiceButton: Rectangle {
        id: choice
        required property string label
        property bool selected: false
        signal clicked()

        implicitWidth: Math.max(76, choiceText.implicitWidth + 24)
        height: 32
        radius: 8
        color: selected ? theme.cardActive : (mouse.containsMouse && enabled ? theme.cardHover : theme.card)
        border.width: selected ? 1 : 0
        border.color: theme.border
        opacity: enabled ? 1 : 0.4

        Text {
            id: choiceText
            anchors.centerIn: parent
            text: choice.label
            color: choice.selected ? theme.accent : theme.text
            font.family: theme.fontFamily
            font.pixelSize: 10
            font.bold: choice.selected
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: choice.enabled
            onClicked: choice.clicked()
        }
    }

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
                height: 32

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Quick Settings"
                    color: theme.text
                    font.family: theme.fontFamily
                    font.pixelSize: 17
                    font.bold: true
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.quickData.busy ? "Applying..." : ""
                    color: theme.accent
                    font.family: theme.fontFamily
                    font.pixelSize: 10
                }
            }

            Row {
                width: parent.width
                height: 54
                spacing: 8

                CategoryButton {
                    label: "Bluetooth"
                    icon: "󰂯"
                    selected: root.currentPage === "bluetooth"
                    onClicked: root.currentPage = "bluetooth"
                }
                CategoryButton {
                    label: "Network"
                    icon: "󰤨"
                    selected: root.currentPage === "network"
                    onClicked: root.currentPage = "network"
                }
                CategoryButton {
                    label: "Audio"
                    icon: "󰕾"
                    selected: root.currentPage === "audio"
                    onClicked: root.currentPage = "audio"
                }
                CategoryButton {
                    label: "Displays"
                    icon: "󰍹"
                    selected: root.currentPage === "displays"
                    onClicked: root.currentPage = "displays"
                }
            }

            Rectangle { width: parent.width; height: 1; color: theme.border }

            Loader {
                width: parent.width
                height: parent.height - 32 - 54 - 1 - 3 * parent.spacing
                    - (errorText.visible ? errorText.implicitHeight + parent.spacing : 0)
                sourceComponent: root.currentPage === "network" ? networkPage
                    : (root.currentPage === "bluetooth" ? bluetoothPage
                    : (root.currentPage === "audio" ? audioPage
                    : displaysPage))
            }

            Text {
                id: errorText
                width: parent.width
                visible: root.quickData.errorMessage.length > 0
                text: root.quickData.errorMessage
                color: theme.error
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.family: theme.fontFamily
                font.pixelSize: 9
            }
        }
    }

    Component {
        id: networkPage

        Flickable {
            clip: true
            contentHeight: networkColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: networkColumn
                width: parent.width
                spacing: 7

                ActionRow {
                    label: "Wi-Fi"
                    detail: root.quickData.wifiEnabled ? "Available networks" : "Wireless radio off"
                    icon: "󰤨"
                    active: root.quickData.wifiEnabled
                    showSwitch: true
                    enabled: !root.quickData.busy
                    onClicked: root.quickData.run("wifi-power", [active ? "off" : "on"])
                }
                SectionLabel { text: "NETWORKS" }
                Rectangle {
                    width: parent.width
                    height: 86
                    visible: root.pendingWifi !== null
                    radius: 9
                    color: theme.card
                    border.width: 1
                    border.color: theme.border

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 7

                        Text {
                            text: root.pendingWifi ? `Password for ${root.pendingWifi.name}` : ""
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                        }
                        Row {
                            width: parent.width
                            spacing: 8

                            Rectangle {
                                width: parent.width - connectButton.width - parent.spacing
                                height: 34
                                radius: 7
                                color: theme.cardHover
                                border.width: passwordInput.activeFocus ? 1 : 0
                                border.color: theme.accent

                                TextInput {
                                    id: passwordInput
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    color: theme.text
                                    font.family: theme.fontFamily
                                    font.pixelSize: 11
                                    echoMode: TextInput.Password
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    onAccepted: connectButton.clicked()
                                }
                            }
                            ChoiceButton {
                                id: connectButton
                                label: "Connect"
                                enabled: passwordInput.text.length > 0 && !root.quickData.busy
                                onClicked: {
                                    root.quickData.run("wifi-connect-password", [root.pendingWifi.name, passwordInput.text])
                                    passwordInput.text = ""
                                    root.pendingWifi = null
                                }
                            }
                        }
                    }
                }
                Repeater {
                    model: root.quickData.wifiNetworks
                    ActionRow {
                        required property var modelData
                        label: modelData.name
                        detail: `${modelData.signal}% · ${modelData.security || "Open"}`
                        icon: modelData.active ? "󰤨" : "󰤢"
                        active: modelData.active
                        enabled: !root.quickData.busy
                        onClicked: {
                            if (modelData.active) {
                                root.quickData.run("wifi-disconnect", [modelData.uuid])
                            } else if (modelData.uuid || !modelData.secured) {
                                root.quickData.run("wifi-connect", [modelData.name, modelData.uuid || ""])
                            } else {
                                root.pendingWifi = modelData
                                passwordInput.forceActiveFocus()
                            }
                        }
                    }
                }
                SectionLabel { text: "VPNS" }
                Repeater {
                    model: root.quickData.vpns
                    ActionRow {
                        required property var modelData
                        label: modelData.name
                        detail: modelData.type === "wireguard" ? "WireGuard" : "VPN"
                        icon: "󰌾"
                        active: modelData.active
                        showSwitch: true
                        enabled: !root.quickData.busy
                        onClicked: root.quickData.run(modelData.active ? "vpn-down" : "vpn-up", [modelData.uuid])
                    }
                }
            }
        }
    }

    Component {
        id: bluetoothPage

        Flickable {
            clip: true
            contentHeight: bluetoothColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: bluetoothColumn
                width: parent.width
                spacing: 7

                ActionRow {
                    label: "Bluetooth"
                    detail: root.quickData.bluetoothPowered ? "Paired devices" : "Radio off"
                    icon: "󰂯"
                    active: root.quickData.bluetoothPowered
                    showSwitch: true
                    enabled: !root.quickData.busy
                    onClicked: root.quickData.run("bluetooth-power", [active ? "off" : "on"])
                }
                SectionLabel { text: "DEVICES" }
                Repeater {
                    model: root.quickData.bluetoothDevices
                    ActionRow {
                        required property var modelData
                        label: modelData.name
                        detail: modelData.connected ? "Connected" : "Paired"
                        icon: modelData.connected ? "󰂱" : "󰂯"
                        active: modelData.connected
                        showSwitch: true
                        enabled: root.quickData.bluetoothPowered && !root.quickData.busy
                        onClicked: root.quickData.run(
                            modelData.connected ? "bluetooth-disconnect" : "bluetooth-connect",
                            [modelData.address]
                        )
                    }
                }
            }
        }
    }

    Component {
        id: audioPage

        Flickable {
            clip: true
            contentHeight: audioColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: audioColumn
                width: parent.width
                spacing: 7

                ActionRow {
                    label: "Output audio"
                    detail: root.systemData.muted ? "Muted" : `${root.systemData.volume}% volume`
                    icon: root.systemData.muted ? "󰝟" : "󰕾"
                    active: !root.systemData.muted
                    showSwitch: true
                    enabled: !root.quickData.busy
                    onClicked: root.quickData.run("audio-mute", [])
                }
                SectionLabel { text: "OUTPUT DEVICES" }
                Repeater {
                    model: root.quickData.sinks
                    ActionRow {
                        required property var modelData
                        label: modelData.name
                        detail: modelData.active ? "Default output" : "Select output"
                        icon: "󰓃"
                        active: modelData.active
                        enabled: !root.quickData.busy
                        onClicked: root.quickData.run("audio-default", [modelData.id])
                    }
                }
                ActionRow {
                    label: "Microphone"
                    detail: root.systemData.microphoneMuted ? "Muted" : "Live"
                    icon: root.systemData.microphoneMuted ? "󰍭" : "󰍬"
                    active: !root.systemData.microphoneMuted
                    showSwitch: true
                    enabled: !root.quickData.busy
                    onClicked: root.quickData.run("microphone-mute", [])
                }
                SectionLabel { text: "INPUT DEVICES" }
                Repeater {
                    model: root.quickData.sources
                    ActionRow {
                        required property var modelData
                        label: modelData.name
                        detail: modelData.active ? "Default microphone" : "Select microphone"
                        icon: "󰍬"
                        active: modelData.active
                        enabled: !root.quickData.busy
                        onClicked: root.quickData.run("audio-default", [modelData.id])
                    }
                }
            }
        }
    }

    Component {
        id: displaysPage

        Flickable {
            clip: true
            contentHeight: displaysColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: displaysColumn
                width: parent.width
                spacing: 8

                Repeater {
                    model: root.quickData.displays
                    Column {
                        id: display
                        required property var modelData
                        width: parent.width
                        spacing: 6

                        ActionRow {
                            label: display.modelData.label || display.modelData.name
                            detail: display.modelData.name
                            icon: "󰍹"
                            active: display.modelData.enabled
                            showSwitch: true
                            enabled: !root.quickData.busy
                                && (!display.modelData.enabled || root.enabledDisplayCount > 1)
                            onClicked: root.quickData.run("display-power", [
                                display.modelData.name, display.modelData.enabled ? "off" : "on"
                            ])
                        }
                        Row {
                            visible: display.modelData.enabled
                            spacing: 7
                            Repeater {
                                model: display.modelData.modes
                                ChoiceButton {
                                    required property var modelData
                                    label: modelData.label
                                    selected: modelData.active
                                    enabled: !root.quickData.busy
                                    onClicked: root.quickData.run("display-mode", [
                                        display.modelData.name, modelData.value
                                    ])
                                }
                            }
                        }
                        Rectangle { width: parent.width; height: 1; color: theme.border }
                    }
                }
            }
        }
    }

}
