import Quickshell

ShellRoot {
    SystemData {
        id: systemSource
    }

    NiriData {
        id: niriSource
    }

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
            systemData: systemSource
            niriData: niriSource
        }
    }
}
