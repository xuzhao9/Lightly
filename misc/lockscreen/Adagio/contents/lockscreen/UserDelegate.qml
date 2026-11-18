/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

QQC2.ToolButton {
    id: userButton

    property string displayName: ""
    property string avatarPath: ""
    property string iconSource: "user-identity"
    property int vtNumber: -1
    property bool isCurrent: false

    implicitWidth: Kirigami.Units.gridUnit * 8
    implicitHeight: Kirigami.Units.gridUnit * 9
    opacity: isCurrent ? 1 : 0.5
    scale: isCurrent ? 1 : 0.88
    Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
    Behavior on scale { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutQuad } }

    Accessible.name: displayName
    background: Item { }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        AdagioUserAvatar {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.gridUnit * 6
            Layout.preferredHeight: Layout.preferredWidth
            userImage: userButton.avatarPath
            iconSource: userButton.iconSource
            revealed: true
        }

        Text {
            Layout.fillWidth: true
            text: userButton.displayName
            color: "white"
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.underline: userButton.activeFocus
        }
    }
}
