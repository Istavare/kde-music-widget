# Music Widget for KDE Plasma

A translucent now-playing widget for a KDE Plasma 6 panel. It shows album art, track details, and playback controls for MPRIS-compatible players, including YouTube Music in Chromium-based browsers. The expanded player has a per-application volume slider and a lightly tinted, rounded card.

## Disclaimer 

- This music now-playing widget primarily uses AI generated code but I have personally tested the widget 

## Requirements

- KDE Plasma 6
- A music player that exposes an MPRIS media session
- PipeWire or PulseAudio for the per-application volume slider

There is no compilation step: the plasmoid is made of QML files.

## Install

From the repository root, run:

```sh
kpackagetool6 --type Plasma/Applet --install ./com.github.istavare.musicwidget
```

Then right-click the panel, choose **Add Widgets**, and add **Music Widget**. To install a newer version over an existing one, use:

```sh
kpackagetool6 --type Plasma/Applet --upgrade ./com.github.istavare.musicwidget
```

If the panel still shows an older version, reload Plasma without tying it to the terminal:

```sh
nohup plasmashell --replace >/tmp/plasmashell.log 2>&1 &
```

This package has a new ID, so installing it does not replace a widget installed under an older ID. Remove the older widget from the panel and add this one when you are ready to switch.

## Use and settings

Play a track, then click the widget in the panel to open or close the expanded player. Click elsewhere to dismiss it. The popup has a small gap above the panel; album art is center-cropped without smoothing pixel art.

When a browser briefly clears track metadata during a skip, the widget holds the previous title and cover for up to 800 ms instead of flashing an empty state. It also keeps the previous cover visible while the next image loads. If the browser supplies its app logo before the real cover, the first new artwork URL is held provisionally; a replacement appears immediately, or the single supplied image appears after two seconds.

The volume slider adjusts the matching application's audio stream, not the system master volume or the music website's own volume. It is disabled when no matching stream is active. By default it follows the preferred player name; set **Volume app match** in the widget settings if the application's mixer name or ID differs. **Popup tint** adjusts the card's transparency.

If playback is not detected, check that your player appears as an MPRIS service:

```sh
busctl --user list | grep org.mpris.MediaPlayer2
```

## Build a distributable package

The source directory can be installed directly. To create a `.plasmoid` archive for a release, run:

```sh
(cd com.github.istavare.musicwidget && zip -qr ../Music-Widget.plasmoid .)
```
