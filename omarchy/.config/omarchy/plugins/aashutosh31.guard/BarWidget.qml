import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Omarchy Guard — shield in the bar, dashboard in the popup.
//
// The daemon prints one JSON snapshot. --fast is cheap enough for the open
// panel's 5 second poll; closed, the poll drops to 30 seconds. The shield goes
// urgent whenever the snapshot is warning or alert.
BarWidget {
  id: root
  moduleName: "aashutosh31.guard"

  property var snapshot: ({})
  property bool popupOpen: false

  // scripts/ live next to this file. The shell loads plugins from a path with
  // no guaranteed cwd, so derive the directory from this component's URL.
  readonly property string pluginDir: {
    var url = String(Qt.resolvedUrl("BarWidget.qml"))
    url = url.replace(/^file:\/\//, "")
    url = url.substring(0, url.lastIndexOf("/"))
    return decodeURIComponent(url)
  }
  readonly property string daemonPath: pluginDir + "/scripts/guard-daemon.sh"
  readonly property string killPath: pluginDir + "/scripts/guard-kill.sh"

  readonly property string status: String(snapshot.status || "unknown")
  readonly property bool alert: status === "warning" || status === "alert"
  readonly property int agentCount: snapshot.agents ? Number(snapshot.agents.count || 0) : 0
  readonly property var hardware: snapshot.hardware || ({})
  readonly property var system: snapshot.system || ({})
  readonly property string tooltipText: buildTooltip()

  readonly property color foregroundColor: bar ? bar.foreground : Commons.Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property bool opened: popupOpen

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function open() {
    popupOpen = true
    refresh()
  }

  function close() {
    popupOpen = false
  }

  function toggle() {
    if (popupOpen) close()
    else open()
  }

  function buildTooltip() {
    if (!snapshot.status) return "Omarchy Guard · collecting…"
    var bits = [status === "secure" ? "Secure" : (status === "alert" ? "Alert" : "Warning")]
    bits.push(agentCount + (agentCount === 1 ? " agent" : " agents"))
    var temp = Number(hardware.cpuTempC)
    if (isFinite(temp)) bits.push(Math.round(temp) + " °C")
    var cpu = Number(system.cpuPercent)
    if (system.cpuPercent !== null && system.cpuPercent !== undefined && isFinite(cpu))
      bits.push("CPU " + Math.round(cpu) + "%")
    return bits.join(" | ")
  }

  function refresh() {
    if (!daemonProc.running) daemonProc.running = true
  }

  function refreshSmart() {
    if (!smartProc.running) smartProc.running = true
  }

  function applySnapshot(text) {
    try {
      var data = JSON.parse(String(text || ""))
      if (!data || typeof data !== "object" || Array.isArray(data)) return
      snapshot = data
    } catch (e) {
      // A partial read or a killed script keeps the previous snapshot rather
      // than blanking the bar.
    }
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function killAgent(pid) {
    var n = Number(pid)
    if (!isFinite(n) || n <= 1 || Math.floor(n) !== n) return
    if (!root.bar) return
    // bar.run() takes a shell command string; the path is single-quoted and
    // the PID is a validated integer. guard-kill.sh re-validates both.
    root.bar.run("bash " + shellQuote(killPath) + " " + n)
    killRefresh.restart()
  }

  ShellIpc {
    target: "aashutosh31.guard"

    function refresh(): void { root.broadcast("refresh") }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
  }

  Timer {
    // 5s while the dashboard is open so the recorder is smooth; 30s in the bar
    // so a closed plugin costs almost nothing.
    interval: root.popupOpen ? 5000 : 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: killRefresh
    interval: 900
    repeat: false
    onTriggered: root.refresh()
  }

  Process {
    id: daemonProc
    command: ["bash", root.daemonPath, "--fast"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applySnapshot(text)
    }
  }

  Process {
    id: smartProc
    command: ["bash", root.daemonPath, "--refresh-smart"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applySnapshot(text)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰒃"
    active: root.alert
    activeColor: root.bar ? root.bar.urgent : Commons.Color.urgent
    tooltipText: root.tooltipText
    onPressed: root.toggle()
  }

  GuardPanel {
    id: panel
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    snapshot: root.snapshot
    onTerminateRequested: function(pid) { root.killAgent(pid) }
    onRefreshRequested: {
      root.refresh()
      root.refreshSmart()
    }
  }
}
