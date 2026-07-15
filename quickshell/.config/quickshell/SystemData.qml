import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property var values: ({})
    readonly property string scriptPath: Qt.resolvedUrl("scripts/system-stats.sh").toString().replace("file://", "")

    readonly property int cpu: values.cpu || 0
    readonly property real memoryUsed: values.memory_used || 0
    readonly property real memoryTotal: values.memory_total || 0
    readonly property int cpuTemp: values.cpu_temp || 0
    readonly property int gpuTemp: values.gpu_temp || 0
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
}
