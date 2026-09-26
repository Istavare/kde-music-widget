import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page
    property alias cfg_preferredPlayer: playerField.text
    property alias cfg_volumeAppMatch: volumeAppField.text
    property alias cfg_popupTintOpacity: tintSlider.value

    Kirigami.FormLayout {
        Controls.TextField {
            id: playerField
            Kirigami.FormData.label: "Preferred player:"
            placeholderText: "Automatic"
        }
        Controls.Label {
            Layout.fillWidth: true
            text: "Use part of a player name, such as chromium. Leave blank to follow KDE’s active player."
            wrapMode: Text.WordWrap
        }
        Controls.TextField {
            id: volumeAppField
            Kirigami.FormData.label: "Volume app match:"
            placeholderText: "Follow preferred player"
        }
        Controls.Label {
            Layout.fillWidth: true
            text: "Match part of the app name or ID shown in KDE's volume mixer. Leave blank to use the preferred player name."
            wrapMode: Text.WordWrap
        }
        Controls.Slider {
            id: tintSlider
            Kirigami.FormData.label: "Popup tint:"
            from: 0.04
            to: 0.34
            stepSize: 0.02
        }
        Controls.Label {
            Layout.fillWidth: true
            text: Math.round(tintSlider.value * 100) + "% opaque. Lower values show more of the desktop behind the player."
            wrapMode: Text.WordWrap
        }
    }
}
