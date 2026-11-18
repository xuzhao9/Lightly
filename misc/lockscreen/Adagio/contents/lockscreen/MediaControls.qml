/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

Item {
    id: mediaControl

    property bool promptVisible: false
    signal controlUsed()

    implicitWidth: Kirigami.Units.gridUnit * 16
    implicitHeight: Kirigami.Units.gridUnit * 3
    visible: players.count > 0 && (promptVisible || opacity > 0)
    opacity: 0
    state: promptVisible ? "shown" : "hidden"
    transform: Translate { id: mediaSlide; y: -40 }

    component MediaButton: QQC2.ToolButton {
        id: button
        Layout.preferredWidth: Kirigami.Units.gridUnit * 2
        Layout.preferredHeight: Layout.preferredWidth
        focusPolicy: Qt.TabFocus
        background: Rectangle {
            radius: width / 2
            color: button.down ? "#55ffffff" : button.hovered || button.activeFocus ? "#33ffffff" : "transparent"
        }
        contentItem: Kirigami.Icon {
            source: button.icon.name
            isMask: true
            color: button.enabled ? "white" : "#88ffffff"
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: "#661b2535"
    }

    Repeater {
        id: players
        model: Mpris.MultiplexerModel { }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing / 2
            enabled: model.canControl

            Image {
                Layout.preferredWidth: height
                Layout.fillHeight: true
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                source: model.artUrl
                visible: status === Image.Loading || status === Image.Ready
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: model.track.length > 0 ? model.track
                          : model.playbackStatus > Mpris.PlaybackStatus.Stopped
                            ? i18n("No title") : i18n("No media playing")
                    color: "white"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap
                    textFormat: Text.PlainText
                }

                Text {
                    Layout.fillWidth: true
                    text: model.artist || model.identity
                    color: "#ddffffff"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize + 1
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap
                    textFormat: Text.PlainText
                }
            }

            MediaButton {
                visible: model.canGoBack || model.canGoNext
                enabled: model.canGoPrevious
                icon.name: LayoutMirroring.enabled ? "media-skip-forward" : "media-skip-backward"
                Accessible.name: i18n("Previous track")
                onClicked: {
                    mediaControl.controlUsed();
                    model.container.Previous();
                }
            }

            MediaButton {
                icon.name: model.playbackStatus === Mpris.PlaybackStatus.Playing
                           ? "media-playback-pause" : "media-playback-start"
                Accessible.name: i18n("Play or Pause media")
                onClicked: {
                    mediaControl.controlUsed();
                    model.container.PlayPause();
                }
            }

            MediaButton {
                visible: model.canGoBack || model.canGoNext
                enabled: model.canGoNext
                icon.name: LayoutMirroring.enabled ? "media-skip-backward" : "media-skip-forward"
                Accessible.name: i18n("Next track")
                onClicked: {
                    mediaControl.controlUsed();
                    model.container.Next();
                }
            }
        }
    }

    states: [
        State { name: "hidden" },
        State {
            name: "shown"
            PropertyChanges { target: mediaControl; opacity: 1 }
            PropertyChanges { target: mediaSlide; y: 0 }
        }
    ]

    transitions: [
        Transition {
            from: "hidden"
            to: "shown"
            SequentialAnimation {
                PauseAnimation { duration: 450 }
                ParallelAnimation {
                    NumberAnimation { target: mediaControl; property: "opacity"; from: 0; to: 1; duration: 500; easing.type: Easing.OutQuart }
                    NumberAnimation { target: mediaSlide; property: "y"; from: 40; to: 0; duration: 500; easing.type: Easing.OutQuart }
                }
            }
        },
        Transition {
            from: "shown"
            to: "hidden"
            SequentialAnimation {
                PauseAnimation { duration: 450 }
                ParallelAnimation {
                    NumberAnimation { target: mediaControl; property: "opacity"; from: 1; to: 0; duration: 500; easing.type: Easing.OutQuart }
                    NumberAnimation { target: mediaSlide; property: "y"; from: 0; to: -40; duration: 500; easing.type: Easing.OutQuart }
                }
            }
        }
    ]
}
