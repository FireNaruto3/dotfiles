import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    function toggleSystemMonitor() {
        clockDashboard.visible = false
        systemMonitor.visible = !systemMonitor.visible
    }

    function toggleClockDashboard() {
        systemMonitor.visible = false
        clockDashboard.visible = !clockDashboard.visible
    }

    SystemData {
        id: systemSource
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

    IpcHandler {
        target: "panels"

        function toggleClock(): void {
            root.toggleClockDashboard()
        }

        function toggleSystem(): void {
            root.toggleSystemMonitor()
        }
    }

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
            systemData: systemSource
            niriData: niriSource
            onToggleSystemMonitor: root.toggleSystemMonitor()
            onToggleClockDashboard: root.toggleClockDashboard()
        }
    }
}
