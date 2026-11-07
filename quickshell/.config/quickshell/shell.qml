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
    property bool verticalBar: true

    function togglePanel(view, screen, anchor) {
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
        if (["bluetooth", "network", "audio"].includes(view)) {
            for (const bar of bars.instances) {
                if (bar.screen === screen)
                    return bar.serviceAnchor(view)
            }
        }
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
    property bool previousNumLock: false
    property bool previousScrollLock: false

    function showOsd(kind, action, refreshData = true) {
        osd.screen = focusedScreen()
        osd.show(kind, action)
        if (refreshData && kind !== "media" && kind !== "lock")
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
        monitoring: ["bluetooth", "network", "audio"].includes(root.activePanel)
    }

    NiriData {
        id: niriSource
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
                root.previousNumLock = systemSource.numLock
                root.previousScrollLock = systemSource.scrollLock
                root.lockStateInitialized = true
                return
            }

            if (root.previousNumLock !== systemSource.numLock)
                root.showOsd("lock", `Num Lock ${systemSource.numLock ? "On" : "Off"}`)
            else if (root.previousScrollLock !== systemSource.scrollLock)
                root.showOsd("lock", `Scroll Lock ${systemSource.scrollLock ? "On" : "Off"}`)

            root.previousNumLock = systemSource.numLock
            root.previousScrollLock = systemSource.scrollLock
        }

        function onCapsLockUpdated(enabled: bool): void {
            root.showOsd("lock", `Caps Lock ${enabled ? "On" : "Off"}`)
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

        function toggleOrientation(): void {
            root.toggleBarOrientation()
        }

        function togglePower(): void {
            const screen = root.focusedScreen()
            root.togglePanel("power", screen, root.defaultPanelAnchor("power", screen))
        }

        function toggleBluetooth(): void {
            const screen = root.focusedScreen()
            root.togglePanel("bluetooth", screen, root.defaultPanelAnchor("bluetooth", screen))
        }

    }

    IpcHandler {
        target: "osd"

        function showVolume(volume: int, muted: bool): void {
            systemSource.updateVolume(volume, muted)
            root.showOsd("volume", "", false)
        }
        function showBrightness(brightness: int): void {
            systemSource.updateBrightness(brightness)
            root.showOsd("brightness", "", false)
        }
        function showMicrophone(): void { root.showOsd("microphone", "") }
        function showKeyboard(): void { root.showOsd("keyboard", "") }
        function showKeyboardEffect(effect: string): void { root.showOsd("keyboard-effect", effect, false) }
        function showPowerProfile(profile: string): void { root.showOsd("power-profile", profile, false) }
        function showTouchpad(state: string): void { root.showOsd("touchpad", state, false) }
        function showPlayPause(): void { root.showOsd("media", "play-pause") }
        function showPlay(): void { root.showOsd("media", "play") }
        function showPause(): void { root.showOsd("media", "pause") }
        function showStop(): void { root.showOsd("media", "stop") }
        function showPrevious(): void { root.showOsd("media", "previous") }
        function showNext(): void { root.showOsd("media", "next") }
    }

    Variants {
        id: bars
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
            drawerAnchor: root.panelScreen === modelData ? root.panelAnchor : (vertical ? height / 2 : width / 2)
            onOpenResources: root.openResources()
            onToggleDrawer: (view, anchor) => root.togglePanel(view, modelData, anchor)
            onCloseDrawer: root.closePanel()
            onToggleOrientation: root.toggleBarOrientation()
        }
    }
}
