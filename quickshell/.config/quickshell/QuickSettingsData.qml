import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property var values: ({})
    property bool monitoring: false
    property bool busy: false
    property bool refreshPending: false
    property string errorMessage: ""
    readonly property string scriptPath: Qt.resolvedUrl("scripts/quick-settings.sh").toString().replace("file://", "")

    readonly property bool wifiEnabled: values.wifi_enabled === true
    readonly property var wifiNetworks: values.wifi_networks || []
    readonly property bool bluetoothPowered: values.bluetooth_powered === true
    readonly property var bluetoothDevices: values.bluetooth_devices || []
    readonly property var sinks: values.sinks || []
    readonly property var sources: values.sources || []
    readonly property var displays: values.displays || []
    readonly property var vpns: values.vpns || []

    onMonitoringChanged: {
        if (monitoring)
            refresh()
    }

    function refresh(): void {
        if (collector.running || busy) {
            refreshPending = true
            return
        }
        collector.running = true
    }

    function run(action, arguments): void {
        if (busy) {
            errorMessage = "Another setting is still being applied"
            errorTimer.restart()
            return
        }

        errorMessage = ""
        errorTimer.stop()
        busy = true
        actionRunner.command = ["bash", scriptPath, action].concat(arguments || [])
        actionRunner.running = true
    }

    property Process collector: Process {
        id: collector
        command: ["bash", root.scriptPath, "state"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.values = JSON.parse(text.trim())
                } catch (error) {
                    root.errorMessage = "Unable to read quick settings"
                    errorTimer.restart()
                }
            }
        }
        onExited: {
            if (root.refreshPending) {
                root.refreshPending = false
                refreshDelay.restart()
            }
        }
    }

    property Process actionRunner: Process {
        id: actionRunner
        stdout: StdioCollector { id: actionOutput }
        stderr: StdioCollector { id: actionError }
        onExited: (exitCode, exitStatus) => {
            root.busy = false
            if (exitCode !== 0) {
                root.errorMessage = actionError.text.trim() || actionOutput.text.trim() || "Setting failed"
                errorTimer.restart()
            }
            actionRunner.command = []
            refreshDelay.restart()
        }
    }

    property Timer pollTimer: Timer {
        interval: 5000
        running: root.monitoring
        repeat: true
        onTriggered: root.refresh()
    }

    property Timer refreshDelay: Timer {
        id: refreshDelay
        interval: 500
        onTriggered: root.refresh()
    }

    property Timer errorTimer: Timer {
        id: errorTimer
        interval: 7000
        onTriggered: root.errorMessage = ""
    }
}
