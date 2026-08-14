import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    function openResources() {
        Quickshell.execDetached([
            "sh", "-c",
            "pkill -TERM -x -u \"$(id -u)\" resources || exec resources"
        ])
    }

    function toggleClockDashboard(screen) {
        powerControl.visible = false
        fanControl.visible = false
        if (clockDashboard.visible && clockDashboard.screen === screen) {
            clockDashboard.visible = false
        } else {
            clockDashboard.screen = screen
            clockDashboard.visible = true
        }
    }

    function focusedScreen() {
        const focusedWorkspace = niriSource.workspaces.find(workspace => workspace.is_focused)
        if (focusedWorkspace) {
            for (let index = 0; index < Quickshell.screens.length; index++) {
                if (Quickshell.screens[index].name === focusedWorkspace.output)
                    return Quickshell.screens[index]
            }
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

    property bool lockStateInitialized: false
    property bool previousCapsLock: false
    property bool previousNumLock: false
    property bool previousScrollLock: false

    function showOsd(kind, action) {
        osd.screen = focusedScreen()
        osd.show(kind, action)
        if (kind !== "media" && kind !== "lock")
            systemSource.refresh()
    }

    function togglePowerControl(screen) {
        clockDashboard.visible = false
        fanControl.visible = false

        if (powerControl.visible && powerControl.screen === screen) {
            powerControl.visible = false
        } else {
            powerControl.screen = screen
            powerControl.visible = true
        }
    }

    function toggleFanControl(screen) {
        clockDashboard.visible = false
        powerControl.visible = false

        if (fanControl.visible && fanControl.screen === screen) {
            fanControl.visible = false
        } else {
            fanControl.screen = screen
            fanControl.visible = true
        }
    }

    SystemData {
        id: systemSource
    }

    PowerData {
        id: powerSource
        powerMonitoring: powerControl.visible
        fanMonitoring: fanControl.visible
    }

    NiriData {
        id: niriSource
    }

    Osd {
        id: osd

        screen: null
        systemData: systemSource
    }

    Connections {
        target: systemSource

        function onRefreshed(): void {
            if (!root.lockStateInitialized) {
                root.previousCapsLock = systemSource.capsLock
                root.previousNumLock = systemSource.numLock
                root.previousScrollLock = systemSource.scrollLock
                root.lockStateInitialized = true
                return
            }

            if (root.previousCapsLock !== systemSource.capsLock)
                root.showOsd("lock", `Caps Lock ${systemSource.capsLock ? "On" : "Off"}`)
            else if (root.previousNumLock !== systemSource.numLock)
                root.showOsd("lock", `Num Lock ${systemSource.numLock ? "On" : "Off"}`)
            else if (root.previousScrollLock !== systemSource.scrollLock)
                root.showOsd("lock", `Scroll Lock ${systemSource.scrollLock ? "On" : "Off"}`)

            root.previousCapsLock = systemSource.capsLock
            root.previousNumLock = systemSource.numLock
            root.previousScrollLock = systemSource.scrollLock
        }

        function onKeyboardBrightnessUpdated(changed: bool): void {
            if (changed) {
                osd.screen = root.focusedScreen()
                osd.show("keyboard", "")
            }
        }
    }

    ClockDashboard {
        id: clockDashboard

        screen: null
        systemData: systemSource
        visible: false
    }

    PowerControl {
        id: powerControl

        screen: null
        systemData: systemSource
        powerData: powerSource
        visible: false
    }

    FanControl {
        id: fanControl

        screen: null
        powerData: powerSource
        visible: false
    }

    IpcHandler {
        target: "panels"

        function toggleClock(): void {
            root.toggleClockDashboard(root.focusedScreen())
        }

        function toggleSystem(): void {
            root.openResources()
        }

        function togglePower(): void {
            root.togglePowerControl(root.focusedScreen())
        }

        function toggleFan(): void {
            root.toggleFanControl(root.focusedScreen())
        }
    }

    IpcHandler {
        target: "osd"

        function showVolume(): void { root.showOsd("volume", "") }
        function showBrightness(): void { root.showOsd("brightness", "") }
        function showMicrophone(): void { root.showOsd("microphone", "") }
        function showKeyboard(): void { root.showOsd("keyboard", "") }
        function showPlayPause(): void { root.showOsd("media", "play-pause") }
        function showPlay(): void { root.showOsd("media", "play") }
        function showPause(): void { root.showOsd("media", "pause") }
        function showStop(): void { root.showOsd("media", "stop") }
        function showPrevious(): void { root.showOsd("media", "previous") }
        function showNext(): void { root.showOsd("media", "next") }
    }

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
            systemData: systemSource
            niriData: niriSource
            onOpenResources: root.openResources()
            onToggleClockDashboard: root.toggleClockDashboard(modelData)
            onTogglePowerControl: root.togglePowerControl(modelData)
            onToggleFanControl: root.toggleFanControl(modelData)
        }
    }
}
