import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Tab 2 — SSH and sudo activity plus the listening-port surface.
Item {
  id: root

  property color foreground: Commons.Color.popups.text
  property color dim: Commons.Util.alpha(foreground, 0.62)
  property color accent: Commons.Color.accent
  property color urgent: Commons.Color.urgent
  property string fontFamily: Style.font.family
  property var security: ({})

  readonly property var ports: security.ports || []
  readonly property var sudo: security.sudo || ({})
  readonly property bool journalAvailable: security.journalAvailable === true
  readonly property int exposed: {
    var n = 0
    for (var i = 0; i < ports.length; i++) if (!ports[i].loopback) n++
    return n
  }

  Column {
    id: header
    width: parent.width
    spacing: Style.space(2)

    Text {
      text: "Security"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.weight: Font.DemiBold
      textFormat: Text.PlainText
    }

    Text {
      width: parent.width
      text: "Hosts are redacted before the snapshot leaves the backend. Ports on localhost stay local; everything else is exposed to the network."
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
        { label: "Failed SSH · 24h", value: Number(root.security.failedSsh || 0),
          warn: Number(root.security.failedSsh || 0) > 5 },
        { label: "sudo failures", value: Number(root.sudo.failures || 0),
          warn: Number(root.sudo.failures || 0) > 0 },
        { label: "sudo successes", value: Number(root.sudo.successes || 0),
          warn: false }
      ]

      Rectangle {
        required property var modelData
        width: (parent.width - Style.space(12)) / 3
        height: Style.space(58)
        radius: Style.cornerRadius
        color: Commons.Util.alpha(modelData.warn ? root.urgent : root.accent, 0.12)

        Column {
          anchors.centerIn: parent
          spacing: Style.space(1)

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: String(modelData.value)
            color: modelData.warn ? root.urgent : root.foreground
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
        }
      }
    }
  }

  RowLayout {
    id: portsHeader
    anchors.top: stats.bottom
    anchors.topMargin: Style.space(10)
    width: parent.width

    Text {
      text: "Listening ports"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.weight: Font.DemiBold
      textFormat: Text.PlainText
    }

    Item { Layout.fillWidth: true }

    Text {
      text: root.ports.length + " open · " + root.exposed + " exposed"
      color: root.exposed > 0 ? root.urgent : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      textFormat: Text.PlainText
    }
  }

  Text {
    id: journalNote
    visible: !root.journalAvailable
    anchors.top: portsHeader.bottom
    anchors.topMargin: Style.space(4)
    width: parent.width
    text: "Journal is not readable for this user, so SSH and sudo counts are unknown."
    color: root.urgent
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
  }

  ListView {
    id: list
    anchors.top: journalNote.visible ? journalNote.bottom : portsHeader.bottom
    anchors.topMargin: Style.space(6)
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    clip: true
    spacing: Style.space(1)
    model: root.ports

    delegate: Rectangle {
      id: row
      required property int index
      required property var modelData

      width: list.width
      height: Style.space(32)
      radius: Style.cornerRadius
      color: index % 2 === 0 ? Commons.Util.alpha(root.foreground, 0.035) : "transparent"

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        spacing: Style.space(8)

        Rectangle {
          Layout.preferredWidth: Style.space(42)
          height: Style.space(20)
          radius: Style.cornerRadius
          color: Commons.Util.alpha(root.accent, 0.16)

          Text {
            anchors.centerIn: parent
            text: String(modelData.proto || "").toUpperCase()
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            textFormat: Text.PlainText
          }
        }

        Text {
          Layout.fillWidth: true
          text: String(modelData.local || "")
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }

        Text {
          Layout.fillWidth: true
          text: String(modelData.process || "") === "" ? "unidentified" : String(modelData.process)
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }

        Text {
          Layout.preferredWidth: Style.space(64)
          horizontalAlignment: Text.AlignRight
          text: modelData.loopback ? "loopback" : "exposed"
          color: modelData.loopback ? root.dim : root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          textFormat: Text.PlainText
        }
      }
    }

    Text {
      anchors.centerIn: parent
      visible: list.count === 0
      text: "No listening ports reported."
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      textFormat: Text.PlainText
    }
  }
}
