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
    property string powerPassword: ""
    property string powerAction: ""
    property string powerMessage: ""
    property bool powerAuthenticating: false
    property bool powerBusy: false
    property bool powerPamError: false
    property bool hidePassword: true
    property bool capsLock: false
    property bool batteryAvailable: false
    property int batteryPercentage: 0
    property string batteryState: "unknown"
    property var wallpapers: []
    readonly property url backgroundSource: wallpaperSettings.wallpaper
    readonly property string wallpaperScanner: Qt.resolvedUrl("scripts/list-wallpapers.sh").toString().replace("file://", "")
    readonly property string capsLockReader: Qt.resolvedUrl("scripts/caps-lock-state.sh").toString().replace("file://", "")

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

    function requestPowerAction(action, response) {
        if (powerBusy)
            return

        powerMessage = ""
        if (action === "suspend") {
            runPowerAction(action)
            return
        }

        if (response.length === 0) {
            powerMessage = "Password required"
            return
        }

        powerAction = action
        powerPassword = response
        powerPamError = false
        powerAuthenticating = true
        powerBusy = true
        if (!powerPam.start()) {
            powerPassword = ""
            powerAuthenticating = false
            powerMessage = "Authentication could not be started"
            powerBusy = false
        }
    }

    function runPowerAction(action) {
        const commands = {
            restart: ["systemctl", "reboot"],
            suspend: ["systemctl", "suspend"],
            poweroff: ["systemctl", "poweroff"],
            logout: ["loginctl", "terminate-user", Quickshell.env("USER")]
        }

        if (!commands[action]) {
            powerMessage = "Unknown power action"
            powerBusy = false
            return
        }

        powerBusy = true
        powerProcess.command = commands[action]
        powerProcess.running = true
    }

    Component.onCompleted: Quickshell.watchFiles = false

    ShellTheme {
        id: themeSource
    }

    Process {
        id: capsLockProcess

        command: ["sh", root.capsLockReader]
        running: true
        stdout: StdioCollector { id: capsLockOutput }
        onExited: root.capsLock = capsLockOutput.text.trim() === "true"
    }

    Process {
        id: batteryProcess

        command: ["upower", "-i", "/org/freedesktop/UPower/devices/DisplayDevice"]
        running: true
        stdout: StdioCollector { id: batteryOutput }
        onExited: {
            const percentage = batteryOutput.text.match(/percentage:\s*([0-9.]+)%/)
            const state = batteryOutput.text.match(/state:\s*([^\n]+)/)
            root.batteryAvailable = percentage !== null
            if (percentage !== null)
                root.batteryPercentage = Math.round(Number(percentage[1]))
            if (state !== null)
                root.batteryState = state[1].trim()
        }
    }

    Process {
        id: powerProcess

        stdout: StdioCollector { id: powerOutput }
        stderr: StdioCollector { id: powerError }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.powerMessage = powerError.text.trim()
                    || powerOutput.text.trim()
                    || "Power action failed"
            root.powerBusy = false
        }
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            if (!capsLockProcess.running)
                capsLockProcess.running = true
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: {
            if (!batteryProcess.running)
                batteryProcess.running = true
        }
    }

    Process {
        command: ["bash", root.wallpaperScanner]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const listedWallpapers = JSON.parse(text)
                    root.wallpapers = listedWallpapers
                    if (listedWallpapers.length > 0
                            && !listedWallpapers.some(item => item.source === String(root.backgroundSource)))
                        wallpaperSettings.wallpaper = listedWallpapers[0].source
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

        config: "quickshell-lock"

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

    PamContext {
        id: powerPam

        config: "quickshell-lock"

        onPamMessage: {
            if (responseRequired)
                respond(root.powerPassword)
            else if (messageIsError)
                root.powerMessage = message
        }

        onCompleted: result => {
            const action = root.powerAction
            root.powerPassword = ""
            root.powerAuthenticating = false

            if (result === PamResult.Success) {
                root.runPowerAction(action)
            } else {
                root.powerMessage = result === PamResult.MaxTries
                    ? "Too many attempts. Try again later."
                    : (result === PamResult.Error || root.powerPamError
                        ? "Authentication service unavailable"
                        : "Incorrect password")
                root.powerBusy = false
            }
        }

        onError: {
            root.powerPamError = true
            root.powerMessage = "Authentication service unavailable"
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
            backgroundSource: root.backgroundSource
            wallpaperModel: root.wallpapers
            batteryAvailable: root.batteryAvailable
            batteryPercentage: root.batteryPercentage
            batteryState: root.batteryState
            capsLock: root.capsLock
            powerAuthenticating: root.powerAuthenticating
            powerBusy: root.powerBusy
            powerMessage: root.powerMessage
            theme: themeSource

            onAuthenticate: response => {
                root.inputText = ""
                root.authenticate(response)
            }
            onPasswordEdited: text => root.inputText = text
            onHidePasswordChangedByUser: hidden => root.hidePassword = hidden
            onWallpaperSelected: source => root.selectWallpaper(source)
            onPowerStateReset: root.powerMessage = ""
            onPowerActionRequested: (action, response) => root.requestPowerAction(action, response)
        }
    }
}
