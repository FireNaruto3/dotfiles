import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    function toggleSystemMonitor() {
        clockDashboard.visible = false
        powerControl.visible = false
        fanControl.visible = false
        systemMonitor.visible = !systemMonitor.visible
    }

    function toggleClockDashboard() {
        systemMonitor.visible = false
        powerControl.visible = false
        fanControl.visible = false
        clockDashboard.visible = !clockDashboard.visible
    }

    function togglePowerControl(screen) {
        systemMonitor.visible = false
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
        systemMonitor.visible = false
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
    }

    NiriData {
        id: niriSource
    }

    EngineRoom {
        id: systemMonitor

        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        systemData: systemSource
        visible: false
    }

    ClockDashboard {
        id: clockDashboard

        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        systemData: systemSource
        visible: false
    }

    PowerControl {
        id: powerControl

        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        systemData: systemSource
        powerData: powerSource
        visible: false
    }

    FanControl {
        id: fanControl

        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        systemData: systemSource
        powerData: powerSource
        visible: false
    }

    IpcHandler {
        target: "panels"

        function toggleClock(): void {
            root.toggleClockDashboard()
        }

        function toggleSystem(): void {
            root.toggleSystemMonitor()
        }

        function togglePower(): void {
            root.togglePowerControl(Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
        }

        function toggleFan(): void {
            root.toggleFanControl(Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
        }
    }

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
            systemData: systemSource
            niriData: niriSource
            powerData: powerSource
            onToggleSystemMonitor: root.toggleSystemMonitor()
            onToggleClockDashboard: root.toggleClockDashboard()
            onTogglePowerControl: root.togglePowerControl(modelData)
            onToggleFanControl: root.toggleFanControl(modelData)
        }
    }
}
