import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Personal media deck. The MPRIS service is standard, but the presentation,
// size and interaction belong to this setup: one click opens the card.
BarWidget {
  id: root
  moduleName: "aashutosh31.media"

  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var activePlayer: choosePlayer(players)
  readonly property bool hasMedia: !!activePlayer && (!!activePlayer.trackTitle || !!activePlayer.trackArtist)
  property bool popupOpen: false
  property real liveSeconds: activePlayer ? seconds(activePlayer.position) : 0
  property real anchorSeconds: 0
  property real anchorMillis: 0
  property real lastObservedSeconds: -1
  property string timelineTrack: ""
  property bool seeking: false
  property double seekGraceUntil: 0

  function close() {
    popupOpen = false
  }

  function choosePlayer(list) {
    for (var i = 0; i < list.length; i++)
      if (list[i] && list[i].isPlaying) return list[i]
    for (var j = 0; j < list.length; j++)
      if (list[j] && (list[j].trackTitle || list[j].trackArtist)) return list[j]
    return null
  }

  function playerLabel(player) {
    return player ? (player.identity || player.desktopEntry || "Player") : "Player"
  }

  function playPause() {
    if (!root.activePlayer) return
    if (root.activePlayer.isPlaying && root.activePlayer.canPause) root.activePlayer.pause()
    else if (!root.activePlayer.isPlaying && root.activePlayer.canPlay) root.activePlayer.play()
    else if (root.activePlayer.canTogglePlaying) root.activePlayer.togglePlaying()
  }

  function seconds(value) {
    var n = Number(value) || 0
    return n > 100000 ? n / 1000000 : n
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
    if (!activePlayer || !activePlayer.positionSupported || !activePlayer.lengthSupported) return
    var length = Number(activePlayer.length) || 0
    var target = Math.max(0, Math.min(1, ratio)) * seconds(length)
    activePlayer.position = length > 100000 ? target * 1000000 : target
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
    if (seeking && now < seekGraceUntil) return
    var reported = seconds(activePlayer.position)
    var track = activePlayer.trackTitle + "\u0000" + activePlayer.trackArtist
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
    spacing: Style.space(8)

    Text {
      text: root.activePlayer && root.activePlayer.isPlaying ? "󰏤" : "󰐊"
      color: root.bar.barForeground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      text: root.activePlayer ? (root.activePlayer.trackTitle || "Now playing") : ""
      color: root.bar.barForeground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
      width: Style.space(170)
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    onClicked: function(mouse) {
      if (!root.activePlayer) return
      if (mouse.button === Qt.MiddleButton && root.activePlayer.canGoNext) root.activePlayer.next()
      else if (mouse.button === Qt.RightButton) root.playPause()
      else root.popupOpen = !root.popupOpen
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
          color: Style.normalFillFor(root.bar.foreground, Commons.Color.accent)
          borderSpec: Border.controlSpec("normal", root.bar.foreground, Commons.Color.accent)

          SizedImage {
            anchors.fill: parent
            anchors.margins: Style.space(2)
            crop: true
            url: root.activePlayer && root.activePlayer.trackArtUrl ? root.activePlayer.trackArtUrl : ""
            visible: url !== ""
          }

          Text {
            anchors.centerIn: parent
            visible: !root.activePlayer || !root.activePlayer.trackArtUrl
            text: "󰝚"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
          }
        }

        Column {
          width: parent.width - Style.space(90)
          spacing: Style.space(4)
          anchors.verticalCenter: parent.verticalCenter

          Text { text: root.activePlayer ? (root.activePlayer.trackTitle || "Nothing playing") : "Nothing playing"; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.subtitle; font.bold: true; elide: Text.ElideRight; width: parent.width }
          Text { text: root.activePlayer ? (root.activePlayer.trackArtist || "") : ""; color: Qt.darker(root.bar.foreground, 1.3); font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; elide: Text.ElideRight; width: parent.width; visible: text !== "" }
          Text { text: root.activePlayer ? (root.activePlayer.trackAlbum || "") : ""; color: Qt.darker(root.bar.foreground, 1.6); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight; width: parent.width; visible: text !== "" }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)

        Button { iconText: "󰒮"; foreground: root.bar.foreground; enabled: root.activePlayer && root.activePlayer.canGoPrevious; onClicked: root.activePlayer.previous() }
        Button { iconText: root.activePlayer && root.activePlayer.isPlaying ? "󰏤" : "󰐊"; foreground: root.bar.foreground; iconSize: Style.font.iconLarge; onClicked: root.playPause() }
        Button { iconText: "󰒭"; foreground: root.bar.foreground; enabled: root.activePlayer && root.activePlayer.canGoNext; onClicked: root.activePlayer.next() }
        Button { iconText: "󰒝"; foreground: root.bar.foreground; enabled: root.activePlayer && root.activePlayer.shuffleSupported; onClicked: root.activePlayer.shuffle = !root.activePlayer.shuffle }
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
          trackColor: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.18)
          fillColor: Commons.Color.accent
          knobColor: root.bar.foreground
          onMoved: function(value) {
            root.seeking = true
            root.seekAt(value)
          }
          onReleased: function(value) {
            root.seekAt(value)
            root.seeking = false
          }
        }

        Row {
          width: parent.width
          Text { id: elapsed; text: root.activePlayer ? root.timeLabel(root.liveSeconds) : "0:00"; color: Qt.darker(root.bar.foreground, 1.4); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption }
          Item { width: parent.width - elapsed.width - total.width; height: 1 }
          Text { id: total; text: root.activePlayer ? root.timeLabel(root.activePlayer.length) : "0:00"; color: Qt.darker(root.bar.foreground, 1.4); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption }
        }
      }

      PanelSeparator { foreground: root.bar.foreground; visible: root.players.length > 1 }

      Repeater {
        model: root.players
        delegate: Button {
          required property var modelData
          width: parent.width
          text: root.playerLabel(modelData) + (modelData === root.activePlayer ? "  • ACTIVE" : "")
          foreground: root.bar.foreground
          visible: modelData.trackTitle || modelData.trackArtist
          onClicked: { if (modelData.canPlay) modelData.play(); root.popupOpen = false }
        }
      }

      Text { text: "Click the media pill to close"; color: Qt.darker(root.bar.foreground, 1.6); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; anchors.horizontalCenter: parent.horizontalCenter }
    }
  }
}
