import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property var values: ({})
    property bool powerMonitoring: false
    property bool busy: false
    property bool refreshPending: false
    property string errorMessage: ""
    readonly property string scriptPath: Qt.resolvedUrl("scripts/power-state.sh").toString().replace("file://", "")
    readonly property string displayScriptPath: Qt.resolvedUrl("scripts/display-control.sh").toString().replace("file://", "")

    readonly property string powerProfile: values.power_profile || "unknown"
    readonly property int keyboardBrightness: values.keyboard_brightness || 0
    readonly property int keyboardMax: values.keyboard_max || 0
    readonly property int chargeLimit: values.charge_limit || 0
    readonly property int displayRefresh: values.display_refresh || 0
    readonly property var displayRefreshRates: values.display_refresh_rates || []

    onPowerMonitoringChanged: {
        if (powerMonitoring && !collector.running)
            collector.running = true
    }

    function refresh() {
        if (collector.running || busy) {
            refreshPending = true
            return
        }

        refreshPending = false
        collector.running = true
    }

    function setError(message) {
        errorMessage = message
        errorTimer.restart()
    }

    function run(command) {
        if (busy) {
            setError("Another power setting is still being applied")
            return
        }

        errorMessage = ""
        errorTimer.stop()
        busy = true
        actionRunner.exec(command)
    }

    function setPowerProfile(profile) {
        run(["powerprofilesctl", "set", profile])
    }

    function setChargeLimit(limit) {
        run(["asusctl", "battery", "limit", limit.toString()])
    }

    function setKeyboardBrightness(level) {
        const levels = ["off", "low", "med", "high"]
        if (level >= 0 && level < levels.length)
            run(["asusctl", "leds", "set", levels[level]])
    }

    function setDisplayRefresh(refresh) {
        run(["bash", displayScriptPath, "set-refresh", refresh.toString()])
    }

    property Process collector: Process {
        id: collector

        command: ["bash", root.scriptPath]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.values = JSON.parse(text.trim())
                } catch (error) {
                    root.setError("Unable to read power state")
                }
            }
        }
        onExited: {
            if (root.refreshPending) {
                root.refreshPending = false
                refreshTimer.restart()
            }
        }
    }

    property Process actionRunner: Process {
        id: actionRunner

        stdout: StdioCollector { id: actionOutput }
        stderr: StdioCollector { id: actionError }
        onExited: (exitCode, exitStatus) => {
            root.busy = false
            if (exitCode !== 0)
                root.setError(actionError.text.trim() || actionOutput.text.trim() || "Power setting failed")
            root.refreshPending = true
            refreshTimer.restart()
        }
    }

    property Timer refreshTimer: Timer {
        id: refreshTimer

        interval: 400
        onTriggered: root.refresh()
    }

    property Timer pollTimer: Timer {
        interval: 3000
        running: root.powerMonitoring
        repeat: true
        onTriggered: root.refresh()
    }

    property Timer errorTimer: Timer {
        id: errorTimer

        interval: 6000
        onTriggered: root.errorMessage = ""
    }
}
