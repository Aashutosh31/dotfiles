import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "aashutosh31.telemetry"

  property real cpuPercent: 0
  property real memoryPercent: 0
  property string networkRate: "—"
  property string previousCpu: ""
  property real previousRx: -1
  property double previousTime: 0

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "aashutosh31.telemetry"
    function refresh(): void { root.sample() }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.sample()
  }

  Process {
    id: statsProc
    command: ["bash", "-c", "awk '/^cpu / {print; next} /^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} END {print \"MEM \" t \" \" a} /:/ && $1 != \"lo:\\" {rx += $2} END {print \"NET \" rx}' /proc/stat /proc/meminfo /proc/net/dev"]
    stdout: SplitParser { onRead: function(line) { root.readLine(line) } }
  }

  function sample() {
    if (!statsProc.running) statsProc.running = true
  }

  function readLine(line) {
    var text = String(line).trim()
    if (text.indexOf("cpu ") === 0) {
      var f = text.split(/\s+/)
      var total = 0
      for (var i = 1; i < f.length; i++) total += Number(f[i])
      var idle = Number(f[4]) + Number(f[5])
      if (root.previousCpu !== "") {
        var p = root.previousCpu.split(/\s+/)
        var oldTotal = 0
        for (var j = 1; j < p.length; j++) oldTotal += Number(p[j])
        var oldIdle = Number(p[4]) + Number(p[5])
        if (total > oldTotal) root.cpuPercent = Math.round((1 - (idle - oldIdle) / (total - oldTotal)) * 100)
      }
      root.previousCpu = text
    } else if (text.indexOf("MEM ") === 0) {
      var m = text.split(/\s+/)
      if (Number(m[1]) > 0) root.memoryPercent = Math.round((1 - Number(m[2]) / Number(m[1])) * 100)
    } else if (text.indexOf("NET ") === 0) {
      var rx = Number(text.split(/\s+/)[1])
      var now = Date.now()
      if (root.previousRx >= 0) {
        var rate = Math.max(0, (rx - root.previousRx) / Math.max(1, (now - root.previousTime) / 1000))
        root.networkRate = rate < 1024 ? Math.round(rate) + " B/s" : (rate / 1024).toFixed(1) + " KB/s"
      }
      root.previousRx = rx
      root.previousTime = now
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰍛"
    fontSize: Style.font.caption
    tooltipText: "CPU " + root.cpuPercent + "%  MEM " + root.memoryPercent + "%  NET " + root.networkRate
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.bar.run("omarchy-launch-tui btop")
    }
  }
}
