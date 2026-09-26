import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Rectangle {
    id: popup
    required property var media
    property real tintOpacity: 0.16

    implicitWidth: 360
    implicitHeight: 450
    Layout.minimumWidth: implicitWidth
    Layout.maximumWidth: implicitWidth
    Layout.preferredWidth: implicitWidth
    Layout.minimumHeight: implicitHeight
    Layout.maximumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight
    radius: 20
    opacity: 1
    color: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g,
                   Kirigami.Theme.backgroundColor.b, Math.max(0.04, Math.min(0.34, tintOpacity)))
    border.width: 1
    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                          Kirigami.Theme.textColor.b, 0.36)

    Rectangle {
        anchors.fill: parent
        radius: popup.radius
        gradient: Gradient {
            GradientStop { position: 0.00; color: "transparent" }
            GradientStop { position: 0.58; color: "transparent" }
            GradientStop { position: 0.74; color: "#99000000" }
            GradientStop { position: 1.00; color: "#AA000000" }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 12

        Item {
            id: artContainer
            property string readyUrl: ""
            property real readyWidth: 0
            property real readyHeight: 0
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(230, popup.width - 44)
            Layout.preferredHeight: width

            function syncCover() {
                if (cover.status === Image.Ready) {
                    readyWidth = cover.implicitWidth
                    readyHeight = cover.implicitHeight
                    readyUrl = cover.source.toString()
                } else if ((cover.status === Image.Null && !cover.source)
                           || cover.status === Image.Error) {
                    readyUrl = ""
                }
                // Keep the last rendered cover while the next one is loading.
            }

            Image {
                id: cover
                anchors.fill: parent
                source: popup.media.artwork
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
                onStatusChanged: artContainer.syncCover()
                onSourceChanged: Qt.callLater(artContainer.syncCover)
            }

            Canvas {
                id: roundedCover
                anchors.fill: parent
                property url imageUrl: artContainer.readyUrl
                visible: artContainer.readyUrl.length > 0
                renderTarget: Canvas.Image
                contextType: "2d"
                smooth: false

                onImageUrlChanged: {
                    if (imageUrl) {
                        loadImage(imageUrl)
                        if (isImageLoaded(imageUrl)) requestPaint()
                    } else {
                        requestPaint()
                    }
                }
                onImageLoaded: requestPaint()

                onPaint: {
                    const context = getContext("2d")
                    const radius = 18
                    if (!imageUrl) {
                        context.clearRect(0, 0, width, height)
                        return
                    }
                    if (!isImageLoaded(imageUrl) || artContainer.readyWidth <= 0
                            || artContainer.readyHeight <= 0) return
                    context.clearRect(0, 0, width, height)
                    context.save()
                    context.beginPath()
                    context.moveTo(radius, 0)
                    context.lineTo(width - radius, 0)
                    context.quadraticCurveTo(width, 0, width, radius)
                    context.lineTo(width, height - radius)
                    context.quadraticCurveTo(width, height, width - radius, height)
                    context.lineTo(radius, height)
                    context.quadraticCurveTo(0, height, 0, height - radius)
                    context.lineTo(0, radius)
                    context.quadraticCurveTo(0, 0, radius, 0)
                    context.closePath()
                    context.clip()
                    // Crop the center square instead of stretching rectangular art.
                    const sourceWidth = artContainer.readyWidth
                    const sourceHeight = artContainer.readyHeight
                    const cropSize = Math.min(sourceWidth, sourceHeight)
                    const cropX = (sourceWidth - cropSize) / 2
                    const cropY = (sourceHeight - cropSize) / 2
                    context.drawImage(imageUrl, cropX, cropY, cropSize, cropSize,
                                      0, 0, width, height)
                    context.restore()
                }
            }

            Kirigami.Icon {
                anchors.fill: parent
                anchors.margins: 46
                source: "audio-x-generic"
                visible: artContainer.readyUrl.length === 0
            }
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.topMargin: 3
            text: popup.media.title
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.weight: Font.DemiBold
            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 2
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: popup.media.artist
            visible: text.length > 0
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            opacity: 0.72
            font: Kirigami.Theme.smallFont
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 3
            spacing: 8

            TransportButton {
                icon.name: "media-skip-backward"
                text: "Previous"
                enabled: popup.media.canPrevious
                onClicked: popup.media.previous()
            }
            TransportButton {
                icon.name: popup.media.playing ? "media-playback-pause" : "media-playback-start"
                text: popup.media.playing ? "Pause" : "Play"
                enabled: popup.media.canToggle
                onClicked: popup.media.toggle()
            }
            TransportButton {
                icon.name: "media-skip-forward"
                text: "Next"
                enabled: popup.media.canNext
                onClicked: popup.media.next()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PlasmaComponents.Label {
                text: popup.media.volumeAppLabel
                font: Kirigami.Theme.smallFont
                elide: Text.ElideRight
                Layout.maximumWidth: 100
            }
            Controls.Slider {
                id: appVolumeSlider
                Layout.fillWidth: true
                from: 0
                to: 100
                stepSize: 1
                Kirigami.StyleHints.tickMarkStepSize: -1
                enabled: popup.media.appVolumeAvailable
                value: popup.media.appVolumePercent
                onMoved: popup.media.setAppVolumePercent(value)
                // A single click on the track may not emit moved on all styles.
                onPressedChanged: {
                    if (!pressed && enabled) popup.media.setAppVolumePercent(value)
                }
                Accessible.name: "Application volume"
            }
            PlasmaComponents.Label {
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
                font: Kirigami.Theme.smallFont
                text: popup.media.appVolumeAvailable
                      ? Math.round(appVolumeSlider.pressed ? appVolumeSlider.value
                                                            : popup.media.appVolumePercent) + "%" : "—"
            }
        }
    }

    component TransportButton: PlasmaComponents.ToolButton {
        width: 42
        height: 42
        display: Controls.AbstractButton.IconOnly
        icon.width: 24
        icon.height: 24
        Accessible.name: text
        Controls.ToolTip.text: text
        Controls.ToolTip.visible: hovered
        Controls.ToolTip.delay: 600
    }
}
