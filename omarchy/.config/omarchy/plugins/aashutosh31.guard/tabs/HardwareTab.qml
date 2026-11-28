import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Tab 3 — temperatures, battery wear, and SMART health.
Item {
  id: root

  property color foreground: Commons.Color.popups.text
  property color dim: Commons.Util.alpha(foreground, 0.62)
  property color accent: Commons.Color.accent
  property color urgent: Commons.Color.urgent
  property string fontFamily: Style.font.family
  property var hardware: ({})
  property var system: ({})
  property var errors: []

  readonly property var battery: hardware.battery || ({})
  readonly property var disks: hardware.disks || []
  readonly property bool hasTemp: hardware.cpuTempC !== null && hardware.cpuTempC !== undefined

  function healthLabel(health) {
    switch (String(health)) {
    case "passed": return "Healthy"
    case "failed": return "FAILING"
    case "permission-denied": return "Requires root"
    case "unsupported": return "Unsupported"
    case "timeout": return "Timed out"
    default: return "Unknown"
    }
  }

  function healthColor(health) {
    var h = String(health)
    if (h === "failed" || h === "timeout") return root.urgent
    if (h === "passed") return root.accent
    return root.dim
  }

  Column {
    id: header
    width: parent.width
    spacing: Style.space(2)

    Text {
      text: "Hardware"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.weight: Font.DemiBold
      textFormat: Text.PlainText
    }

    Text {
      width: parent.width
      text: "Battery figures come from sysfs; SMART health needs smartctl and usually root, and is reported as unavailable rather than guessed."
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
    }
  }

  Row {
    id: stats
    anchors.top: header.bottom
    anchors.topMargin: Style.space(8)
    width: parent.width
    spacing: Style.space(6)

    Repeater {
      model: [
        {
          label: "CPU",
          value: root.hasTemp ? Math.round(Number(root.hardware.cpuTempC)) + " °C" : "—",
          detail: root.hasTemp ? String(root.hardware.cpuLabel || "") : "no sensor"
        },
        {
          label: "Memory",
          value: (root.system.memPercent === null || root.system.memPercent === undefined)
            ? "—" : String(root.system.memPercent) + "%",
          detail: (root.system.memUsedMb || 0) + " / " + (root.system.memTotalMb || 0) + " MB"
        },
        {
          label: "Battery",
          value: root.battery.present
            ? String(root.battery.capacity === null || root.battery.capacity === undefined ? "—" : root.battery.capacity) + "%"
            : "—",
          detail: root.battery.present
            ? (root.battery.healthPercent === null || root.battery.healthPercent === undefined
              ? "health unknown"
              : "health " + root.battery.healthPercent + "% · "
                + (root.battery.cycles === null || root.battery.cycles === undefined
                  ? "cycles unknown" : root.battery.cycles + " cycles"))
            : "no battery"
        }
      ]

      Rectangle {
        required property var modelData
        width: (parent.width - Style.space(12)) / 3
        height: Style.space(62)
        radius: Style.cornerRadius
        color: Commons.Util.alpha(root.accent, 0.10)

        Column {
          anchors.centerIn: parent
          spacing: Style.space(1)

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: modelData.value
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            textFormat: Text.PlainText
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: modelData.label
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            textFormat: Text.PlainText
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Style.space(150)
            horizontalAlignment: Text.AlignHCenter
            text: modelData.detail
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            textFormat: Text.PlainText
          }
        }
      }
    }
  }

  RowLayout {
    id: disksHeader
    anchors.top: stats.bottom
    anchors.topMargin: Style.space(10)
    width: parent.width

    Text {
      text: "Disks · SMART"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.weight: Font.DemiBold
      textFormat: Text.PlainText
    }

    Item { Layout.fillWidth: true }

    Text {
      text: root.disks.length + " device(s)"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      textFormat: Text.PlainText
    }
  }

  Text {
    id: errorsArea
    visible: root.errors.length > 0
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: visible ? implicitHeight : 0
    text: root.errors.length > 0 ? root.errors[0] : ""
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
  }

  ListView {
    id: list
    anchors.top: disksHeader.bottom
    anchors.topMargin: Style.space(6)
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: errorsArea.top
    anchors.bottomMargin: Style.space(4)
    clip: true
    spacing: Style.space(1)
    model: root.disks

    delegate: Rectangle {
      id: row
      required property int index
      required property var modelData

      width: list.width
      height: Style.space(44)
      radius: Style.cornerRadius
      color: index % 2 === 0 ? Commons.Util.alpha(root.foreground, 0.035) : "transparent"

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        spacing: Style.space(8)

        Text {
          Layout.preferredWidth: Style.space(70)
          text: "/dev/" + String(modelData.device || "")
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          textFormat: Text.PlainText
        }

        Text {
          Layout.preferredWidth: Style.space(96)
          text: root.healthLabel(modelData.health)
          color: root.healthColor(modelData.health)
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.weight: String(modelData.health) === "failed" ? Font.DemiBold : Font.Normal
          textFormat: Text.PlainText
        }

        Text {
          Layout.fillWidth: true
          text: String(modelData.detail || "")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }
      }
    }

    Text {
      anchors.centerIn: parent
      visible: list.count === 0
      text: "No disk health data available."
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      textFormat: Text.PlainText
    }
  }
}
