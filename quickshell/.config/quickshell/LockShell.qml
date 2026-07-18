import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

ShellRoot {
    id: root

    property string password: ""
    property string inputText: ""
    property string authMessage: ""
    property bool authenticating: false
    property bool pamError: false
    property bool hidePassword: true
    property int revealDelay: 800
    property var wallpapers: []
    readonly property url backgroundSource: wallpaperSettings.wallpaper
    readonly property string wallpaperScanner: Qt.resolvedUrl("scripts/list-wallpapers.sh").toString().replace("file://", "")

    function selectWallpaper(source) {
        wallpaperSettings.wallpaper = String(source)
    }

    function authenticate(response) {
        if (authenticating || response.length === 0)
            return

        password = response
        authMessage = ""
        pamError = false
        authenticating = true
        if (!pam.start()) {
            password = ""
            authenticating = false
            authMessage = "Authentication could not be started"
        }
    }

    function runPowerAction(action) {
        const commands = {
            restart: ["systemctl", "reboot"],
            suspend: ["systemctl", "suspend-then-hibernate"],
            poweroff: ["systemctl", "poweroff"],
            logout: ["loginctl", "terminate-user", Quickshell.env("USER")]
        }

        if (commands[action])
            Quickshell.execDetached(commands[action])
    }

    Component.onCompleted: Quickshell.watchFiles = false

    SystemData {
        id: systemSource
    }

    Process {
        command: ["bash", root.wallpaperScanner]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.wallpapers = JSON.parse(text)
                } catch (error) {
                    console.warn("Unable to list lock screen wallpapers:", error)
                }
            }
        }
    }

    FileView {
        id: wallpaperState

        path: Quickshell.statePath("lockscreen.json")
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: wallpaperSettings

            property string wallpaper: "file://" + Quickshell.env("HOME") + "/dotfiles/wallpapers/Karina5.jpg"
        }
    }

    PamContext {
        id: pam

        config: "login"

        onPamMessage: {
            if (responseRequired)
                respond(root.password)
            else if (messageIsError)
                root.authMessage = message
        }

        onCompleted: result => {
            root.password = ""
            root.authenticating = false

            if (result === PamResult.Success) {
                sessionLock.locked = false
                exitTimer.start()
            } else if (result === PamResult.Error || root.pamError) {
                root.authMessage = "Authentication service unavailable"
            } else {
                root.authMessage = result === PamResult.MaxTries
                    ? "Too many attempts. Try again later."
                    : "Incorrect password"
            }
        }

        onError: {
            root.pamError = true
            root.authMessage = "Authentication service unavailable"
        }
    }

    IpcHandler {
        target: "lock"

        function isSecure(): bool {
            return sessionLock.secure
        }
    }

    Timer {
        id: exitTimer

        interval: 150
        onTriggered: Qt.quit()
    }

    Timer {
        id: acquisitionTimer

        interval: 9800
        running: true
        onTriggered: {
            if (!sessionLock.secure) {
                sessionLock.locked = false
                Qt.quit()
            }
        }
    }

    WlSessionLock {
        id: sessionLock

        locked: true
        onSecureChanged: {
            if (secure)
                acquisitionTimer.stop()
        }

        LockScreen {
            authenticating: root.authenticating
            authMessage: root.authMessage
            passwordText: root.inputText
            hidePassword: root.hidePassword
            revealDelay: root.revealDelay
            backgroundSource: root.backgroundSource
            wallpaperModel: root.wallpapers
            systemData: systemSource

            onAuthenticate: response => {
                root.inputText = ""
                root.authenticate(response)
            }
            onPasswordEdited: text => root.inputText = text
            onHidePasswordChangedByUser: hidden => root.hidePassword = hidden
            onRevealDelayChangedByUser: delay => root.revealDelay = delay
            onWallpaperSelected: source => root.selectWallpaper(source)
            onPowerActionRequested: action => root.runPowerAction(action)
        }
    }
}
