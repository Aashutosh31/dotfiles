import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Personal, on-demand telemetry HUD. It is deliberately a panel, not a bar
// widget: it never changes the bar layout or replaces any existing feature.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property int cpu: 0
  property int memory: 0
  property string network: "—"
  property string previousCpu: ""
  property real previousRx: -1
  property double previousTime: 0
  readonly property string fontFamily: Style.font.family

  function open(payloadJson) {
    root.opened = true
    sample()
  }

  function close() {
    root.opened = false
    if (stats.running) stats.running = false
  }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "aashutosh31.telemetry")
    else root.close()
  }

  function parseLine(line) {
    var text = String(line).trim()
    var f = text.split(/\s+/)
    if (f[0] === "CPU" && f.length > 1) {
      var now = Number(f[1])
      var idle = Number(f[5]) + Number(f[6])
      if (root.previousCpu !== "") {
        var p = root.previousCpu.split(/\s+/)
        var oldTotal = 0
        for (var i = 1; i < p.length; i++) oldTotal += Number(p[i])
        var oldIdle = Number(p[5]) + Number(p[6])
        var total = 0
        for (var j = 1; j < f.length; j++) total += Number(f[j])
        if (total > oldTotal) root.cpu = Math.max(0, Math.min(100, Math.round((1 - (idle - oldIdle) / (total - oldTotal)) * 100)))
      }
      root.previousCpu = text
    } else if (f[0] === "MEM") {
      var totalMem = Number(f[1]), available = Number(f[2])
      if (totalMem > 0) root.memory = Math.round((totalMem - available) * 100 / totalMem)
    } else if (f[0] === "NET") {
      var rx = Number(f[1]), nowNet = Date.now()
      if (root.previousRx >= 0) {
        var rate = Math.max(0, (rx - root.previousRx) / Math.max(1, (nowNet - root.previousTime) / 1000))
        root.network = rate < 1024 ? Math.round(rate) + " B/s" : (rate / 1024).toFixed(1) + " KB/s"
      }
      root.previousRx = rx
      root.previousTime = nowNet
    }
  }

  function sample() {
    if (!stats.running) stats.running = true
  }

  Timer {
    interval: 1000
    running: root.opened
    repeat: true
    triggeredOnStart: true
    onTriggered: root.sample()
  }

  Process {
    id: stats
    command: ["bash", "-c", "awk '/^cpu / {print \"CPU\", $2,$3,$4,$5,$6,$7,$8,$9} /^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} END {print \"MEM\",t,a}' /proc/stat /proc/meminfo; awk 'NR > 2 && $1 != \"lo:\" {rx += $2} END {print \"NET\",rx+0}' /proc/net/dev"]
    stdout: SplitParser { onRead: function(line) { root.parseLine(line) } }
  }

  OverlayWindow {
    shown: root.opened
    WlrLayershell.namespace: "aashutosh31-telemetry"

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0.02, 0.03, 0.08, 0.86)
      MouseArea { anchors.fill: parent; onClicked: root.dismiss() }
    }

    Rectangle {
      anchors.centerIn: parent
      width: Math.min(parent.width - Style.space(48), Style.space(440))
      height: card.implicitHeight + Style.space(40)
      radius: Style.radius.normal
      color: Qt.rgba(0.04, 0.05, 0.13, 0.96)
      border.color: Qt.rgba(0.49, 0.64, 0.97, 0.55)
      border.width: 1
      MouseArea { anchors.fill: parent; onClicked: {} }

      ColumnLayout {
        id: card
        anchors.centerIn: parent
        width: parent.width - Style.space(40)
        spacing: Style.space(14)

        Text {
          text: "SYSTEM TELEMETRY"
          color: "#7aa2f7"
          font.family: root.fontFamily || "monospace"
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 2
          Layout.alignment: Qt.AlignHCenter
        }

        Text { text: "LIVE // ON DEMAND"; color: "#565f89"; font.family: root.fontFamily || "monospace"; font.pixelSize: Style.font.small; Layout.alignment: Qt.AlignHCenter }

        TelemetryRow { label: "CPU"; value: root.cpu + "%"; accent: "#7aa2f7" }
        TelemetryRow { label: "MEM"; value: root.memory + "%"; accent: "#9ece6a" }
        TelemetryRow { label: "NET"; value: root.network; accent: "#bb9af7" }

        Text { text: "Click outside or press Esc to close"; color: "#565f89"; font.family: root.fontFamily || "monospace"; font.pixelSize: Style.font.small; Layout.alignment: Qt.AlignHCenter }
      }
    }

    Item { anchors.fill: parent; focus: true; Keys.onEscapePressed: root.dismiss() }
  }

  component TelemetryRow: RowLayout {
    property string label
    property string value
    property color accent
    Layout.fillWidth: true
    Text { text: parent.label; color: parent.accent; font.family: root.fontFamily || "monospace"; font.pixelSize: Style.font.body; Layout.preferredWidth: Style.space(70) }
    Text { text: parent.value; color: "#c0caf5"; font.family: root.fontFamily || "monospace"; font.pixelSize: Style.font.body; Layout.alignment: Qt.AlignRight }
  }
}
