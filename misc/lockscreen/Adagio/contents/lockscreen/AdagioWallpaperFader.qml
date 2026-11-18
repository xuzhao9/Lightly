/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: fader

    required property Item sourceItem
    property bool revealed: false

    FastBlur {
        id: wallpaperBlur
        anchors.fill: parent
        source: fader.sourceItem
        radius: 0
        state: fader.revealed ? "revealed" : "idle"

        states: [
            State { name: "idle" },
            State {
                name: "revealed"
                PropertyChanges { target: wallpaperBlur; radius: 80 }
            }
        ]

        transitions: [
            Transition {
                from: "idle"
                to: "revealed"
                NumberAnimation { target: wallpaperBlur; property: "radius"; duration: 500 }
            },
            Transition {
                from: "revealed"
                to: "idle"
                SequentialAnimation {
                    PauseAnimation { duration: 400 }
                    NumberAnimation { target: wallpaperBlur; property: "radius"; duration: 500 }
                }
            }
        ]
    }

    Rectangle {
        anchors.fill: parent
        color: "#101526"
        opacity: fader.revealed ? 0.55 : 0.24
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
    }
}
