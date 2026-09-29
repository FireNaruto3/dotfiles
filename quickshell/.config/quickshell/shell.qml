import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    function openResources() {
        Quickshell.execDetached([
            "sh", "-c",
            "pkill -TERM -x -u \"$(id -u)\" resources || exec niri msg action spawn -- resources"
        ])
    }

    property string activePanel: "none"
    property var panelScreen: null
    property real panelAnchor: 0
    property string panelPage: "network"
    property bool verticalBar: true

    function togglePanel(view, screen, anchor, page) {
        const pageChanged = view === "quickSettings" && page && panelPage !== page
        if (view === "quickSettings" && page)
            panelPage = page
        if (activePanel === view && panelScreen === screen && pageChanged)
            return
        if (activePanel === view && panelScreen === screen) {
            closePanel()
            return
        }

        panelScreen = screen
        panelAnchor = anchor
        activePanel = view
    }

    function closePanel() {
        activePanel = "none"
    }

    function toggleBarOrientation() {
        closePanel()
        verticalBar = !verticalBar
    }

    function defaultPanelAnchor(view, screen) {
        if (!screen)
            return 0
        if (!verticalBar)
            return screen.width - 180
        if (view === "clock")
            return screen.height - 70
        if (view === "power")
            return screen.height - 104
        return screen.height / 2
    }

    function focusedScreen() {
        const focusedWorkspace = niriSource.workspaces.find(workspace => workspace.is_focused)
        if (focusedWorkspace) {
            for (let index = 0; index < Quickshell.screens.length; index++) {
                if (Quickshell.screens[index].name === focusedWorkspace.output)
                    return Quickshell.screens[index]
            }
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

    property bool lockStateInitialized: false
    property bool previousCapsLock: false
    property bool previousNumLock: false
    property bool previousScrollLock: false

    function showOsd(kind, action) {
        osd.screen = focusedScreen()
        osd.show(kind, action)
        if (kind !== "media" && kind !== "lock")
            systemSource.refresh()
    }

    SystemData {
        id: systemSource
    }

    PowerData {
        id: powerSource
        powerMonitoring: root.activePanel === "power"
    }

    QuickSettingsData {
        id: quickSettingsSource
        monitoring: root.activePanel === "quickSettings"
    }

    NiriData {
        id: niriSource
    }

    Process {
        command: [
            "sh", "-c",
            "pkill -TERM -f \"^$HOME/.local/bin/flameshot-v14$\" 2>/dev/null || true; sleep 0.25; exec \"$HOME/.local/bin/flameshot-v14\""
        ]
        running: true
    }

    Osd {
        id: osd

        screen: null
        systemData: systemSource
    }

    Connections {
        target: systemSource

        function onRefreshed(): void {
            if (!root.lockStateInitialized) {
                root.previousCapsLock = systemSource.capsLock
                root.previousNumLock = systemSource.numLock
                root.previousScrollLock = systemSource.scrollLock
                root.lockStateInitialized = true
                return
            }

            if (root.previousCapsLock !== systemSource.capsLock)
                root.showOsd("lock", `Caps Lock ${systemSource.capsLock ? "On" : "Off"}`)
            else if (root.previousNumLock !== systemSource.numLock)
                root.showOsd("lock", `Num Lock ${systemSource.numLock ? "On" : "Off"}`)
            else if (root.previousScrollLock !== systemSource.scrollLock)
                root.showOsd("lock", `Scroll Lock ${systemSource.scrollLock ? "On" : "Off"}`)

            root.previousCapsLock = systemSource.capsLock
            root.previousNumLock = systemSource.numLock
            root.previousScrollLock = systemSource.scrollLock
        }

        function onKeyboardBrightnessUpdated(changed: bool): void {
            if (changed) {
                osd.screen = root.focusedScreen()
                osd.show("keyboard", "")
            }
        }
    }

    IpcHandler {
        target: "panels"

        function toggleClock(): void {
            const screen = root.focusedScreen()
            root.togglePanel("clock", screen, root.defaultPanelAnchor("clock", screen))
        }

        function toggleSystem(): void {
            const screen = root.focusedScreen()
            root.togglePanel("quickSettings", screen, root.defaultPanelAnchor("quickSettings", screen), "network")
        }

        function toggleOrientation(): void {
            root.toggleBarOrientation()
        }

        function togglePower(): void {
            const screen = root.focusedScreen()
            root.togglePanel("power", screen, root.defaultPanelAnchor("power", screen))
        }

        function toggleQuickSettings(): void {
            const screen = root.focusedScreen()
            root.togglePanel("quickSettings", screen, root.defaultPanelAnchor("quickSettings", screen), "network")
        }

    }

    IpcHandler {
        target: "osd"

        function showVolume(): void { root.showOsd("volume", "") }
        function showBrightness(): void { root.showOsd("brightness", "") }
        function showMicrophone(): void { root.showOsd("microphone", "") }
        function showKeyboard(): void { root.showOsd("keyboard", "") }
        function showPlayPause(): void { root.showOsd("media", "play-pause") }
        function showPlay(): void { root.showOsd("media", "play") }
        function showPause(): void { root.showOsd("media", "pause") }
        function showStop(): void { root.showOsd("media", "stop") }
        function showPrevious(): void { root.showOsd("media", "previous") }
        function showNext(): void { root.showOsd("media", "next") }
    }

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
            systemData: systemSource
            powerData: powerSource
            quickSettingsData: quickSettingsSource
            niriData: niriSource
            vertical: root.verticalBar
            activeView: root.panelScreen === modelData ? root.activePanel : "none"
            quickSettingsPage: root.panelPage
            drawerAnchor: root.panelScreen === modelData ? root.panelAnchor : (vertical ? height / 2 : width / 2)
            onOpenResources: root.openResources()
            onToggleDrawer: (view, anchor) => root.togglePanel(view, modelData, anchor)
            onToggleQuickSettings: (page, anchor) => root.togglePanel("quickSettings", modelData, anchor, page)
            onCloseDrawer: root.closePanel()
            onToggleOrientation: root.toggleBarOrientation()
        }
    }
}
