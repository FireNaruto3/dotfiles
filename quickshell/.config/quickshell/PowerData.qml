import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property var values: ({})
    property var fanValues: ({})
    property var fanCurveValues: ({})
    property bool powerMonitoring: false
    property bool fanMonitoring: false
    property bool busy: false
    property bool refreshPending: false
    property string errorMessage: ""
    readonly property string scriptPath: Qt.resolvedUrl("scripts/power-state.sh").toString().replace("file://", "")
    readonly property string fanScriptPath: Qt.resolvedUrl("scripts/fan-stats.sh").toString().replace("file://", "")
    readonly property string fanCurveScriptPath: Qt.resolvedUrl("scripts/fan-curves.sh").toString().replace("file://", "")
    readonly property string displayScriptPath: Qt.resolvedUrl("scripts/display-control.sh").toString().replace("file://", "")

    readonly property string powerProfile: values.power_profile || "unknown"
    readonly property int keyboardBrightness: values.keyboard_brightness || 0
    readonly property int keyboardMax: values.keyboard_max || 0
    readonly property int chargeLimit: values.charge_limit || 0
    readonly property int displayRefresh: values.display_refresh || 0
    readonly property var displayRefreshRates: values.display_refresh_rates || []
    readonly property string fanProfile: fanCurveValues.fan_profile || "Unknown"
    readonly property int cpuTemp: fanValues.cpu_temp || 0
    readonly property bool cpuTempAvailable: fanValues.cpu_temp_available === true
    readonly property int gpuTemp: fanValues.gpu_temp || 0
    readonly property bool gpuTempAvailable: fanValues.gpu_temp_available === true
    readonly property string gpuTempState: fanValues.gpu_temp_state || "unavailable"
    readonly property int cpuFan: fanValues.cpu_fan || 0
    readonly property bool cpuFanAvailable: fanValues.cpu_fan_available === true
    readonly property int gpuFan: fanValues.gpu_fan || 0
    readonly property bool gpuFanAvailable: fanValues.gpu_fan_available === true
    readonly property int midFan: fanValues.mid_fan || 0
    readonly property bool midFanAvailable: fanValues.mid_fan_available === true
    readonly property bool cpuFanCurveAvailable: fanCurveValues.cpu_fan_curve_available === true
    readonly property bool gpuFanCurveAvailable: fanCurveValues.gpu_fan_curve_available === true
    readonly property bool cpuFanCurveEnabled: fanCurveValues.cpu_fan_curve_enabled || false
    readonly property bool gpuFanCurveEnabled: fanCurveValues.gpu_fan_curve_enabled || false
    readonly property var cpuFanCurve: fanCurveValues.cpu_fan_curve || []
    readonly property var gpuFanCurve: fanCurveValues.gpu_fan_curve || []

    function fanCurvePercent(curve, temperature, enabled) {
        if (!enabled || temperature <= 0 || curve.length === 0)
            return -1
        if (temperature <= curve[0].temperature)
            return curve[0].percent

        for (let index = 1; index < curve.length; index++) {
            const previous = curve[index - 1]
            const current = curve[index]
            if (temperature <= current.temperature) {
                const temperatureRange = current.temperature - previous.temperature
                if (temperatureRange <= 0)
                    return current.percent
                const progress = (temperature - previous.temperature) / temperatureRange
                return Math.round(previous.percent + progress * (current.percent - previous.percent))
            }
        }

        return curve[curve.length - 1].percent
    }

    onFanMonitoringChanged: {
        if (fanMonitoring) {
            if (!fanCollector.running)
                fanCollector.running = true
            if (!fanCurveCollector.running)
                fanCurveCollector.running = true
        }
    }

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
            if (root.fanMonitoring && !fanCollector.running)
                fanCollector.running = true
            if (root.fanMonitoring && !fanCurveCollector.running)
                fanCurveCollector.running = true
        }
    }

    property Process fanCollector: Process {
        id: fanCollector

        command: ["bash", root.fanScriptPath]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.fanValues = JSON.parse(text.trim())
                } catch (error) {
                    console.warn("Unable to parse fan data:", error, text)
                }
            }
        }
    }

    property Process fanCurveCollector: Process {
        id: fanCurveCollector

        command: ["bash", root.fanCurveScriptPath]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.fanCurveValues = JSON.parse(text.trim())
                } catch (error) {
                    console.warn("Unable to parse fan curve data:", error, text)
                }
            }
        }
    }

    property Timer fanPollTimer: Timer {
        interval: 1000
        running: root.fanMonitoring
        repeat: true
        onTriggered: {
            if (!fanCollector.running)
                fanCollector.running = true
        }
    }

    property Timer fanCurvePollTimer: Timer {
        interval: 15000
        running: root.fanMonitoring
        repeat: true
        onTriggered: {
            if (!fanCurveCollector.running)
                fanCurveCollector.running = true
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
