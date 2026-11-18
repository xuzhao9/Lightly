/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

QQC2.ToolButton {
    id: actionButton

    property int iconSize: Kirigami.Units.gridUnit * 3

    implicitWidth: Math.max(iconSize + Kirigami.Units.gridUnit * 2, label.implicitWidth + 16)
    implicitHeight: iconSize + Kirigami.Units.smallSpacing + label.implicitHeight + 12
    padding: 0
    opacity: !enabled ? 0.4 : activeFocus || hovered ? 1 : 0.85
    Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad } }

    background: Item { }

    contentItem: Item {
        Rectangle {
            id: iconCircle
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: actionButton.iconSize + Kirigami.Units.smallSpacing
            height: width
            radius: width / 2
            color: "#ffffff"
            opacity: actionButton.hovered || actionButton.activeFocus ? 0.18 : 0
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad } }
        }

        Rectangle {
            anchors.centerIn: iconCircle
            width: iconCircle.width
            height: width
            radius: width / 2
            color: "#ffffff"
            opacity: 0.2
            scale: actionButton.down ? 1 : 0
            Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.InOutQuart } }
        }

        Kirigami.Icon {
            anchors.centerIn: iconCircle
            width: actionButton.iconSize
            height: width
            source: actionButton.icon.name
            isMask: true
            color: "white"
            active: actionButton.hovered || actionButton.activeFocus
        }

        Text {
            id: label
            anchors.top: iconCircle.bottom
            anchors.topMargin: Kirigami.Units.smallSpacing
            anchors.left: parent.left
            anchors.right: parent.right
            text: actionButton.text
            color: "white"
            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
            font.underline: actionButton.activeFocus
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            style: GraphicsInfo.api === GraphicsInfo.Software ? Text.Outline : Text.Normal
            styleColor: "#101526"
        }
    }
}
