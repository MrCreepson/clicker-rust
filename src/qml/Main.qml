import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import clicker_rust

ApplicationWindow {
    id: root
    visible: true
    width: 620
    height: 250
    title: qsTr("Rust Clicker")

    flags: Qt.FramelessWindowHint
    color: "transparent"

    readonly property color panelBg: "#a6111513"
    readonly property color surfaceBg: "#66202824"
    readonly property color surfaceHover: "#8a2b3630"
    readonly property color borderSubtle: "#38ffffff"
    readonly property color accent: "#8fd3b6"
    readonly property color accentSoft: "#338fd3b6"
    readonly property color textPrimary: "#f2f5f3"
    readonly property color textMuted: "#a8b5ae"

    property int currentClickCode: 272
    property int currentListenCode: 276
    property string statusMessage: "Ready"
    property int interval_ms: 60
    property bool clickerActive: false
    property int currentCaptureMode: 0
    property bool blinkPhase: true

    property string hotkeyDevice: NaN
    property string captureDevice: NaN

    function refreshKeyLabels() {
        currentClickCode = Backend.click_key_code_val()
        currentListenCode = Backend.listen_key_code_val()
    }

    Component.onCompleted: {
        deviceCombo.model = Backend.device_names()
        Backend.init_worker()
        Backend.set_interval_ms(root.interval_ms)
        refreshKeyLabels()
    }

    Timer {
        id: syncTimer
        interval: 150
        repeat: true
        running: true
        onTriggered: {
            const runningNow = Backend.is_running_val()
            const modeNow = Backend.capture_mode_val()

            const hotkeyDeviceNow = Backend.hotkey_device_val()
            const captureDeviceNow = Backend.capture_device_val()

            root.clickerActive = runningNow
            root.currentCaptureMode = modeNow

            root.hotkeyDevice = hotkeyDeviceNow
            root.captureDevice = captureDeviceNow

            if (modeNow !== 0) {
                root.blinkPhase = !root.blinkPhase
            } else {
                root.blinkPhase = true
            }
        }
    }

    Timer {
        id: captureWatchdog
        interval: 50
        repeat: true
        running: capturePopup.opened
        onTriggered: {
            if (Date.now() - capturePopup.openedAt < 180) {
                return
            }
            if (!Backend.is_capturing()) {
                refreshKeyLabels()
                statusMessage = "Zaktualizowano (Click: " + currentClickCode + ", Listen: " + currentListenCode + ")"
                capturePopup.close()
            }
        }
    }

    background: Rectangle {
        radius: 12
        color: root.panelBg
        border.width: 1
        border.color: root.borderSubtle
        antialiasing: true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        ColumnLayout {
            anchors.top: parent.top

            // Status bulb
            Label {
                id: statusBulb
                text: "⬤"
                padding: 5
                color: {
                    if (root.currentCaptureMode !== 0) {
                        return root.blinkPhase ? "#f5c451" : "#3a2e12"
                    }
                    return root.clickerActive ? "#6ee7a8" : "#ef5350"
                }

                Behavior on color {
                    ColorAnimation { duration: 250 }
                }
            }

            // Row 1
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ComboBox {
                    id: deviceCombo
                    Layout.fillWidth: true
                    implicitHeight: 32

                    contentItem: Text {
                        leftPadding: 10
                        rightPadding: 24
                        text: deviceCombo.displayText
                        font.pixelSize: 12
                        color: root.textPrimary
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    background: Rectangle {
                        radius: 8
                        color: deviceCombo.hovered ? root.surfaceHover : root.surfaceBg
                        border.width: 1
                        border.color: deviceCombo.popup.visible ? root.accent : root.borderSubtle
                    }

                    popup: Popup {
                        y: deviceCombo.height + 4
                        width: deviceCombo.width
                        implicitHeight: Math.min(contentItem.implicitHeight + 8, 180)
                        padding: 4

                        background: Rectangle {
                            radius: 8
                            color: "#e6141816"
                            border.width: 1
                            border.color: root.borderSubtle
                        }

                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: deviceCombo.delegateModel
                            ScrollIndicator.vertical: ScrollIndicator {}
                        }
                    }

                    delegate: ItemDelegate {
                        width: deviceCombo.width - 8
                        height: 28
                        highlighted: deviceCombo.highlightedIndex === index

                        contentItem: Text {
                            text: modelData
                            color: highlighted ? "#0e1311" : root.textPrimary
                            font.pixelSize: 12
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        background: Rectangle {
                            radius: 6
                            color: highlighted ? root.accent : (hovered ? root.surfaceHover : "transparent")
                        }
                    }

                    onActivated: function(index) {
                        Backend.select_device_by_label(currentText)
                        statusMessage = "Capture dev: " + currentText
                    }
                }

                Button {
                    id: setHotkeyDevBtn
                    text: "Set hotkey dev"
                    implicitHeight: 32
                    leftPadding: 12
                    rightPadding: 12

                    contentItem: Text {
                        text: setHotkeyDevBtn.text
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: root.textPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 8
                        color: setHotkeyDevBtn.down ? root.accentSoft : (setHotkeyDevBtn.hovered ? root.surfaceHover : root.surfaceBg)
                        border.width: 1
                        border.color: setHotkeyDevBtn.hovered ? root.accent : root.borderSubtle

                        Behavior on color {
                            ColorAnimation { duration: 110 }
                        }
                    }

                    onClicked: {
                        Backend.set_listen_device_to_selected()
                        statusMessage = "Hotkey dev set to: " + deviceCombo.currentText
                    }
                }
            }

            // Row 2
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Button {
                    id: toggleBtn
                    implicitHeight: 34
                    leftPadding: 12
                    rightPadding: 14

                    contentItem: RowLayout {
                        spacing: 7

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: root.clickerActive ? "#9ef0c8" : root.textMuted
                        }

                        Text {
                            text: root.clickerActive ? "Clicker: ON" : "Toggle Clicker"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: root.clickerActive ? "#0d1310" : root.textPrimary
                        }
                    }

                    background: Rectangle {
                        radius: 8
                        color: root.clickerActive
                            ? root.accent
                            : (toggleBtn.down ? root.accentSoft : (toggleBtn.hovered ? root.surfaceHover : root.surfaceBg))
                        border.width: 1
                        border.color: root.clickerActive ? root.accent : root.borderSubtle

                        Behavior on color {
                            ColorAnimation { duration: 110 }
                        }
                    }

                    onClicked: {
                        Backend.toggle_clicker()
                        root.clickerActive = !root.clickerActive
                        statusMessage = root.clickerActive ? "Clicker active (" + root.interval_ms + " ms)" : "Clicker stopped"
                    }
                }

                RowLayout {
                    spacing: 5

                    Rectangle {
                        implicitWidth: 68
                        implicitHeight: 34
                        radius: 8
                        color: root.surfaceBg
                        border.width: 1
                        border.color: intervalField.activeFocus ? root.accent : root.borderSubtle

                        TextInput {
                            id: intervalField
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            horizontalAlignment: TextInput.AlignRight
                            text: "" + root.interval_ms
                            color: root.textPrimary
                            selectionColor: root.accent
                            selectedTextColor: "#0e1311"
                            font.pixelSize: 12
                            font.family: "JetBrains Mono"
                            validator: IntValidator { bottom: 1; top: 60000 }

                            onEditingFinished: {
                                let val = parseInt(text, 10)
                                if (!isNaN(val) && val >= 1) {
                                    root.interval_ms = val
                                    Backend.set_interval_ms(val)
                                    statusMessage = "Interval: " + val + " ms"
                                } else {
                                    text = "" + root.interval_ms
                                }
                            }
                        }
                    }

                    Label {
                        text: "ms"
                        color: root.textMuted
                        font.pixelSize: 12
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    id: changeClickBtn
                    text: "Click [" + currentClickCode + "]"
                    implicitHeight: 34
                    leftPadding: 10
                    rightPadding: 10

                    contentItem: Text {
                        text: changeClickBtn.text
                        font.pixelSize: 12
                        font.family: "JetBrains Mono"
                        color: root.textPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 8
                        color: changeClickBtn.down ? root.accentSoft : (changeClickBtn.hovered ? root.surfaceHover : root.surfaceBg)
                        border.width: 1
                        border.color: changeClickBtn.hovered ? root.accent : root.borderSubtle

                        Behavior on color {
                            ColorAnimation { duration: 110 }
                        }
                    }

                    onClicked: {
                        capturePopup.modeText = "Clicking button"
                        capturePopup.open()
                        Backend.arm_capture_click_key_code()
                    }
                }

                Button {
                    id: changeListenBtn
                    text: "Hotkey [" + currentListenCode + "]"
                    implicitHeight: 34
                    leftPadding: 10
                    rightPadding: 10

                    contentItem: Text {
                        text: changeListenBtn.text
                        font.pixelSize: 12
                        font.family: "JetBrains Mono"
                        color: root.textPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 8
                        color: changeListenBtn.down ? root.accentSoft : (changeListenBtn.hovered ? root.surfaceHover : root.surfaceBg)
                        border.width: 1
                        border.color: changeListenBtn.hovered ? root.accent : root.borderSubtle

                        Behavior on color {
                            ColorAnimation { duration: 110 }
                        }
                    }

                    onClicked: {
                        capturePopup.modeText = "Hotkey start/stop"
                        capturePopup.open()
                        Backend.arm_capture_listen_key_code()
                    }
                }
            }

        }

        // Row 3
        ColumnLayout {
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 24
                radius: 6
                color: "#3d0b0e0d"
                border.width: 1
                border.color: "#22ffffff"

                Label {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: Text.AlignVCenter
                    text: "Capture device: " + root.captureDevice
                    color: root.textMuted
                    font.pixelSize: 11
                    font.family: "JetBrains Mono"
                    elide: Text.ElideRight
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 24
                radius: 6
                color: "#3d0b0e0d"
                border.width: 1
                border.color: "#22ffffff"


                Label {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: Text.AlignVCenter
                    text: "Hotkey Device: " + root.hotkeyDevice
                    color: root.textMuted
                    font.pixelSize: 11
                    font.family: "JetBrains Mono"
                    elide: Text.ElideRight
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 24
                radius: 6
                color: "#3d0b0e0d"
                border.width: 1
                border.color: "#22ffffff"

                Label {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: Text.AlignVCenter
                    text: statusMessage
                    color: root.textMuted
                    font.pixelSize: 11
                    font.family: "JetBrains Mono"
                    elide: Text.ElideRight
                }
            }
        }
    }

    Popup {
        id: capturePopup
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose
        padding: 16

        property string modeText: ""
        property real openedAt: 0

        onOpened: {
            openedAt = Date.now()
        }

        background: Rectangle {
            radius: 10
            color: "#ec121614"
            border.width: 1
            border.color: root.accent
        }

        Shortcut {
            sequence: "Escape"
            enabled: capturePopup.opened
            onActivated: {
                Backend.cancel_capture()
                statusMessage = "Capture canceled"
                capturePopup.close()
            }
        }

        ColumnLayout {
            spacing: 6

            Label {
                text: "Listening: " + capturePopup.modeText
                color: root.accent
                font.bold: true
                font.pixelSize: 13
            }

            Label {
                text: "Press mouse or keboard button (Esc = cance)..."
                color: root.textPrimary
                font.pixelSize: 12
            }
        }
    }
}