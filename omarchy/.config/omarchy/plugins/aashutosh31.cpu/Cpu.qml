import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "aashutosh31.cpu"

  property real cpuPercent: 0
  property string prevLine: ""

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "aashutosh31.cpu"
    function refresh(): void { root.broadcast("refresh") }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: cpuProc
    command: ["bash", "-c", "head -1 /proc/stat"]
    stdout: SplitParser {
      onRead: function(line) {
        if (!line || !line.startsWith("cpu ")) return
        var fields = line.trim().split(/\s+/)
        var sum = 0
        for (var i = 1; i < fields.length; i++) sum += parseInt(fields[i])
        var idle = parseInt(fields[4]) + parseInt(fields[5])
        if (root.prevLine !== "") {
          var prevFields = root.prevLine.trim().split(/\s+/)
          var prevSum = 0
          for (var j = 1; j < prevFields.length; j++) prevSum += parseInt(prevFields[j])
          var prevIdle = parseInt(prevFields[4]) + parseInt(prevFields[5])
          var totalDelta = sum - prevSum
          var idleDelta = idle - prevIdle
          if (totalDelta > 0) root.cpuPercent = Math.round(((totalDelta - idleDelta) / totalDelta) * 100)
        }
        root.prevLine = line
      }
    }
  }

  function refresh() {
    if (!cpuProc.running) cpuProc.running = true
  }

  function toggleBtop() {
    if (!root.bar) return
    root.bar.run("pgrep -x btop > /dev/null && hyprctl dispatch focuswindow class:btop || omarchy-launch-floating-terminal-with-presentation btop")
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf2db"
    fontSize: Style.font.caption
    tooltipText: "CPU: " + root.cpuPercent + "%"
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.toggleBtop()
    }
  }
}
