/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.sessions

Item {
    id: sessionScreen

    property bool active: false
    readonly property bool hasEntries: sessionsModel.count > 0
    signal back()

    visible: active || opacity > 0
    enabled: active
    opacity: active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }

    SessionsModel {
        id: sessionsModel
        showNewSessionEntry: true
    }

    function switchSelected() {
        if (!userList.currentItem) {
            return;
        }
        const vt = userList.selectedVtNumber;
        if (vt === -1) {
            sessionsModel.startNewSession();
        } else {
            sessionsModel.switchUser(vt);
        }
        back();
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            back();
            event.accepted = true;
        }
    }

    onActiveChanged: {
        if (active) {
            userList.forceActiveFocus();
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, Kirigami.Units.gridUnit * 32)
        spacing: Kirigami.Units.gridUnit

        Text {
            Layout.fillWidth: true
            text: i18n("Switch User")
            color: "white"
            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 6
            horizontalAlignment: Text.AlignHCenter
        }

        UserList {
            id: userList
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 9
            model: sessionsModel
            Keys.onReturnPressed: sessionScreen.switchSelected()
            Keys.onEnterPressed: sessionScreen.switchSelected()
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.smallSpacing

            ActionButton {
                enabled: userList.currentItem !== null
                text: userList.selectedVtNumber === -1 ? i18n("Start New Session") : i18n("Switch Session")
                icon.name: "system-switch-user"
                onClicked: sessionScreen.switchSelected()
            }

            ActionButton {
                text: i18n("Back")
                icon.name: "go-previous"
                onClicked: sessionScreen.back()
            }
        }
    }
}
