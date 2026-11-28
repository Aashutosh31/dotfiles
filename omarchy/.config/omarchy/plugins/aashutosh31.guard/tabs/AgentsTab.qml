import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Tab 1 — AI and background dev processes found by the daemon.
Item {
  id: root

  property color foreground: Commons.Color.popups.text
  property color dim: Commons.Util.alpha(foreground, 0.62)
  property color accent: Commons.Color.accent
  property color urgent: Commons.Color.urgent
  property string fontFamily: Style.font.family
  property var agents: []

  signal terminateRequested(int pid)

  Column {
    id: header
    width: parent.width
    spacing: Style.space(2)

    RowLayout {
      width: parent.width

      Text {
        text: "Active agents"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.weight: Font.DemiBold
        textFormat: Text.PlainText
      }

      Item { Layout.fillWidth: true }

      Text {
        text: root.agents.length + " found"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        textFormat: Text.PlainText
      }
    }

    Text {
      text: "AI tooling and long-running background processes. Terminate sends SIGKILL only after the helper re-checks ownership and the agent name."
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.Wrap
      width: parent.width
      textFormat: Text.PlainText
    }
  }

  ListView {
    id: list
    anchors.top: header.bottom
    anchors.topMargin: Style.space(8)
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    clip: true
    spacing: Style.space(2)
    model: root.agents

    delegate: Rectangle {
      id: row
      required property int index
      required property var modelData

      width: list.width
      height: Style.space(54)
      radius: Style.cornerRadius
      color: index % 2 === 0 ? Commons.Util.alpha(root.foreground, 0.035) : "transparent"

      readonly property bool hot: Number(modelData.highCpu)

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(6)
        spacing: Style.space(8)

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.space(1)

          Text {
            Layout.fillWidth: true
            text: String(modelData.command || "process")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
            textFormat: Text.PlainText
          }

          Text {
            Layout.fillWidth: true
            text: "PID " + modelData.pid + " · " + String(modelData.match || "agent")
              + (row.hot ? " · high CPU" : "")
              + (modelData.longRunning ? " · running long" : "")
            color: row.hot ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            textFormat: Text.PlainText
          }
        }

        Text {
          Layout.preferredWidth: Style.space(54)
          text: Number(modelData.cpu || 0).toFixed(1) + "%"
          horizontalAlignment: Text.AlignRight
          color: row.hot ? root.urgent : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          textFormat: Text.PlainText
        }

        Text {
          Layout.preferredWidth: Style.space(72)
          text: Math.max(0, Math.round(Number(modelData.rssKb || 0) / 1024)) + " MB"
          horizontalAlignment: Text.AlignRight
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          textFormat: Text.PlainText
        }

        Button {
          text: "Terminate"
          foreground: root.urgent
          accent: root.urgent
          fontSize: Style.font.caption
          bordered: true
          onClicked: root.terminateRequested(Number(modelData.pid))
        }
      }
    }

    Text {
      anchors.centerIn: parent
      visible: list.count === 0
      width: parent.width - Style.space(24)
      horizontalAlignment: Text.AlignHCenter
      text: "No AI agents running.\nThe shield still watches SSH, ports, and hardware."
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
    }
  }
}
