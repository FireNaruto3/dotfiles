import QtQuick
import Quickshell

PanelWindow {
    id: window

    required property var systemData
    required property var powerData
    property string requestedGpuMode: ""
    property string requestedSystemAction: ""
    property int chargeLimitPreview: -1
    property int keyboardPreview: -1
    readonly property int displayedChargeLimit: chargeLimitPreview >= 0
        ? chargeLimitPreview
        : powerData.chargeLimit
    readonly property int displayedKeyboardBrightness: keyboardPreview >= 0
        ? keyboardPreview
        : powerData.keyboardBrightness

    readonly property var powerProfiles: [
        { label: "Power Saver", value: "power-saver", asusValue: "Quiet" },
        { label: "Balanced", value: "balanced", asusValue: "Balanced" },
        { label: "Performance", value: "performance", asusValue: "Performance" }
    ]
    readonly property var gpuModes: [
        { label: "Integrated", value: "Integrated" },
        { label: "Hybrid", value: "Hybrid" },
        { label: "dGPU", value: "AsusMuxDgpu" }
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
    implicitHeight: 606
        + (pendingActionVisible() ? 64 : 0)
        + (gpuIssueVisible() ? 44 : 0)
        + (powerData.errorMessage.length > 0 ? 56 : 0)
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false
    color: "transparent"

    onVisibleChanged: {
        if (visible)
            powerData.refresh()
        else
            requestedGpuMode = ""
        requestedSystemAction = ""
        chargeLimitPreview = -1
        keyboardPreview = -1
    }

    function gpuModeLabel(mode) {
        for (const entry of gpuModes) {
            if (entry.value === mode)
                return entry.label
        }
        return mode
    }

    function gpuModeDescription(mode) {
        if (mode === "Integrated")
            return "Uses only the AMD iGPU for the best battery life. NVIDIA and dGPU-connected outputs will be unavailable."
        if (mode === "Hybrid")
            return "Uses AMD for the desktop while keeping NVIDIA available for application offloading and runtime suspension."
        return "Routes the display through NVIDIA for maximum performance at the cost of battery life."
    }

    function gpuRequiredAction(mode) {
        return mode === "AsusMuxDgpu" || powerData.gpuMode === "AsusMuxDgpu"
            ? "reboot"
            : "logout"
    }

    function gpuStatusText() {
        const labels = {
            "active": "dGPU active",
            "suspended": "dGPU suspended",
            "off": "dGPU off",
            "dgpu_disabled": "dGPU disabled",
            "asus_mux_discreet": "MUX discrete",
            "transitioning": "GPU transition pending"
        }
        return labels[powerData.gpuStatus] || powerData.gpuStatus
    }

    function gpuStatusColor() {
        if (powerData.gpuStatus === "active" || powerData.gpuStatus === "asus_mux_discreet"
            || powerData.gpuStatus === "transitioning")
            return "#e5c890"
        if (powerData.gpuStatus === "suspended" || powerData.gpuStatus === "off"
            || powerData.gpuStatus === "dgpu_disabled")
            return "#a9f3d1"
        return "#758083"
    }

    function gpuIssueVisible() {
        return !powerData.gpuTransitionPending && powerData.gpuSwitchError.length > 0
    }

    function pendingActionVisible() {
        return powerData.gpuTransitionPending
            || (powerData.gpuSwitchError.length === 0
            && powerData.pendingAction !== "No action required"
            && powerData.pendingAction !== "Unknown"
            )
    }

    function pendingActionKind() {
        if (powerData.gpuTransitionPending)
            return powerData.gpuActionRequired
        if (powerData.gpuSwitchError.length > 0)
            return ""
        const action = powerData.pendingAction.toLowerCase()
        if (action.indexOf("reboot") !== -1)
            return "reboot"
        if (action.indexOf("logout") !== -1 || action.indexOf("log out") !== -1)
            return "logout"
        return ""
    }

    function systemActionReady(action) {
        if (powerData.gpuTransitionPending)
            return powerData.gpuActionReady && action === powerData.gpuActionRequired
        return powerData.gpuSwitchError.length === 0
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

            Text {
                text: "DEFAULT POWER PROFILE WHEN ON AC POWER"
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
                        selected: window.powerData.acProfile === modelData.asusValue
                        enabled: !window.powerData.busy
                        onClicked: window.powerData.setDefaultProfile(modelData.asusValue, true)
                    }
                }
            }

            Text {
                text: "DEFAULT POWER PROFILE WHEN ON BATTERY"
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
                        selected: window.powerData.batteryProfile === modelData.asusValue
                        enabled: !window.powerData.busy
                        onClicked: window.powerData.setDefaultProfile(modelData.asusValue, false)
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#2ec8e6e6" }

            Row {
                width: parent.width

                Text {
                    width: parent.width / 2
                    text: "GPU MODE"
                    color: "#758083"
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 10
                    font.bold: true
                }

                Text {
                    width: parent.width / 2
                    horizontalAlignment: Text.AlignRight
                    text: window.gpuStatusText()
                    color: window.gpuStatusColor()
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 10
                }
            }

            Row {
                width: parent.width
                spacing: 7

                Repeater {
                    model: window.gpuModes

                    PowerChoice {
                        required property var modelData

                        width: (window.width - 42) / 3
                        label: modelData.label
                        selected: window.powerData.gpuMode === modelData.value
                        enabled: !window.powerData.busy
                            && window.powerData.gpuSwitchReady
                            && window.powerData.gpuMode !== modelData.value
                        onClicked: window.requestedGpuMode = modelData.value
                    }
                }
            }

            Text {
                width: parent.width
                visible: window.gpuIssueVisible()
                text: window.powerData.gpuSwitchError
                color: "#e78284"
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 10
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

            Rectangle {
                width: parent.width
                height: window.pendingActionVisible() ? 54 : 0
                radius: 6
                color: "#292d33"
                visible: height > 0

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - actionButton.width - (actionButton.visible ? 28 : 20)
                    text: window.powerData.gpuTransitionPending
                        ? (window.powerData.gpuActionReady
                            ? `${window.gpuModeLabel(window.powerData.gpuRequestedMode)} selected · ${window.powerData.gpuActionRequired} required`
                            : `Preparing ${window.gpuModeLabel(window.powerData.gpuRequestedMode)} transition`)
                        : (window.powerData.pendingMode === "Unknown"
                            ? window.powerData.pendingAction
                            : `${window.powerData.pendingMode}: ${window.powerData.pendingAction}`)
                    color: "#e5c890"
                    elide: Text.ElideRight
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 10
                }

                Rectangle {
                    id: actionButton

                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 76
                    height: 32
                    radius: 6
                    visible: window.pendingActionKind().length > 0
                    opacity: window.powerData.busy || (window.powerData.gpuTransitionPending
                        && !window.powerData.gpuActionReady) ? 0.45 : 1
                    color: actionMouse.containsMouse ? "#80669970" : "#3b4148"

                    Text {
                        anchors.centerIn: parent
                        text: window.pendingActionKind() === "reboot" ? "Reboot" : "Log out"
                        color: "#d8e0e3"
                        font.family: "JetBrains Mono Nerd Font"
                        font.pixelSize: 10
                        font.bold: true
                    }

                    MouseArea {
                        id: actionMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !window.powerData.busy
                            && window.systemActionReady(window.pendingActionKind())
                        onClicked: window.requestedSystemAction = window.pendingActionKind()
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

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: "#d9131819"
            visible: window.requestedGpuMode.length > 0 || window.requestedSystemAction.length > 0

            MouseArea { anchors.fill: parent }

            Rectangle {
                anchors.centerIn: parent
                width: 300
                height: window.requestedGpuMode.length > 0 ? 190 : 174
                radius: 10
                color: "#f21b1d21"
                border.width: 1
                border.color: "#40464f"

                Column {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: window.requestedGpuMode.length > 0
                            ? `Switch GPU mode to ${window.gpuModeLabel(window.requestedGpuMode)}?`
                            : (window.requestedSystemAction === "reboot" ? "Reboot now?" : "Log out now?")
                        color: "#e2e5ea"
                        font.family: "JetBrains Mono Nerd Font"
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Text {
                        width: parent.width
                        text: window.requestedGpuMode.length > 0
                            ? `${window.gpuModeDescription(window.requestedGpuMode)} An explicit ${window.gpuRequiredAction(window.requestedGpuMode)} is required; it will not happen automatically.`
                            : "Save your work before continuing."
                        color: "#858d98"
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        font.family: "JetBrains Mono Nerd Font"
                        font.pixelSize: 10
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10

                        Repeater {
                            model: ["Cancel", "Apply"]

                            Rectangle {
                                required property string modelData

                                width: 116
                                height: 36
                                radius: 7
                                color: confirmMouse.containsMouse
                                    ? (modelData === "Apply" ? "#526f63" : "#343941")
                                    : (modelData === "Apply" ? "#40594f" : "#292d33")

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: "#e2e5ea"
                                    font.family: "JetBrains Mono Nerd Font"
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                MouseArea {
                                    id: confirmMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (modelData === "Apply") {
                                            if (window.requestedGpuMode.length > 0) {
                                                window.powerData.setGpuMode(window.requestedGpuMode)
                                            } else if (window.requestedSystemAction.length > 0) {
                                                if (window.systemActionReady(window.requestedSystemAction))
                                                    window.powerData.runGpuTransitionAction(window.requestedSystemAction)
                                                else
                                                    window.powerData.setError("GPU transition is no longer ready")
                                            }
                                        }
                                        window.requestedGpuMode = ""
                                        window.requestedSystemAction = ""
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
