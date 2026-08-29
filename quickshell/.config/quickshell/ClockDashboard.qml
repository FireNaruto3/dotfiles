import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: window

    required property var systemData

    ShellTheme { id: theme }

    readonly property var activePlayer: {
        const players = Mpris.players.values
        for (let index = 0; index < players.length; ++index) {
            if (players[index].playbackState === MprisPlaybackState.Playing)
                return players[index]
        }
        return players.length > 0 ? players[0] : null
    }
    property int displayedMonth: clock.date.getMonth()
    property int displayedYear: clock.date.getFullYear()
    readonly property int firstWeekday: new Date(displayedYear, displayedMonth, 1).getDay()
    readonly property int daysInMonth: new Date(displayedYear, displayedMonth + 1, 0).getDate()
    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    implicitWidth: 440
    implicitHeight: 478

    function changeMonth(offset) {
        const next = new Date(displayedYear, displayedMonth + offset, 1)
        displayedMonth = next.getMonth()
        displayedYear = next.getFullYear()
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: theme.background
        border.width: 1
        border.color: theme.border

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Rectangle {
                width: parent.width
                height: 112
                radius: 5
                color: theme.card

                Rectangle {
                    id: albumArt

                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 88
                    height: 88
                    radius: 4
                    color: theme.cardHover
                    clip: true

                    Image {
                        id: coverImage

                        anchors.fill: parent
                        source: window.activePlayer ? window.activePlayer.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !window.activePlayer || coverImage.status !== Image.Ready
                        text: "󰎈"
                        color: theme.textMuted
                        font.family: theme.fontFamily
                        font.pixelSize: 34
                    }
                }

                Text {
                    anchors.left: albumArt.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    y: 15
                    text: window.activePlayer
                        ? (window.activePlayer.trackTitle || "Unknown title")
                        : "Nothing playing"
                    color: theme.text
                    elide: Text.ElideRight
                    font.family: theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    anchors.left: albumArt.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    y: 39
                    text: window.activePlayer
                        ? (window.activePlayer.trackArtist || window.activePlayer.identity || "Unknown artist")
                        : "Start a media player to see it here"
                    color: theme.textMuted
                    elide: Text.ElideRight
                    font.family: theme.fontFamily
                    font.pixelSize: 12
                }

                Row {
                    anchors.left: albumArt.right
                    anchors.leftMargin: 14
                    y: 67
                    spacing: 8

                    Repeater {
                        model: ["previous", "toggle", "next"]

                        Rectangle {
                            required property string modelData

                            width: 38
                            height: 30
                            radius: 15
                            color: mediaMouse.containsMouse ? theme.cardActive : theme.cardHover

                            Text {
                                anchors.centerIn: parent
                                text: modelData === "previous"
                                    ? "󰒮"
                                    : (modelData === "next"
                                        ? "󰒭"
                                        : (window.activePlayer && window.activePlayer.isPlaying ? "󰏤" : "󰐊"))
                                color: theme.accent
                                font.family: theme.fontFamily
                                font.pixelSize: 16
                            }

                            MouseArea {
                                id: mediaMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: window.activePlayer !== null
                                onClicked: {
                                    if (modelData === "previous" && window.activePlayer.canGoPrevious)
                                        window.activePlayer.previous()
                                    else if (modelData === "next" && window.activePlayer.canGoNext)
                                        window.activePlayer.next()
                                    else if (modelData === "toggle" && window.activePlayer.canTogglePlaying)
                                        window.activePlayer.togglePlaying()
                                }
                            }
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 10

                Rectangle {
                    width: (parent.width - 10) / 2
                    height: 62
                    radius: 5
                    color: dndMouse.containsMouse ? theme.cardActive : theme.card

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: window.systemData.dnd ? "󰂛" : "󰂚"
                        color: window.systemData.dnd ? theme.warning : theme.accent
                        font.family: theme.fontFamily
                        font.pixelSize: 22
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 48
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "Do Not Disturb"
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Text {
                            text: window.systemData.dnd ? "Enabled" : "Disabled"
                            color: theme.textMuted
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    MouseArea {
                        id: dndMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Quickshell.execDetached([
                            "makoctl", "mode", "-t", "do-not-disturb"
                        ])
                    }
                }

                Rectangle {
                    width: (parent.width - 10) / 2
                    height: 62
                    radius: 5
                    color: theme.card

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰅐"
                        color: theme.accent
                        font.family: theme.fontFamily
                        font.pixelSize: 22
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 48
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "System Uptime"
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Text {
                            text: window.systemData.uptime
                            color: theme.textMuted
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 252
                radius: 5
                color: theme.card

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12

                    Text {
                        width: 32
                        text: "󰅁"
                        color: previousMouse.containsMouse ? theme.accent : theme.textMuted
                        font.family: theme.fontFamily
                        font.pixelSize: 17

                        MouseArea {
                            id: previousMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: window.changeMonth(-1)
                        }
                    }

                    Text {
                        width: parent.width - 64
                        horizontalAlignment: Text.AlignHCenter
                        text: `${window.monthNames[window.displayedMonth]} ${window.displayedYear}`
                        color: theme.text
                        font.family: theme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        width: 32
                        horizontalAlignment: Text.AlignRight
                        text: "󰅂"
                        color: nextMouse.containsMouse ? theme.accent : theme.textMuted
                        font.family: theme.fontFamily
                        font.pixelSize: 17

                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: window.changeMonth(1)
                        }
                    }
                }

                Grid {
                    id: calendarGrid

                    x: 12
                    y: 48
                    columns: 7
                    rows: 7
                    spacing: 2

                    Repeater {
                        model: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

                        Text {
                            required property string modelData

                            width: 55
                            height: 24
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: modelData
                            color: theme.textMuted
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    Repeater {
                        model: 42

                        Rectangle {
                            required property int index

                            readonly property int day: index - window.firstWeekday + 1
                            readonly property bool validDay: day > 0 && day <= window.daysInMonth
                            readonly property bool today: validDay
                                && day === clock.date.getDate()
                                && window.displayedMonth === clock.date.getMonth()
                                && window.displayedYear === clock.date.getFullYear()

                            width: 55
                            height: 25
                            radius: 12
                            color: today ? theme.cardActive : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: parent.validDay ? parent.day : ""
                                color: parent.today ? theme.accent : theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 11
                                font.bold: parent.today
                            }
                        }
                    }
                }
            }
        }
    }
}
