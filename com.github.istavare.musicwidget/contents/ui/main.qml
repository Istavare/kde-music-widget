import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root
    property bool popupClosingFromWidget: false
    property double lastPopupDismissedAt: 0

    function toggleTransparentPopup() {
        if (popupDialog.visible) {
            popupClosingFromWidget = true
            popupDialog.visible = false
            popupClosingFromWidget = false
            return
        }
        // Focus loss may hide the dialog before the same panel click arrives.
        if (Date.now() - lastPopupDismissedAt < 400) return
        popupDialog.visible = true
    }

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: compactRepresentation
    preloadFullRepresentation: true
    toolTipMainText: backend.title
    toolTipSubText: [backend.artist, backend.player ? backend.player.identity : "No media player detected"].filter(Boolean).join("\n")
    toolTipTextFormat: Text.PlainText

    MediaBackend {
        id: backend
        preferredPlayer: Plasmoid.configuration.preferredPlayer
        volumeAppMatch: Plasmoid.configuration.volumeAppMatch
    }

    compactRepresentation: PlayerView {
        media: backend
        togglePopup: root.toggleTransparentPopup
    }

    // Plasma's applet-dialog role is anchored to visualParent on Wayland but
    // does not grab the panel click like a Qt.Popup window.
    PlasmaCore.Dialog {
        id: popupDialog
        visible: false
        visualParent: root.compactRepresentationItem
        location: Plasmoid.location
        type: PlasmaCore.Dialog.AppletPopup
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: true
        color: "transparent"
        onWindowDeactivated: {
            if (!root.popupClosingFromWidget) root.lastPopupDismissedAt = Date.now()
        }
        // Keep the anchored dialog flush with the panel, but leave an
        // invisible strip below the visible card so it never touches it.
        mainItem: Item {
            property int panelGap: 14
            width: root.compactRepresentationItem
                   ? Math.round(root.compactRepresentationItem.width) : 360
            height: 450 + panelGap
            Layout.minimumWidth: width
            Layout.maximumWidth: width
            Layout.preferredWidth: width
            Layout.minimumHeight: height
            Layout.maximumHeight: height
            Layout.preferredHeight: height
            ExpandedPlayer {
                anchors.top: parent.top
                width: parent.width
                height: 450
                media: backend
                tintOpacity: Plasmoid.configuration.popupTintOpacity
            }
        }
    }

    fullRepresentation: ExpandedPlayer {
        media: backend
        tintOpacity: Plasmoid.configuration.popupTintOpacity
    }
}
