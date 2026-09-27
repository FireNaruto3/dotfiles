import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    readonly property var palette: {
        if (!themeFile.loaded)
            return ({})

        try {
            return JSON.parse(themeFile.text())
        } catch (error) {
            console.warn("Unable to parse generated theme:", error)
            return ({})
        }
    }

    readonly property color background: palette.background || "#e6131819"
    readonly property color card: palette.card || "#1a1b26"
    readonly property color cardHover: palette.cardHover || "#26343d40"
    readonly property color cardActive: palette.cardActive || "#334f6b75"
    readonly property color border: palette.border || "#3399d1db"
    readonly property color accent: palette.accent || "#99d1db"
    readonly property color text: palette.text || "#c6d0f5"
    readonly property color textMuted: palette.textMuted || "#758083"
    readonly property color success: palette.success || "#a6d189"
    readonly property color warning: palette.warning || "#e5c890"
    readonly property color error: palette.error || "#e78284"
    readonly property string fontFamily: "JetBrains Mono Nerd Font"

    property FileView themeFile: FileView {
        path: Quickshell.env("HOME") + "/.cache/matugen/quickshell.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }
}
