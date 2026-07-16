import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var values: ({})
    property bool busy: false
    property bool refreshPending: false
    property string errorMessage: ""
    readonly property string scriptPath: Qt.resolvedUrl("scripts/power-state.sh").toString().replace("file://", "")

    readonly property string powerProfile: values.power_profile || "unknown"
    readonly property string asusProfile: values.asus_profile || "Unknown"
    readonly property string acProfile: values.ac_profile || "Unknown"
    readonly property string batteryProfile: values.battery_profile || "Unknown"
    readonly property string gpuMode: values.gpu_mode || "Unknown"
    readonly property string gpuStatus: values.gpu_status || "unknown"
    readonly property string pendingAction: values.pending_action || "Unknown"
    readonly property string pendingMode: values.pending_mode || "Unknown"
    readonly property string supportedModes: values.supported_modes || "[]"
    readonly property bool cpuFanCurveEnabled: values.cpu_fan_curve_enabled || false
    readonly property var cpuFanCurve: values.cpu_fan_curve || []
    readonly property int keyboardBrightness: values.keyboard_brightness || 0
    readonly property int keyboardMax: values.keyboard_max || 0
    readonly property int displayRefresh: values.display_refresh || 0
    readonly property int cpuFan: values.cpu_fan || 0
    readonly property int gpuFan: values.gpu_fan || 0
    readonly property int midFan: values.mid_fan || 0

    function cpuFanPercent(temperature) {
        if (!cpuFanCurveEnabled || cpuFanCurve.length === 0)
            return -1
        if (temperature <= cpuFanCurve[0].temperature)
            return cpuFanCurve[0].percent

        for (let index = 1; index < cpuFanCurve.length; index++) {
            const previous = cpuFanCurve[index - 1]
            const current = cpuFanCurve[index]
            if (temperature <= current.temperature) {
                const temperatureRange = current.temperature - previous.temperature
                if (temperatureRange <= 0)
                    return current.percent
                const progress = (temperature - previous.temperature) / temperatureRange
                return Math.round(previous.percent + progress * (current.percent - previous.percent))
            }
        }

        return cpuFanCurve[cpuFanCurve.length - 1].percent
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

    function setDefaultProfile(profile, onAc) {
        run(["asusctl", "profile", "set", onAc ? "--ac" : "--battery", profile])
    }

    function setGpuMode(mode) {
        run(["supergfxctl", "--mode", mode])
    }

    function setKeyboardBrightness(level) {
        const levels = ["off", "low", "med", "high"]
        if (level >= 0 && level < levels.length)
            run(["asusctl", "leds", "set", levels[level]])
    }

    function setDisplayMode(mode) {
        run(["niri", "msg", "output", "eDP-1", "mode", mode])
    }

    function runSystemAction(action) {
        if (action === "reboot") {
            run(["systemctl", "reboot"])
        } else if (action === "logout") {
            const session = Quickshell.env("XDG_SESSION_ID")
            if (session)
                run(["loginctl", "terminate-session", session])
            else
                setError("Unable to determine the current login session")
        }
    }

    property Process collector: Process {
        id: collector

        command: ["bash", root.scriptPath]
        running: true
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
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    property Timer errorTimer: Timer {
        id: errorTimer

        interval: 6000
        onTriggered: root.errorMessage = ""
    }
}
