/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.plasma.private.sessions
import org.kde.plasma.workspace.components as PW

Item {
    id: root

    // KScreenLocker sets this property when the view becomes visible.
    property bool viewVisible: false
    property bool uiVisible: false
    property bool sessionPickerVisible: false
    property bool passwordlessReady: false
    property string notification: ""
    property date currentTime: new Date()

    implicitWidth: 800
    implicitHeight: 600
    focus: true
    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary

    component AdagioActionButton: QQC2.ToolButton {
        id: actionButton

        padding: 10

        background: Rectangle {
            radius: 8
            color: actionButton.down ? "#d11b2535"
                  : actionButton.hovered ? "#b31b2535" : "#991b2535"
            border.color: actionButton.activeFocus ? "white" : "#99ffffff"
            border.width: actionButton.activeFocus ? 2 : 1
        }

        contentItem: RowLayout {
            spacing: 8

            Kirigami.Icon {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                source: actionButton.icon.name
                isMask: true
                color: "white"
            }

            Text {
                text: actionButton.text
                font: actionButton.font
                color: "white"
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    function showUnlock() {
        if (sessionPickerVisible) {
            return;
        }
        uiVisible = true;
        authenticator.startAuthenticating();
        passwordField.forceActiveFocus();
        idleTimer.restart();
    }

    function submitPassword() {
        if (authenticator.graceLocked || passwordlessReady) {
            return;
        }
        notification = "";
        authenticator.respond(passwordField.text);
    }

    function hideUnlock() {
        if (virtualKeyboard.item && virtualKeyboard.item.activated) {
            virtualKeyboard.item.activated = false;
            Qt.inputMethod.hide();
        }
        passwordField.clear();
        notification = "";
        sessionPickerVisible = false;
        uiVisible = false;
        forceActiveFocus();
    }

    Component.onCompleted: {
        authenticator.startAuthenticating();
        if (typeof defaultToSwitchUser !== "undefined" && defaultToSwitchUser) {
            uiVisible = true;
            sessionPickerVisible = true;
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            if (sessionPickerVisible) {
                sessionPickerVisible = false;
                idleTimer.restart();
                passwordField.forceActiveFocus();
            } else if (uiVisible) {
                hideUnlock();
            }
            event.accepted = true;
        } else if (!uiVisible) {
            showUnlock();
            event.accepted = false;
        }
    }

    Connections {
        target: authenticator

        function onFailed(kind) {
            if (kind !== 0) {
                return;
            }
            root.notification = i18n("Unlocking failed");
            passwordField.clear();
            root.uiVisible = true;
            retryTimer.restart();
            idleTimer.restart();
        }

        function onSucceeded() {
            if (authenticator.hadPrompt) {
                Qt.quit();
            } else {
                root.passwordlessReady = true;
                root.uiVisible = true;
            }
        }

        function onPromptForSecretChanged() {
            root.passwordlessReady = false;
            if (root.uiVisible) {
                passwordField.forceActiveFocus();
            }
        }

        function onPromptChanged() {
            root.notification = authenticator.prompt;
        }

        function onInfoMessageChanged() {
            root.notification = authenticator.infoMessage;
        }

        function onErrorMessageChanged() {
            root.notification = authenticator.errorMessage;
        }
    }

    Timer {
        id: retryTimer
        interval: 3000
        onTriggered: {
            authenticator.startAuthenticating();
            root.notification = "";
            passwordField.forceActiveFocus();
        }
    }

    Timer {
        id: idleTimer
        interval: 10000
        onTriggered: {
            if (passwordField.text.length === 0 && !root.passwordlessReady
                    && !sleepConfirmation.opened
                    && !(virtualKeyboard.item && virtualKeyboard.item.activated)) {
                root.hideUnlock();
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    SessionManagement {
        id: sessionManagement
    }

    KeyboardIndicator.KeyState {
        id: capsLockState
        key: Qt.Key_CapsLock
    }

    Connections {
        target: sessionManagement
        function onAboutToSuspend() {
            passwordField.clear();
        }
    }

    AdagioWallpaperFader {
        anchors.fill: parent
        sourceItem: wallpaper
        revealed: root.uiVisible
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.uiVisible ? Qt.ArrowCursor : Qt.BlankCursor
        onClicked: root.showUnlock()
        onPositionChanged: {
            if (root.uiVisible) {
                idleTimer.restart();
            }
        }
    }

    AdagioClock {
        currentTime: root.currentTime
        promptVisible: root.uiVisible
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: Kirigami.Units.gridUnit
        anchors.bottomMargin: Kirigami.Units.gridUnit
        visible: config.alwaysShowClock && (!config.hideClockWhenIdle || root.uiVisible) && opacity > 0
    }

    ColumnLayout {
        id: unlockForm
        width: Math.min(380, root.width - 32)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: virtualKeyboard.item && virtualKeyboard.item.activated
                                      ? -virtualKeyboard.item.height / 2 : 42
        spacing: Kirigami.Units.smallSpacing
        visible: opacity > 0 && (root.uiVisible || userAvatar.scale > 0 || userLabel.opacity > 0
                 || passwordRow.opacity > 0 || actionRow.opacity > 0
                 || (mediaLoader.item && mediaLoader.item.opacity > 0))
        enabled: root.uiVisible && !root.sessionPickerVisible
        opacity: root.sessionPickerVisible ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 250 } }

        AdagioUserAvatar {
            id: userAvatar
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 92
            Layout.preferredHeight: 92
            userImage: kscreenlocker_userImage
            revealed: root.uiVisible
        }

        PlasmaComponents.Label {
            id: userLabel
            Layout.fillWidth: true
            Layout.topMargin: 5
            text: kscreenlocker_userName
            font.pixelSize: 19
            font.weight: Font.Medium
            color: "white"
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            opacity: root.uiVisible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
        }

        RowLayout {
            id: passwordRow
            Layout.fillWidth: true
            Layout.topMargin: 12
            spacing: 6
            visible: !root.passwordlessReady && (root.uiVisible || opacity > 0)
            opacity: 0
            state: root.uiVisible ? "shown" : "hidden"
            transform: Translate { id: passwordSlide; y: -40 }

            states: [
                State { name: "hidden" },
                State {
                    name: "shown"
                    PropertyChanges { target: passwordRow; opacity: 1 }
                    PropertyChanges { target: passwordSlide; y: 0 }
                }
            ]

            transitions: [
                Transition {
                    from: "hidden"
                    to: "shown"
                    SequentialAnimation {
                        PauseAnimation { duration: 350 }
                        ParallelAnimation {
                            NumberAnimation { target: passwordRow; property: "opacity"; from: 0; to: 1; duration: 500; easing.type: Easing.OutQuart }
                            NumberAnimation { target: passwordSlide; property: "y"; from: 40; to: 0; duration: 500; easing.type: Easing.OutQuart }
                        }
                    }
                },
                Transition {
                    from: "shown"
                    to: "hidden"
                    SequentialAnimation {
                        PauseAnimation { duration: 350 }
                        ParallelAnimation {
                            NumberAnimation { target: passwordRow; property: "opacity"; from: 1; to: 0; duration: 500; easing.type: Easing.OutQuart }
                            NumberAnimation { target: passwordSlide; property: "y"; from: 0; to: -40; duration: 500; easing.type: Easing.OutQuart }
                        }
                    }
                }
            ]

            PlasmaExtras.PasswordField {
                id: passwordField
                Layout.fillWidth: true
                focus: root.uiVisible
                enabled: !authenticator.graceLocked
                placeholderText: i18n("Password")
                Accessible.name: i18n("Password")
                inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData
                                  | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                onAccepted: root.submitPassword()
                onTextChanged: idleTimer.restart()
            }

            Image {
                id: loginButton
                source: "login.svg"
                sourceSize: Qt.size(passwordField.height, passwordField.height)
                Layout.preferredWidth: passwordField.height
                Layout.preferredHeight: passwordField.height
                fillMode: Image.PreserveAspectFit
                smooth: true
                mirror: LayoutMirroring.enabled
                Accessible.name: i18n("Unlock")
                opacity: passwordField.text.length > 0 ? 0.75 : 0
                visible: opacity > 0
                enabled: passwordField.text.length > 0
                Behavior on opacity {
                    NumberAnimation { duration: passwordField.text.length > 0 ? 100 : 80 }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: loginButton.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.submitPassword()
                }
            }
        }

        ActionButton {
            Layout.alignment: Qt.AlignHCenter
            visible: root.passwordlessReady
            text: i18n("Unlock")
            icon.name: "unlock"
            onClicked: Qt.quit()
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.topMargin: 5
            text: {
                const parts = [];
                if (capsLockState.locked) {
                    parts.push(i18n("Caps Lock is on"));
                }
                if (root.notification) {
                    parts.push(root.notification);
                }
                return parts.join(" · ");
            }
            color: "white"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: text.length > 0
        }

        RowLayout {
            id: actionRow
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 12
            spacing: 8
            opacity: root.uiVisible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }

            ActionButton {
                visible: sessionManagement.canSwitchUser
                text: i18n("Switch User")
                icon.name: "system-switch-user"
                onClicked: {
                    if (switchPage.hasEntries) {
                        idleTimer.stop();
                        root.sessionPickerVisible = true;
                    } else {
                        sessionManagement.switchUser();
                    }
                }
            }

            ActionButton {
                visible: sessionManagement.canSuspend
                text: i18n("Sleep")
                icon.name: "system-suspend"
                onClicked: sleepConfirmation.open()
            }
        }

        Loader {
            id: mediaLoader
            Layout.fillWidth: true
            Layout.topMargin: 8
            Layout.preferredHeight: item && item.visible ? item.implicitHeight : 0
            active: config.showMediaControls
            source: "MediaControls.qml"
            onLoaded: item.promptVisible = Qt.binding(() => root.uiVisible)
        }

        Connections {
            target: mediaLoader.item
            function onControlUsed() {
                idleTimer.stop();
            }
        }
    }

    Loader {
        active: root.viewVisible
        source: "LockOsd.qml"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Kirigami.Units.gridUnit
        z: 8
    }

    SessionManagementScreen {
        id: switchPage
        anchors.fill: parent
        z: 5
        active: root.sessionPickerVisible
        onBack: {
            root.sessionPickerVisible = false;
            idleTimer.restart();
            passwordField.forceActiveFocus();
        }
    }

    RowLayout {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        opacity: root.uiVisible ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }

        AdagioActionButton {
            visible: virtualKeyboard.status === Loader.Ready
            text: i18n("Virtual Keyboard")
            icon.name: "input-keyboard-virtual-off"
            onClicked: {
                root.showUnlock();
                virtualKeyboard.item.activated = !virtualKeyboard.item.activated;
                if (virtualKeyboard.item.activated) {
                    Qt.inputMethod.show();
                } else {
                    Qt.inputMethod.hide();
                }
                passwordField.forceActiveFocus();
            }
        }

        AdagioActionButton {
            visible: layoutSwitcher.hasMultipleKeyboardLayouts
            text: layoutSwitcher.layoutNames.longName
            icon.name: "input-keyboard"
            Accessible.description: i18n("Switch keyboard layout")
            onClicked: layoutSwitcher.keyboardLayout.switchToNextLayout()

            PW.KeyboardLayoutSwitcher {
                id: layoutSwitcher
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
            }
        }

        Item { Layout.fillWidth: true }

        Battery { }
    }

    Loader {
        id: virtualKeyboard
        anchors.fill: parent
        z: 10
        source: "AdagioVirtualKeyboard.qml"
    }

    QQC2.Popup {
        id: sleepConfirmation
        parent: root
        x: (root.width - width) / 2
        y: (root.height - height) / 2
        width: Math.min(360, root.width - 32)
        padding: 20
        modal: true
        focus: true
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

        function confirm() {
            close();
            sessionManagement.suspend();
        }

        onOpened: {
            idleTimer.stop();
            cancelSleepButton.forceActiveFocus();
        }
        onClosed: {
            if (root.uiVisible) {
                idleTimer.restart();
                passwordField.forceActiveFocus();
            }
        }

        background: Rectangle {
            radius: 12
            color: "#ee1b2535"
            border.color: "#bbffffff"
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 16

            Text {
                Layout.fillWidth: true
                text: i18n("Put the computer to sleep?")
                color: "white"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                AdagioActionButton {
                    id: cancelSleepButton
                    text: i18n("Cancel")
                    icon.name: "dialog-cancel"
                    onClicked: sleepConfirmation.close()
                }

                AdagioActionButton {
                    text: i18n("Sleep")
                    icon.name: "system-suspend"
                    onClicked: sleepConfirmation.confirm()
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 20
        enabled: root.uiVisible
        acceptedButtons: Qt.RightButton
        onClicked: root.hideUnlock()
    }
}
