import QtQuick

SystemButton {
    id: root

    required property int brightness
    readonly property real level: Math.max(0, Math.min(100, brightness)) / 100

    implicitWidth: 34
    tooltip: `Brightness: ${brightness}%`

    // Draw the sun rather than relying on an icon-font glyph.
    Item {
        anchors.centerIn: parent
        width: 16
        height: 16

        Rectangle {
            anchors.centerIn: parent
            width: 7
            height: 7
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: root.foreground

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: width / 2
                color: root.foreground
                opacity: root.level
            }
        }

        Repeater {
            model: 8

            Item {
                required property int index
                anchors.fill: parent
                rotation: index * 45

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 0
                    width: 1.5
                    height: 2.5
                    radius: 0.75
                    color: root.foreground
                }
            }
        }
    }

}
