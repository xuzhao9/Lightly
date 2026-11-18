/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.VirtualKeyboard

Item {
    property bool activated: false

    InputPanel {
        width: parent.width
        y: parent.height - height
        active: parent.activated && Qt.inputMethod.visible
        visible: active
    }
}
