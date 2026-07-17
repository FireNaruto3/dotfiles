import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property var values: ({})
    property var resourceValues: ({})
    property bool resourceMonitoring: false
    readonly property string scriptPath: Qt.resolvedUrl("scripts/system-stats.sh").toString().replace("file://", "")
    readonly property string resourceScriptPath: Qt.resolvedUrl("scripts/resource-stats.sh").toString().replace("file://", "")

    readonly property int cpu: resourceValues.cpu || 0
    readonly property string load1: resourceValues.load_1 || "0.00"
    readonly property string load5: resourceValues.load_5 || "0.00"
    readonly property string load15: resourceValues.load_15 || "0.00"
    readonly property int gpu: resourceValues.gpu || 0
    readonly property string gpuClock: resourceValues.gpu_clock || "-"
    readonly property string gpuMaxClock: resourceValues.gpu_max_clock || "-"
    readonly property real memoryUsed: resourceValues.memory_used || 0
    readonly property real memoryTotal: resourceValues.memory_total || 0
    readonly property int memoryPercent: resourceValues.memory_percent || 0
    readonly property real memoryCache: resourceValues.memory_cache || 0
    readonly property real swapUsed: resourceValues.swap_used || 0
    readonly property real swapTotal: resourceValues.swap_total || 0
    readonly property int cpuTemp: resourceValues.cpu_temp || 0
    readonly property int gpuTemp: resourceValues.gpu_temp || 0
    readonly property string bluetooth: values.bluetooth || "off"
    readonly property string bluetoothDevice: values.bluetooth_device || ""
    readonly property string network: values.network || "disconnected"
    readonly property string ssid: values.ssid || ""
    readonly property int signal: values.signal || 0
    readonly property int volume: values.volume || 0
    readonly property bool muted: values.muted || false
    readonly property int brightness: values.brightness || 0
    readonly property int battery: values.battery || 0
    readonly property string batteryState: values.battery_state || "Unknown"
    readonly property real batteryPower: values.battery_power || 0
    readonly property string batteryTime: values.battery_time || ""
    readonly property int batteryHealth: values.battery_health || 0
    readonly property string uptime: values.uptime || "-"
    readonly property bool dnd: values.dnd || false

    onResourceMonitoringChanged: {
        if (resourceMonitoring && !resourceCollector.running)
            resourceCollector.running = true
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
                collector.running = true
        }
    }

    property Process resourceCollector: Process {
        id: resourceCollector

        command: ["bash", root.resourceScriptPath]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.resourceValues = JSON.parse(text.trim())
                } catch (error) {
                    console.warn("Unable to parse resource data:", error, text)
                }
            }
        }
    }

    property Timer resourceRefreshTimer: Timer {
        interval: 1000
        running: root.resourceMonitoring
        repeat: true
        onTriggered: {
            if (!resourceCollector.running)
                resourceCollector.running = true
        }
    }
}
