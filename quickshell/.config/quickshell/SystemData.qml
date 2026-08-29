import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property var values: ({})
    property var resourceValues: ({})
    property real previousCpuIdle: -1
    property real previousCpuTotal: -1
    readonly property string scriptPath: Qt.resolvedUrl("scripts/system-stats.sh").toString().replace("file://", "")
    readonly property string resourceScriptPath: Qt.resolvedUrl("scripts/resource-stats.sh").toString().replace("file://", "")
    readonly property int cpuUsage: resourceValues.cpu || 0
    readonly property int memoryPercent: resourceValues.memory_percent || 0
    readonly property real memoryUsed: resourceValues.memory_used || 0
    readonly property real memoryTotal: resourceValues.memory_total || 0
    readonly property string bluetooth: values.bluetooth || "off"
    readonly property string bluetoothDevice: values.bluetooth_device || ""
    readonly property string network: values.network || "disconnected"
    readonly property string ssid: values.ssid || ""
    readonly property int signal: values.signal || 0
    readonly property int volume: values.volume || 0
    readonly property bool muted: values.muted || false
    readonly property bool microphoneMuted: values.microphone_muted || false
    readonly property int brightness: values.brightness || 0
    readonly property int keyboardBrightness: values.keyboard_brightness || 0
    readonly property int keyboardMax: values.keyboard_max || 3
    readonly property bool capsLock: values.caps_lock || false
    readonly property bool numLock: values.num_lock || false
    readonly property bool scrollLock: values.scroll_lock || false
    readonly property int battery: values.battery || 0
    readonly property string batteryState: values.battery_state || "Unknown"
    readonly property real batteryPower: values.battery_power || 0
    readonly property string batteryTime: values.battery_time || ""
    readonly property int batteryHealth: values.battery_health || 0
    readonly property string uptime: values.uptime || "-"
    readonly property bool dnd: values.dnd || false
    property bool refreshPending: false
    property int observedKeyboardBrightness: -1

    signal refreshed()
    signal keyboardBrightnessUpdated(bool changed)

    function refresh(): void {
        if (collector.running)
            refreshPending = true
        else
            collector.running = true
    }

    property Process collector: Process {
        id: collector

        command: ["bash", root.scriptPath]
        running: true
        onRunningChanged: {
            if (!running && root.refreshPending) {
                root.refreshPending = false
                running = true
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.values = JSON.parse(text.trim())
                    root.refreshed()
                } catch (error) {
                    console.warn("Unable to parse system data:", error, text)
                }
            }
        }
    }

    property Timer refreshTimer: Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (!collector.running)
                root.refresh()
        }
    }

    property Process resourceCollector: Process {
        id: resourceCollector

        command: ["bash", root.resourceScriptPath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim())
                    const totalDelta = data.cpu_total - root.previousCpuTotal
                    const idleDelta = data.cpu_idle - root.previousCpuIdle
                    const cpu = root.previousCpuTotal >= 0 && totalDelta > 0
                        ? Math.round(100 * Math.max(0, totalDelta - idleDelta) / totalDelta)
                        : 0
                    root.previousCpuIdle = data.cpu_idle
                    root.previousCpuTotal = data.cpu_total
                    root.resourceValues = Object.assign({}, data, { cpu: cpu })
                } catch (error) {
                    console.warn("Unable to parse resource data:", error, text)
                }
            }
        }
    }

    property Timer resourceRefreshTimer: Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (!resourceCollector.running)
                resourceCollector.running = true
        }
    }

    property Process keyboardCollector: Process {
        id: keyboardCollector

        command: ["brightnessctl", "-d", "asus::kbd_backlight", "-m"]
        running: true
        stdout: StdioCollector { id: keyboardOutput }
        onExited: {
            const fields = keyboardOutput.text.trim().split(",")
            if (fields.length < 5)
                return

            const level = parseInt(fields[2])
            const maximum = parseInt(fields[4])
            if (isNaN(level) || isNaN(maximum))
                return

            const changed = root.observedKeyboardBrightness >= 0
                && root.observedKeyboardBrightness !== level
            root.observedKeyboardBrightness = level
            root.values = Object.assign({}, root.values, {
                keyboard_brightness: level,
                keyboard_max: maximum
            })
            root.keyboardBrightnessUpdated(changed)
        }
    }

    property Timer keyboardRefreshTimer: Timer {
        interval: 400
        running: true
        repeat: true
        onTriggered: {
            if (!keyboardCollector.running)
                keyboardCollector.running = true
        }
    }

}
