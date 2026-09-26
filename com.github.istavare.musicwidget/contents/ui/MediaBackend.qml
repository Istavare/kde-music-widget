import QtQuick
import QtQml.Models
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.private.volume as PulseAudio

// Plasma 6's native model watches D-Bus and keeps metadata/capabilities live.
// The old "mpris2" DataEngine is not shipped by Plasma 6.
Item {
    id: backend

    property string preferredPlayer: "chromium"
    // Blank follows the preferred MPRIS player; set this when its audio stream
    // has a different application name (for example a standalone web app).
    property string volumeAppMatch: ""
    property var preferredContainer: null
    readonly property var player: preferredContainer || players.currentPlayer
    readonly property string rawTitle: player && player.track ? player.track : ""
    readonly property string rawArtist: player && player.artist ? player.artist : ""
    readonly property string rawArtwork: player && player.artUrl ? player.artUrl : ""
    // Browsers briefly clear MPRIS metadata between tracks. Keep the last
    // complete display state through that gap instead of flashing an empty
    // title and the fallback artwork icon.
    property string title: "Nothing playing"
    property string artist: ""
    property string artwork: ""
    property string pendingArtwork: ""
    property bool waitingForArtwork: false
    readonly property bool playing: !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property bool canControl: !!player && player.canControl
    readonly property bool canPrevious: canControl && player.canGoPrevious
    readonly property bool canNext: canControl && player.canGoNext
    // `currentPlayer` can briefly be null while a browser closes or restarts.
    readonly property bool canToggle: !!player && player.canControl
                                      && (playing ? player.canPause : player.canPlay)
    property int playerCount: 0
    property var volumeStream: null
    property string volumeAppLabel: "App volume"
    readonly property bool appVolumeAvailable: !!volumeStream
                                               && volumeStream.hasVolume
                                               && volumeStream.volumeWritable
    readonly property real appVolumePercent: appVolumeAvailable
                                             ? Math.round(volumeStream.volume * 100 / 65536) : 0

    function updatePresentation() {
        if (rawTitle) {
            if (rawTitle !== title) {
                // Chromium can publish its app icon as the first art URL for a
                // new track, then replace it with the actual cover. Hold the
                // previous cover until a second URL arrives or the grace
                // period expires.
                waitingForArtwork = true
                pendingArtwork = rawArtwork && rawArtwork !== artwork ? rawArtwork : ""
                artworkSettleTimer.restart()
            }
            title = rawTitle
            if (rawArtist) artist = rawArtist
            if (rawArtwork && rawArtwork !== artwork) {
                if (waitingForArtwork && pendingArtwork
                        && rawArtwork !== pendingArtwork) {
                    artwork = rawArtwork
                    pendingArtwork = ""
                    waitingForArtwork = false
                    artworkSettleTimer.stop()
                } else if (waitingForArtwork) {
                    pendingArtwork = rawArtwork
                } else {
                    waitingForArtwork = true
                    pendingArtwork = rawArtwork
                    artworkSettleTimer.restart()
                }
            }
            if (rawArtist && rawArtwork) metadataGapTimer.stop()
            else metadataGapTimer.restart()
        } else if (title !== "Nothing playing" || artist || artwork) {
            metadataGapTimer.restart()
        }
    }

    onRawTitleChanged: updatePresentation()
    onRawArtistChanged: updatePresentation()
    onRawArtworkChanged: updatePresentation()

    Timer {
        id: artworkSettleTimer
        interval: 2000
        repeat: false
        onTriggered: {
            backend.waitingForArtwork = false
            backend.pendingArtwork = ""
            if (backend.rawTitle) backend.artwork = backend.rawArtwork
        }
    }

    Timer {
        id: metadataGapTimer
        interval: 800
        repeat: false
        onTriggered: {
            backend.title = backend.rawTitle || "Nothing playing"
            backend.artist = backend.rawArtist
            if (!backend.rawTitle) {
                artworkSettleTimer.stop()
                backend.waitingForArtwork = false
                backend.pendingArtwork = ""
                backend.artwork = ""
            } else if (!backend.waitingForArtwork) {
                backend.artwork = backend.rawArtwork
            }
        }
    }

    function setAppVolumePercent(percent) {
        if (!appVolumeAvailable) return
        const value = Math.round(Math.max(0, Math.min(100, percent)) * 65536 / 100)
        if (volumeStream.volume !== value) volumeStream.volume = value
        if (value > 0 && volumeStream.muted) volumeStream.muted = false
    }

    function selectVolumeStream() {
        let best = null
        let bestScore = -1
        for (let i = 0; i < volumeCandidates.count; ++i) {
            const candidate = volumeCandidates.objectAt(i)
            if (!candidate || !candidate.stream) continue
            if (candidate.score > bestScore) {
                best = candidate
                bestScore = candidate.score
            }
        }
        volumeStream = bestScore > 0 ? best.stream : null
        volumeAppLabel = bestScore > 0 ? best.label : "App volume"
    }

    function previous() {
        if (canPrevious) player.Previous()
    }

    function next() {
        if (canNext) player.Next()
    }

    function toggle() {
        if (!canToggle) return
        if (playing) player.Pause()
        else player.Play()
    }

    function selectPreferred() {
        let best = null
        let bestScore = -1
        let count = 0
        for (let i = 0; i < candidates.count; ++i) {
            const candidate = candidates.objectAt(i)
            if (!candidate || candidate.isMultiplexer || !candidate.container) continue
            ++count
            if (candidate.score > bestScore) {
                best = candidate.container
                bestScore = candidate.score
            }
        }
        playerCount = count
        preferredContainer = best
    }

    onPreferredPlayerChanged: {
        Qt.callLater(selectPreferred)
        Qt.callLater(selectVolumeStream)
    }
    onVolumeAppMatchChanged: Qt.callLater(selectVolumeStream)
    onPlayerChanged: Qt.callLater(selectVolumeStream)

    Mpris.Mpris2Model {
        id: players
        onCurrentPlayerChanged: Qt.callLater(backend.selectPreferred)
    }

    PulseAudio.SinkInputModel {
        id: sinkInputs
    }

    Instantiator {
        id: volumeCandidates
        model: sinkInputs
        delegate: QtObject {
            required property var model
            readonly property var stream: model.PulseObject
            readonly property var streamProperties: model.Properties || ({})
            readonly property string label: streamProperties["application.name"]
                                            || streamProperties["application.id"] || "App volume"
            readonly property int score: {
                const selectedPlayer = backend.player
                const match = (backend.volumeAppMatch.trim()
                               || backend.preferredPlayer.trim()
                               || (selectedPlayer ? (selectedPlayer.identity
                                                     || selectedPlayer.desktopEntry || "") : "")).toLowerCase()
                if (!match) return -1
                const appId = String(streamProperties["pipewire.access.portal.app_id"] || "").toLowerCase()
                const desktopId = String(streamProperties["application.id"] || "").toLowerCase()
                const appName = String(streamProperties["application.name"] || "").toLowerCase()
                const binary = String(streamProperties["application.process.binary"] || "").toLowerCase()
                if (appId.includes(match) || desktopId.includes(match)) return 100
                if (appName.includes(match) || binary.includes(match)) return 50
                return -1
            }
            onScoreChanged: Qt.callLater(backend.selectVolumeStream)
        }
        onObjectAdded: Qt.callLater(backend.selectVolumeStream)
        onObjectRemoved: Qt.callLater(backend.selectVolumeStream)
    }

    Instantiator {
        id: candidates
        model: players
        delegate: QtObject {
            required property bool isMultiplexer
            required property var container
            // Prefer a matching browser, then playing over paused instances.
            // No match (or empty preference) follows KDE's automatic player.
            readonly property int score: {
                const preferred = backend.preferredPlayer.trim().toLowerCase()
                if (isMultiplexer || !container || !preferred) return -1
                const name = [container.objectName, container.identity, container.desktopEntry].join(" ").toLowerCase()
                if (name.indexOf(preferred) === -1) return -1
                return (container.playbackStatus === Mpris.PlaybackStatus.Playing ? 100 : 0)
                    + (container.track ? 10 : 0) + (container.canControl ? 1 : 0)
            }
            onScoreChanged: Qt.callLater(backend.selectPreferred)
        }
        onObjectAdded: Qt.callLater(backend.selectPreferred)
        onObjectRemoved: Qt.callLater(backend.selectPreferred)
    }

    Component.onCompleted: {
        updatePresentation()
        Qt.callLater(selectPreferred)
        Qt.callLater(selectVolumeStream)
    }
}
