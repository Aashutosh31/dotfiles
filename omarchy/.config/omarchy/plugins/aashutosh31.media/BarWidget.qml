import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Media Deck — a now-playing pill for the Omarchy bar, backed by MPRIS.
BarWidget {
  id: root
  moduleName: "aashutosh31.media"

  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var activePlayer: choosePlayer(players)
  readonly property bool hasMedia: !!activePlayer && (!!activePlayer.trackTitle || !!activePlayer.trackArtist)
  readonly property string artworkUrl: safeArtworkUrl(activePlayer ? activePlayer.trackArtUrl : "")
  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color barForeground: bar ? bar.barForeground : Commons.Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  property bool popupOpen: false
  property real liveSeconds: activePlayer ? seconds(activePlayer.position) : 0
  property real anchorSeconds: 0
  property real anchorMillis: 0
  property real lastObservedSeconds: -1
  property string timelineTrack: ""
  property double seekGraceUntil: 0
  property real rememberedVolume: 0.5

  readonly property bool opened: popupOpen

  function open() {
    popupOpen = true
  }

  function close() {
    popupOpen = false
  }

  function toggle() {
    popupOpen = !popupOpen
  }

  function choosePlayer(list) {
    // Prefer a playing source with a real timeline. Firefox's MPRIS bridge can
    // say Playing while reporting position 0 and no duration; Chrome exposes
    // the actual YouTube Music timeline, so it must win when both are open.
    for (var i = 0; i < list.length; i++)
      if (list[i] && list[i].isPlaying && list[i].lengthSupported && list[i].positionSupported && list[i].canSeek)
        return list[i]
    for (var j = 0; j < list.length; j++)
      if (list[j] && list[j].isPlaying) return list[j]
    for (var k = 0; k < list.length; k++)
      if (list[k] && (list[k].trackTitle || list[k].trackArtist)) return list[k]
    return null
  }

  function playerLabel(player) {
    return player ? displayMetadata(player.identity || player.desktopEntry || "Player", 80) : "Player"
  }

  function displayMetadata(value, maxLength) {
    var text = String(value || "")
    if (text.length <= maxLength) return text
    return text.slice(0, maxLength - 1) + "…"
  }

  function safeArtworkUrl(value) {
    var url = String(value || "")
    if (url.length > 4096) return ""

    // MPRIS artwork is untrusted input. Only load local files with raster
    // extensions. Never pass remote, data, SVG, or other schemes to Qt Quick.
    if (/^file:\/\/\/(?!\/).+\.(?:png|jpe?g|gif|webp|bmp|avif)$/i.test(url))
      return url
    return ""
  }

  function playPause() {
    if (!root.activePlayer) return
    if (root.activePlayer.isPlaying && root.activePlayer.canPause) root.activePlayer.pause()
    else if (!root.activePlayer.isPlaying && root.activePlayer.canPlay) root.activePlayer.play()
    else if (root.activePlayer.canTogglePlaying) root.activePlayer.togglePlaying()
  }

  function toggleMute() {
    if (!activePlayer || !activePlayer.volumeSupported) return
    if (activePlayer.volume > 0) {
      rememberedVolume = activePlayer.volume
      activePlayer.volume = 0
    } else {
      activePlayer.volume = Math.max(0.05, rememberedVolume)
    }
  }

  function cycleRepeat() {
    if (!activePlayer || !activePlayer.loopSupported) return
    if (activePlayer.loopState === MprisLoopState.None)
      activePlayer.loopState = MprisLoopState.Playlist
    else if (activePlayer.loopState === MprisLoopState.Playlist)
      activePlayer.loopState = MprisLoopState.Track
    else
      activePlayer.loopState = MprisLoopState.None
  }

  function seconds(value) {
    return Number(value) || 0
  }

  function timeLabel(value) {
    var total = Math.max(0, Math.floor(seconds(value)))
    var minutes = Math.floor(total / 60)
    var secs = total % 60
    return minutes + ":" + (secs < 10 ? "0" : "") + secs
  }

  readonly property real progress: activePlayer && activePlayer.lengthSupported && seconds(activePlayer.length) > 0
    ? Math.max(0, Math.min(1, liveSeconds / seconds(activePlayer.length))) : 0

  function seekAt(ratio) {
    if (!activePlayer || !activePlayer.canSeek || !activePlayer.lengthSupported) return
    var length = Number(activePlayer.length) || 0
    var target = Math.max(0, Math.min(1, ratio)) * seconds(length)
    activePlayer.seek(target - root.liveSeconds)
    root.liveSeconds = target
    root.anchorSeconds = target
    root.anchorMillis = Date.now()
    root.lastObservedSeconds = target
    root.seekGraceUntil = Date.now() + 1500
  }

  Timer {
    interval: 500
    running: root.popupOpen && root.hasMedia
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshTimeline()
  }

  function refreshTimeline() {
    if (!activePlayer) return
    var now = Date.now()
    if (now < seekGraceUntil) return
    activePlayer.positionChanged()
    var reported = seconds(activePlayer.position)
    var track = displayMetadata(activePlayer.trackTitle, 256)
      + "\u0000" + displayMetadata(activePlayer.trackArtist, 256)
    var newTrack = track !== timelineTrack
    var jumped = lastObservedSeconds >= 0 && Math.abs(reported - lastObservedSeconds) > 1.5

    if (newTrack || anchorMillis === 0 || jumped) {
      timelineTrack = track
      liveSeconds = reported
      anchorSeconds = reported
      anchorMillis = now
    } else if (activePlayer.isPlaying) {
      liveSeconds = anchorSeconds + Math.max(0, now - anchorMillis) / 1000
    } else {
      liveSeconds = reported
      anchorSeconds = reported
      anchorMillis = now
    }
    lastObservedSeconds = reported
  }

  visible: hasMedia
  implicitWidth: hasMedia ? Style.space(230) : 0
  implicitHeight: barSize

  Row {
    anchors.centerIn: parent
    spacing: Style.space(7)

    BorderSurface {
      width: Style.space(26)
      height: Style.space(26)
      radius: Style.spacing.labelGap
      anchors.verticalCenter: parent.verticalCenter
      color: Style.normalFillFor(root.barForeground, Commons.Color.accent)

      SizedImage {
        anchors.fill: parent
        anchors.margins: Style.space(1)
        crop: true
        url: root.artworkUrl
        visible: url !== ""
      }

      Text {
        anchors.centerIn: parent
        visible: root.artworkUrl === ""
        text: "󰝚"
        color: root.barForeground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
    }

    Text {
      text: root.activePlayer && root.activePlayer.isPlaying ? "󰏤" : "󰐊"
      color: root.activePlayer && root.activePlayer.isPlaying ? Commons.Color.accent : root.barForeground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      text: root.activePlayer
        ? displayMetadata(root.activePlayer.trackTitle || "Now playing", 256)
          + (root.activePlayer.trackArtist ? "  ·  " + displayMetadata(root.activePlayer.trackArtist, 256) : "")
        : ""
      textFormat: Text.PlainText
      color: root.barForeground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
      width: Style.space(155)
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.activePlayer ? Qt.PointingHandCursor : Qt.ArrowCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    onEntered: if (root.bar && root.activePlayer) {
      var title = root.displayMetadata(root.activePlayer.trackTitle || "Now playing", 256)
      var artist = root.displayMetadata(root.activePlayer.trackArtist, 256)
      root.bar.showTooltip(root, title + (artist ? " — " + artist : "") + "  ·  " + root.playerLabel(root.activePlayer))
    }
    onExited: if (root.bar) root.bar.hideTooltip(root)
    onClicked: function(mouse) {
      if (!root.activePlayer) return
      if (mouse.button === Qt.MiddleButton && root.activePlayer.canGoNext) root.activePlayer.next()
      else if (mouse.button === Qt.RightButton) root.playPause()
      else root.popupOpen = !root.popupOpen
    }
    onWheel: function(wheel) {
      if (!root.activePlayer || !root.activePlayer.volumeSupported) return
      var step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
      root.activePlayer.volume = Math.max(0, Math.min(1, root.activePlayer.volume + step))
      if (root.activePlayer.volume > 0) root.rememberedVolume = root.activePlayer.volume
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(390))
    contentHeight: popup.fittedContentHeight(deck.implicitHeight)

    Column {
      id: deck
      anchors.fill: parent
      spacing: Style.space(12)

      Row {
        width: parent.width
        spacing: Style.space(12)

        BorderSurface {
          width: Style.space(78)
          height: Style.space(78)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.foreground, Commons.Color.accent)
          borderSpec: Border.controlSpec("normal", root.foreground, Commons.Color.accent)

          SizedImage {
            anchors.fill: parent
            anchors.margins: Style.space(2)
            crop: true
            url: root.artworkUrl
            visible: url !== ""
          }

          Text {
            anchors.centerIn: parent
            visible: root.artworkUrl === ""
            text: "󰝚"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.displayLarge
          }
        }

        Column {
          width: parent.width - Style.space(90)
          spacing: Style.space(4)
          anchors.verticalCenter: parent.verticalCenter

          Text { text: root.activePlayer ? root.displayMetadata(root.activePlayer.trackTitle || "Nothing playing", 256) : "Nothing playing"; textFormat: Text.PlainText; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.subtitle; font.bold: true; elide: Text.ElideRight; width: parent.width }
          Text { text: root.activePlayer ? root.displayMetadata(root.activePlayer.trackArtist, 256) : ""; textFormat: Text.PlainText; color: Qt.darker(root.foreground, 1.3); font.family: root.fontFamily; font.pixelSize: Style.font.body; elide: Text.ElideRight; width: parent.width; visible: text !== "" }
          Text { text: root.activePlayer ? root.displayMetadata(root.activePlayer.trackAlbum, 256) : ""; textFormat: Text.PlainText; color: Qt.darker(root.foreground, 1.6); font.family: Style.font.caption; elide: Text.ElideRight; width: parent.width; visible: text !== "" }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)

        Button { iconText: "󰒮"; foreground: root.foreground; enabled: root.activePlayer && root.activePlayer.canGoPrevious; onClicked: root.activePlayer.previous() }
        Button { iconText: root.activePlayer && root.activePlayer.isPlaying ? "󰏤" : "󰐊"; foreground: root.foreground; iconSize: Style.font.iconLarge; onClicked: root.playPause() }
        Button { iconText: "󰒭"; foreground: root.foreground; enabled: root.activePlayer && root.activePlayer.canGoNext; onClicked: root.activePlayer.next() }
        Button { iconText: "󰒝"; foreground: root.foreground; enabled: root.activePlayer && root.activePlayer.shuffleSupported; onClicked: root.activePlayer.shuffle = !root.activePlayer.shuffle }
      }

      Column {
        width: parent.width
        spacing: Style.space(4)

        PanelSlider {
          id: progressSlider
          bar: root.bar
          width: parent.width
          minimum: 0
          maximum: 1
          step: 0.001
          value: root.progress
          enabled: root.activePlayer && root.activePlayer.canSeek && root.activePlayer.lengthSupported
          trackColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
          fillColor: Commons.Color.accent
          knobColor: root.foreground
          onReleased: function(value) {
            root.seekAt(value)
          }
        }

        Row {
          width: parent.width
          Text { id: elapsed; text: root.activePlayer ? root.timeLabel(root.liveSeconds) : "0:00"; color: Qt.darker(root.foreground, 1.4); font.family: root.fontFamily; font.pixelSize: Style.font.caption }
          Item { width: parent.width - elapsed.width - total.width; height: 1 }
          Text { id: total; text: root.activePlayer ? root.timeLabel(root.activePlayer.length) : "0:00"; color: Qt.darker(root.foreground, 1.4); font.family: root.fontFamily; font.pixelSize: Style.font.caption }
        }
      }

      PanelSeparator { foreground: root.foreground; visible: root.players.length > 1 }

      Repeater {
        model: root.players
        delegate: Button {
          required property var modelData
          width: parent.width
          text: root.playerLabel(modelData) + (modelData === root.activePlayer ? "  • ACTIVE" : "")
          foreground: root.foreground
          visible: modelData.trackTitle || modelData.trackArtist
          onClicked: { if (modelData.canPlay) modelData.play(); root.popupOpen = false }
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(6)
        visible: root.activePlayer && root.activePlayer.volumeSupported

        Button {
          iconText: root.activePlayer && root.activePlayer.volume === 0 ? "󰖁" : "󰕾"
          foreground: root.foreground
          tooltipText: root.activePlayer && root.activePlayer.volume === 0 ? "Unmute player" : "Mute player"
          onClicked: root.toggleMute()
        }

        PanelSlider {
          width: parent.width - Style.space(62)
          minimum: 0
          maximum: 1
          step: 0.01
          value: root.activePlayer ? root.activePlayer.volume : 0
          enabled: root.activePlayer && root.activePlayer.volumeSupported
          trackColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
          fillColor: Commons.Color.accent
          knobColor: root.foreground
          onReleased: function(value) {
            if (root.activePlayer && root.activePlayer.volumeSupported) {
              root.activePlayer.volume = value
              if (value > 0) root.rememberedVolume = value
            }
          }
        }

        Text {
          width: Style.space(30)
          text: root.activePlayer ? Math.round(root.activePlayer.volume * 100) + "%" : ""
          color: Qt.darker(root.foreground, 1.4)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          anchors.verticalCenter: parent.verticalCenter
          horizontalAlignment: Text.AlignRight
        }
      }

      Button {
        visible: root.activePlayer && root.activePlayer.loopSupported
        iconText: root.activePlayer && root.activePlayer.loopState === MprisLoopState.Track ? "󰑘" : "󰑖"
        active: root.activePlayer && root.activePlayer.loopState !== MprisLoopState.None
        foreground: root.foreground
        tooltipText: !root.activePlayer || root.activePlayer.loopState === MprisLoopState.None
          ? "Repeat off" : (root.activePlayer.loopState === MprisLoopState.Track ? "Repeat track" : "Repeat playlist")
        onClicked: root.cycleRepeat()
      }

      Text { text: "Click the media pill to close"; color: Qt.darker(root.foreground, 1.6); font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.horizontalCenter: parent.horizontalCenter }
    }
  }
}
