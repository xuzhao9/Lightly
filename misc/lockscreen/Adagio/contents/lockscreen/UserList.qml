/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami

ListView {
    id: userList

    readonly property int selectedVtNumber: currentItem ? currentItem.vtNumber : -1

    orientation: ListView.Horizontal
    highlightRangeMode: ListView.StrictlyEnforceRange
    preferredHighlightBegin: width / 2 - Kirigami.Units.gridUnit * 4
    preferredHighlightEnd: preferredHighlightBegin
    clip: true
    focus: true

    delegate: UserDelegate {
        width: Kirigami.Units.gridUnit * 8
        height: userList.height
        displayName: model.realName || model.name || i18n("New Session")
        avatarPath: model.icon || ""
        iconSource: model.iconName || "user-identity"
        vtNumber: model.vtNumber
        isCurrent: ListView.isCurrentItem
        onClicked: userList.currentIndex = index
    }
}
