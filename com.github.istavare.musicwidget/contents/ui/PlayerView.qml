import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid

Rectangle {
    id: card
    required property var media
    // Supplied by main.qml, where the owning PlasmoidItem is in scope.
    property var togglePopup: null
    implicitWidth: 360
    implicitHeight: 42
    height: Math.min(implicitHeight, parent ? parent.height : implicitHeight)
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    Layout.minimumWidth: 280
    Layout.preferredWidth: implicitWidth
    Layout.maximumWidth: 460
    Layout.minimumHeight: 42
    Layout.preferredHeight: implicitHeight
    Layout.alignment: Qt.AlignVCenter
    radius: 12
    color: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.55)
    border.width: 1
    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10)

    Item {
        anchors.fill: parent

        // The compact representation is not a Button, so request the popup
        // directly when the artwork or track details are clicked.  The
        // transport buttons remain above this area and keep their own clicks.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (card.togglePopup) card.togglePopup()
            }
        }

        Item {
            id: artContainer
            property string readyUrl: ""
            property real readyWidth: 0
            property real readyHeight: 0
            width: Math.min(34, card.height - 6)
            height: width
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter

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
                objectName: "albumArt"
                anchors.fill: parent
                source: card.media.artwork
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
                    const radius = 8
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
                anchors.margins: 5
                source: "audio-x-generic"
                visible: artContainer.readyUrl.length === 0
            }
        }

        Column {
            id: trackDetails
            anchors.left: artContainer.right
            anchors.leftMargin: 7
            anchors.right: transport.left
            anchors.rightMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            PlasmaComponents.Label {
                objectName: "trackTitle"
                width: parent.width
                text: card.media.title
                textFormat: Text.PlainText
                elide: Text.ElideRight
                maximumLineCount: 1
                height: 17
                verticalAlignment: Text.AlignVCenter
                font.weight: Font.DemiBold
            }
            PlasmaComponents.Label {
                objectName: "trackArtist"
                width: parent.width
                text: card.media.artist
                textFormat: Text.PlainText
                visible: text.length > 0 && card.height >= 36
                elide: Text.ElideRight
                maximumLineCount: 1
                height: 15
                verticalAlignment: Text.AlignVCenter
                font: Kirigami.Theme.smallFont
                opacity: 0.72
            }
        }

        Row {
            id: transport
            anchors.right: parent.right
            anchors.rightMargin: 3
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            TransportButton {
                objectName: "previousButton"
                icon.name: "media-skip-backward"
                text: "Previous"
                enabled: card.media.canPrevious
                onClicked: card.media.previous()
            }
            TransportButton {
                objectName: "playPauseButton"
                icon.name: card.media.playing ? "media-playback-pause" : "media-playback-start"
                text: card.media.playing ? "Pause" : "Play"
                enabled: card.media.canToggle
                onClicked: card.media.toggle()
            }
            TransportButton {
                objectName: "nextButton"
                icon.name: "media-skip-forward"
                text: "Next"
                enabled: card.media.canNext
                onClicked: card.media.next()
            }
        }
    }

    component TransportButton: PlasmaComponents.ToolButton {
        width: 30
        height: 30
        display: Controls.AbstractButton.IconOnly
        icon.width: 18
        icon.height: 18
        Accessible.name: text
        Controls.ToolTip.text: text
        Controls.ToolTip.visible: hovered
        Controls.ToolTip.delay: 600
    }
}
