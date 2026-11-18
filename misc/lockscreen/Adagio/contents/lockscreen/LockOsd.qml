/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: osd

    // These names are the interface KScreenLocker uses for its OSD.
    property int timeout: 1800
    property var osdValue
    property var osdMaxValue: 100
    property string osdAdditionalText: ""
    property string icon: ""
    property bool showingProgress: false

    objectName: "onScreenDisplay"
    visible: false
    width: osdContent.width + 32
    height: osdContent.height + 32

    function show() {
        visible = true;
        hideAnimation.restart();
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: "#bb1b2535"
        border.color: "#88ffffff"
        border.width: 1
    }

    ColumnLayout {
        id: osdContent
        anchors.centerIn: parent
        width: Math.min(Kirigami.Units.gridUnit * 11, Screen.height / 5)
        height: width
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: osdContent.width * 0.65
            Layout.fillHeight: true
            source: osd.icon
            isMask: true
            color: "white"
        }

        QQC2.ProgressBar {
            Layout.fillWidth: true
            visible: osd.showingProgress
            from: 0
            to: Number(osd.osdMaxValue) || 100
            value: Number(osd.osdValue) || 0
        }

        Text {
            Layout.fillWidth: true
            visible: !osd.showingProgress
            text: osd.osdValue === undefined || osd.osdValue === null ? "" : String(osd.osdValue)
            color: "white"
            font.pixelSize: Kirigami.Units.gridUnit * 1.5
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideLeft
            textFormat: Text.PlainText
        }

        Text {
            Layout.fillWidth: true
            visible: osd.showingProgress && osd.osdAdditionalText.length > 0
            text: osd.osdAdditionalText
            color: "white"
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }
    }

    SequentialAnimation {
        id: hideAnimation
        PauseAnimation { duration: 100 }
        NumberAnimation {
            target: osd
            property: "opacity"
            from: 1
            to: 0
            duration: 4000
            easing.type: Easing.InOutQuad
        }
        ScriptAction {
            script: {
                osd.visible = false;
                osd.opacity = 1;
                osd.icon = "";
                osd.osdValue = 0;
                osd.osdAdditionalText = "";
            }
        }
    }
}
