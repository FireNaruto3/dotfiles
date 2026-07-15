import QtQuick

Item {
    id: root

    property real value: 0
    property color accent: "#a9f3d1"
    property string icon: ""

    implicitWidth: 104
    implicitHeight: 104

    onValueChanged: gauge.requestPaint()
    onAccentChanged: gauge.requestPaint()

    Canvas {
        id: gauge

        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const context = getContext("2d")
            const center = width / 2
            const radius = Math.min(width, height) / 2 - 7
            const start = Math.PI * 0.75
            const sweep = Math.PI * 1.5
            const progress = Math.max(0, Math.min(100, root.value)) / 100

            context.reset()
            context.lineWidth = 10
            context.lineCap = "round"

            context.beginPath()
            context.strokeStyle = "rgba(103, 118, 121, 0.28)"
            context.arc(center, center, radius, start, start + sweep, false)
            context.stroke()

            if (progress > 0) {
                context.beginPath()
                context.strokeStyle = root.accent
                context.arc(center, center, radius, start, start + sweep * progress, false)
                context.stroke()
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.icon
            color: "#cfeaff"
            font.family: "JetBrains Mono Nerd Font"
            font.pixelSize: 30
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: `${Math.round(root.value)}%`
            color: "#c9d3d6"
            font.family: "JetBrains Mono Nerd Font"
            font.pixelSize: 13
            font.bold: true
        }
    }
}
