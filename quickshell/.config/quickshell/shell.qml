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
        powerMonitoring: powerControl.visible || fanControl.visible
        fanMonitoring: fanControl.visible
    }

    NiriData {
        id: niriSource
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

        function updateAudio(volume: int, muted: bool): void {
            systemSource.updateAudio(volume, muted)
        }
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
