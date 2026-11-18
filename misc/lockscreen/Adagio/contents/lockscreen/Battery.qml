/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.private.battery as BatteryControl
import org.kde.plasma.workspace.components as PW

RowLayout {
    id: batteryIndicator
    spacing: 5
    visible: batteryModel.hasCumulative

    BatteryControl.BatteryControlModel {
        id: batteryModel
    }

    PW.BatteryIcon {
        Layout.preferredWidth: batteryLabel.implicitHeight
        Layout.preferredHeight: batteryLabel.implicitHeight
        hasBattery: batteryModel.hasBatteries
        percent: batteryModel.percent
        pluggedIn: batteryModel.pluggedIn
        preferSymbolic: true
    }

    Text {
        id: batteryLabel
        text: i18n("%1%", batteryModel.percent)
        color: "white"
        Accessible.name: i18n("Battery at %1%", batteryModel.percent)
    }
}
