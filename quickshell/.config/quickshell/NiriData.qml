import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property var workspaces: []
    property var windowsById: ({})
    property var focusedWindow: null

    function workspacesFor(output) {
        return workspaces
            .filter(workspace => workspace.output === output)
            .sort((left, right) => left.idx - right.idx)
    }

    function handleLine(line) {
        if (!line.trim())
            return

        let event
        try {
            event = JSON.parse(line)
        } catch (error) {
            console.warn("Invalid Niri event:", error, line)
            return
        }

        if (event.WorkspacesChanged) {
            workspaces = event.WorkspacesChanged.workspaces.slice()
            return
        }

        if (event.WindowsChanged) {
            const next = {}
            let focused = null
            for (const window of event.WindowsChanged.windows) {
                next[window.id] = window
                if (window.is_focused)
                    focused = window
            }
            windowsById = next
            focusedWindow = focused
            return
        }

        if (event.WindowOpenedOrChanged) {
            const window = event.WindowOpenedOrChanged.window
            const next = Object.assign({}, windowsById)
            next[window.id] = window
            windowsById = next
            if (window.is_focused || (focusedWindow && focusedWindow.id === window.id))
                focusedWindow = window
            return
        }

        if (event.WindowClosed) {
            const id = event.WindowClosed.id
            const next = Object.assign({}, windowsById)
            delete next[id]
            windowsById = next
            if (focusedWindow && focusedWindow.id === id)
                focusedWindow = null
            return
        }

        if (event.WindowFocusChanged) {
            const id = event.WindowFocusChanged.id
            focusedWindow = id === null ? null : (windowsById[id] || null)
            return
        }

        if (event.WorkspaceActivated) {
            const update = event.WorkspaceActivated
            const target = workspaces.find(workspace => workspace.id === update.id)
            if (!target)
                return

            workspaces = workspaces.map(workspace => Object.assign({}, workspace, {
                is_active: workspace.output === target.output
                    ? workspace.id === update.id
                    : workspace.is_active,
                is_focused: update.focused
                    ? workspace.id === update.id
                    : workspace.is_focused
            }))
            return
        }

        if (event.WorkspaceUrgencyChanged) {
            const update = event.WorkspaceUrgencyChanged
            workspaces = workspaces.map(workspace => workspace.id === update.id
                ? Object.assign({}, workspace, { is_urgent: update.urgent })
                : workspace)
        }
    }

    property Process eventStream: Process {
        id: eventStream

        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.handleLine(data)
        }
        onRunningChanged: {
            if (!running)
                reconnectTimer.restart()
        }
    }

    property Timer reconnectTimer: Timer {
        interval: 1000
        onTriggered: eventStream.running = true
    }
}
