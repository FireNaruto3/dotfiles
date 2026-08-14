import QtQuick
import Quickshell
import Quickshell.Services.Mpris

PanelWindow {
    id: window

    required property var systemData
    property string kind: "volume"
    property string action: ""

    readonly property var activePlayer: {
        const players = Mpris.players.values
        for (let index = 0; index < players.length; ++index) {
            if (players[index].playbackState === MprisPlaybackState.Playing)
                return players[index]
        }
        return players.length > 0 ? players[0] : null
    }
    readonly property bool showsProgress: kind === "volume"
        || kind === "brightness"
        || kind === "keyboard"
    readonly property int progress: {
        if (kind === "brightness")
            return systemData.brightness
        if (kind === "keyboard")
            return systemData.keyboardMax > 0
                ? Math.round(systemData.keyboardBrightness / systemData.keyboardMax * 100)
                : 0
        return systemData.volume
    }

    anchors {
        bottom: true
        left: true
        right: true
    }
    margins.bottom: 48
    implicitHeight: 82
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false
    color: "transparent"
    visible: false

    function icon(): string {
        if (kind === "brightness") {
            if (systemData.brightness < 20)
                return "󰃜"
            if (systemData.brightness < 50)
                return "󰃝"
            if (systemData.brightness < 80)
                return "󰃟"
            return "󰃠"
        }
        if (kind === "microphone")
            return systemData.microphoneMuted ? "󰍭" : "󰍬"
        if (kind === "keyboard")
            return systemData.keyboardBrightness === 0 ? "󰌐" : "󰌌"
        if (kind === "media") {
            if (action === "next")
                return "󰒭"
            if (action === "previous")
                return "󰒮"
            if (action === "stop")
                return "󰓛"
            if (action === "pause")
                return "󰏤"
            return activePlayer && activePlayer.isPlaying ? "󰏤" : "󰐊"
        }
        if (kind === "lock")
            return "󰌌"
        if (systemData.muted)
            return "󰝟"
        if (systemData.volume < 34)
            return "󰕿"
        if (systemData.volume < 67)
            return "󰖀"
        return "󰕾"
    }

    function primaryText(): string {
        if (kind === "brightness")
            return `Brightness  ${systemData.brightness}%`
        if (kind === "microphone")
            return systemData.microphoneMuted ? "Microphone muted" : "Microphone active"
        if (kind === "keyboard") {
            const levels = ["Off", "Low", "Medium", "High"]
            return `Keyboard light  ${levels[Math.max(0, Math.min(3, systemData.keyboardBrightness))]}`
        }
        if (kind === "media")
            return activePlayer ? (activePlayer.trackTitle || activePlayer.identity || "Media") : "Media"
        if (kind === "lock")
            return action
        return systemData.muted ? "Volume muted" : `Volume  ${systemData.volume}%`
    }

    function secondaryText(): string {
        if (kind !== "media" || !activePlayer)
            return ""
        return activePlayer.trackArtist || activePlayer.identity || ""
    }

    function show(requestedKind, requestedAction): void {
        kind = requestedKind
        action = requestedAction || ""
        visible = true
        card.opacity = 1
        closeTimer.restart()
    }

    Timer {
        id: closeTimer
        interval: 1500
        onTriggered: card.opacity = 0
    }

    Timer {
        interval: 160
        running: card.opacity === 0 && window.visible
        onTriggered: window.visible = false
    }

    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        width: 390
        height: parent.height
        radius: 8
        color: "#f0131819"
        border.width: 1
        border.color: "#29b4dcdc"
        opacity: 0

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        Row {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                text: window.icon()
                color: window.kind === "microphone" && window.systemData.microphoneMuted
                    ? "#e78284"
                    : "#99d1db"
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 28
                horizontalAlignment: Text.AlignHCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 52
                spacing: 8

                Text {
                    width: parent.width
                    text: window.primaryText()
                    color: "#c9d3d6"
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: window.secondaryText()
                    color: "#758083"
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Rectangle {
                    width: parent.width
                    height: 7
                    visible: window.showsProgress
                    radius: 4
                    color: "#293f4749"

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(100, window.progress)) / 100
                        height: parent.height
                        radius: parent.radius
                        color: "#99d1db"

                        Behavior on width {
                            NumberAnimation { duration: 130 }
                        }
                    }
                }
            }
        }
    }
}
