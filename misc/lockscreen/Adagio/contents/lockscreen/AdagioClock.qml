/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import org.kde.plasma.components as PlasmaComponents

Item {
    id: clock

    required property date currentTime
    property bool promptVisible: false

    implicitWidth: clockColumn.implicitWidth
    implicitHeight: clockColumn.implicitHeight
    visible: opacity > 0
    state: promptVisible ? "hidden" : "shown"

    transform: Translate { id: clockSlide; y: 0 }

    Column {
        id: clockColumn
        spacing: 4

        PlasmaComponents.Label {
            text: Qt.formatTime(clock.currentTime, Qt.locale().timeFormat(Locale.ShortFormat))
            font.pixelSize: 64
            font.weight: Font.Light
            color: "white"
            style: Text.Raised
            styleColor: "#55000000"
        }

        PlasmaComponents.Label {
            text: Qt.formatDate(clock.currentTime, Qt.locale().dateFormat(Locale.LongFormat))
            font.pixelSize: 22
            font.weight: Font.Light
            color: "white"
            style: Text.Raised
            styleColor: "#55000000"
        }
    }

    states: [
        State {
            name: "shown"
            PropertyChanges { target: clock; opacity: 1 }
            PropertyChanges { target: clockSlide; y: 0 }
        },
        State {
            name: "hidden"
            PropertyChanges { target: clock; opacity: 0 }
            PropertyChanges { target: clockSlide; y: 10 }
        }
    ]

    transitions: [
        Transition {
            from: "shown"
            to: "hidden"
            ParallelAnimation {
                NumberAnimation { target: clock; property: "opacity"; duration: 500; easing.type: Easing.OutQuart }
                NumberAnimation { target: clockSlide; property: "y"; duration: 500; easing.type: Easing.OutQuart }
            }
        },
        Transition {
            from: "hidden"
            to: "shown"
            SequentialAnimation {
                PauseAnimation { duration: 400 }
                ParallelAnimation {
                    NumberAnimation { target: clock; property: "opacity"; duration: 500; easing.type: Easing.OutQuart }
                    NumberAnimation { target: clockSlide; property: "y"; duration: 500; easing.type: Easing.OutQuart }
                }
            }
        }
    ]

    ParallelAnimation {
        id: launchAnimation
        NumberAnimation { target: clock; property: "opacity"; from: 0; to: 1; duration: 1000; easing.type: Easing.OutQuart }
        NumberAnimation { target: clockSlide; property: "y"; from: 40; to: 0; duration: 1000; easing.type: Easing.OutQuart }
    }

    Component.onCompleted: {
        if (!promptVisible) {
            launchAnimation.start();
        }
    }
}
