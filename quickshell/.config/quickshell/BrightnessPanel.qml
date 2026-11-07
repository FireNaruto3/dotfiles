import QtQuick
import Quickshell.Io

Item {
    id: root

    required property var systemData
    property string controlScript: Qt.resolvedUrl("scripts/display-control.sh").toString().replace("file://", "")
    property int preview: -1
    property int requestedBrightness: 5
    property string errorMessage: ""
    readonly property bool busy: setter.running
    readonly property int displayedBrightness: preview >= 0 ? preview : systemData.brightness

    implicitWidth: 350
    implicitHeight: 140 + (errorMessage.length > 0 ? 42 : 0)

    ShellTheme { id: theme }

    function clampBrightness(value) {
        return Math.max(5, Math.min(100, Math.round(value)))
    }

    function applyBrightness(value) {
        if (busy)
            return
        requestedBrightness = clampBrightness(value)
        preview = requestedBrightness
        errorMessage = ""
        setter.running = true
    }

    Process {
        id: setter
        command: ["bash", root.controlScript, "set-brightness", `${root.requestedBrightness}%`]
        stderr: StdioCollector { id: setterError }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root.systemData.updateBrightness(root.requestedBrightness)
            else
                root.errorMessage = setterError.text.trim() || "Unable to set display brightness"
            root.preview = -1
            root.systemData.refresh()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: theme.background
        border.width: 1
        border.color: theme.border

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Item {
                width: parent.width
                height: 24

                Text {
                    text: "Display brightness"
                    color: theme.text
                    font.family: theme.fontFamily
                    font.pixelSize: 16
                    font.bold: true
                }

                Text {
                    anchors.right: parent.right
                    text: `${root.displayedBrightness}%`
                    color: theme.accent
                    font.family: theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                }
            }

            Item {
                id: slider
                width: parent.width
                height: 30
                enabled: !root.busy
                opacity: enabled ? 1 : 0.6
                activeFocusOnTab: true

                Keys.onPressed: event => {
                    let value
                    switch (event.key) {
                    case Qt.Key_Left: value = root.displayedBrightness - 1; break
                    case Qt.Key_Right: value = root.displayedBrightness + 1; break
                    case Qt.Key_Home: value = 5; break
                    case Qt.Key_End: value = 100; break
                    default: return
                    }
                    event.accepted = true
                    root.applyBrightness(value)
                }

                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    x: handle.width / 2
                    width: parent.width - handle.width
                    height: 6
                    radius: 3
                    color: theme.cardHover

                    Rectangle {
                        width: Math.max(0, Math.min(1, (root.displayedBrightness - 5) / 95)) * parent.width
                        height: parent.height
                        radius: parent.radius
                        color: theme.accent
                    }
                }

                Rectangle {
                    id: handle
                    x: Math.max(0, Math.min(1, (root.displayedBrightness - 5) / 95)) * (slider.width - width)
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18
                    radius: 9
                    color: mouse.pressed ? theme.text : theme.accent
                    border.width: 2
                    border.color: slider.activeFocus ? theme.text : theme.background
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    preventStealing: true

                    function updatePreview(mouseX) {
                        const ratio = Math.max(0, Math.min(1, (mouseX - handle.width / 2) / track.width))
                        root.preview = root.clampBrightness(5 + ratio * 95)
                    }

                    onPressed: event => {
                        slider.forceActiveFocus()
                        updatePreview(event.x)
                    }
                    onPositionChanged: event => {
                        if (pressed)
                            updatePreview(event.x)
                    }
                    onReleased: event => {
                        updatePreview(event.x)
                        root.applyBrightness(root.preview)
                    }
                    onCanceled: root.preview = -1
                }
            }

            Text {
                width: parent.width
                text: "Drag to choose · Arrow keys adjust by 1% · Minimum 5%"
                color: theme.textMuted
                font.family: theme.fontFamily
                font.pixelSize: 9
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                visible: root.errorMessage.length > 0
                text: root.errorMessage
                color: theme.error
                font.family: theme.fontFamily
                font.pixelSize: 10
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }
}
