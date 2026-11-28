import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "tabs"

// The Guard dashboard: status header, four tabs, and the 15 minute recorder.
// BarWidget owns polling and passes each snapshot down as `snapshot`.
PopupCard {
  id: root

  property var snapshot: ({})
  property int tab: 0

  signal terminateRequested(int pid)
  signal refreshRequested()

  readonly property var agentList: snapshot.agents && snapshot.agents.list ? snapshot.agents.list : []
  readonly property var security: snapshot.security || ({})
  readonly property var hardware: snapshot.hardware || ({})
  readonly property var system: snapshot.system || ({})
  readonly property var reasons: snapshot.reasons || []
  readonly property var errors: snapshot.errors || []

  readonly property color textColor: Commons.Color.popups.text
  readonly property color dimColor: Commons.Util.alpha(textColor, 0.62)
  readonly property color accentColor: Commons.Color.accent
  readonly property color urgentColor: Commons.Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string status: String(snapshot.status || "unknown")
  readonly property string statusLabel: status === "secure" ? "Secure"
    : status === "alert" ? "Alert"
    : status === "warning" ? "Warning" : "Checking…"
  readonly property color statusColor: status === "secure" ? accentColor : urgentColor
  readonly property int agentCount: agentList.length
  readonly property int exposedPorts: {
    var n = 0
    var ports = security.ports || []
    for (var i = 0; i < ports.length; i++) if (!ports[i].loopback) n++
    return n
  }

  readonly property string updatedLabel: {
    var raw = snapshot.generatedAt
    if (!raw) return "waiting for first snapshot"
    var when = new Date(raw)
    if (isNaN(when.getTime())) return "updated recently"
    return "updated " + Qt.formatTime(when, "HH:mm:ss")
  }

  contentWidth: fittedContentWidth(Style.space(560))
  contentHeight: fittedContentHeight(Style.space(560))
  padding: Style.spacing.popupPadding

  // ---- Flight recorder ring buffer -------------------------------------
  // 180 samples at 5 seconds is exactly 15 minutes. While the panel is
  // closed the bar polls at 30 seconds and nothing is recorded.
  // PopupCard's default content list accepts visual items only. Keep the
  // non-visual model under an invisible Item so it is not assigned directly
  // to the popup's QQuickItem children alias.
  Item {
    width: 0
    height: 0
    visible: false
    ListModel { id: history }
  }

  function appendHistory() {
    var s = system
    if (!s || s.cpuPercent === null || s.cpuPercent === undefined) return
    var cpu = Number(s.cpuPercent)
    var mem = Number(s.memPercent)
    if (!isFinite(cpu) || !isFinite(mem)) return
    var now = Date.now()
    history.append({ stamp: now, cpu: cpu, mem: mem })
    while (history.count > 180) history.remove(0)
    while (history.count > 0 && now - history.get(0).stamp > 900000) history.remove(0)
  }

  onSnapshotChanged: if (open) appendHistory()
  onOpenChanged: if (open) appendHistory()

  Column {
    id: layout
    width: parent ? parent.width : root.contentWidth - root.padding * 2
    spacing: Style.space(12)

    // ---- Header --------------------------------------------------------
    RowLayout {
      width: parent.width
      spacing: Style.space(10)

      Text {
        text: "󰒃"
        color: root.statusColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.iconLarge
        textFormat: Text.PlainText
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          text: "Omarchy Guard"
          color: root.textColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          textFormat: Text.PlainText
        }

        Text {
          text: root.statusLabel + " · " + root.agentCount
            + (root.agentCount === 1 ? " agent" : " agents")
            + (root.exposedPorts > 0 ? " · " + root.exposedPorts + " exposed port(s)" : "")
          color: root.statusColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          textFormat: Text.PlainText
        }
      }

      Text {
        text: root.updatedLabel
        color: root.dimColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        textFormat: Text.PlainText
      }

      Button {
        text: "󰑐"
        tooltipText: "Refresh now"
        foreground: root.textColor
        accent: root.accentColor
        bordered: true
        onClicked: root.refreshRequested()
      }
    }

    // ---- Why the shield is urgent --------------------------------------
    Rectangle {
      visible: root.reasons.length > 0
      width: parent.width
      height: visible ? reasonText.implicitHeight + Style.space(12) : 0
      radius: Style.cornerRadius
      color: Commons.Util.alpha(root.urgentColor, 0.14)

      Text {
        id: reasonText
        x: Style.space(6)
        y: Style.space(6)
        width: parent.width - Style.space(12)
        text: root.reasons.length > 0 ? root.reasons[0] : ""
        color: root.textColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
      }
    }

    // ---- Tabs ----------------------------------------------------------
    Row {
      spacing: Style.space(4)

      Repeater {
        model: ["Agents", "Security", "Hardware", "Recorder"]

        Button {
          required property int index
          required property string modelData
          text: modelData
          selected: root.tab === index
          foreground: root.textColor
          accent: root.accentColor
          fontSize: Style.font.bodySmall
          onClicked: root.tab = index
        }
      }
    }

    // ---- Active tab ----------------------------------------------------
    StackLayout {
      width: parent.width
      height: Style.space(372)
      currentIndex: root.tab

      AgentsTab {
        foreground: root.textColor
        dim: root.dimColor
        accent: root.accentColor
        urgent: root.urgentColor
        fontFamily: root.fontFamily
        agents: root.agentList
        onTerminateRequested: function(pid) { root.terminateRequested(pid) }
      }

      SecurityTab {
        foreground: root.textColor
        dim: root.dimColor
        accent: root.accentColor
        urgent: root.urgentColor
        fontFamily: root.fontFamily
        security: root.security
      }

      HardwareTab {
        foreground: root.textColor
        dim: root.dimColor
        accent: root.accentColor
        urgent: root.urgentColor
        fontFamily: root.fontFamily
        hardware: root.hardware
        system: root.system
        errors: root.errors
      }

      RecorderTab {
        foreground: root.textColor
        dim: root.dimColor
        accent: root.accentColor
        urgent: root.urgentColor
        fontFamily: root.fontFamily
        historyModel: history
        agentCount: root.agentCount
      }
    }
  }
}
