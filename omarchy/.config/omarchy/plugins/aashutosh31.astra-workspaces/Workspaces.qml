import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) if (values[i].id === id) return values[i]
    return null
  }

  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }
    ids.sort(function(a, b) { return a - b })
    return ids
  }

  function focusWorkspace(id) {
    if (bar) bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  readonly property real gap: root.vertical ? 0 : Style.space(1)
  implicitWidth: strip.implicitWidth
  implicitHeight: strip.implicitHeight

  Row {
    id: strip
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.gap

    Repeater {
      model: root.workspaceIds()

      Item {
        id: tab
        required property int modelData
        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
        width: root.vertical ? root.barSize : 34
        height: root.barSize

        Rectangle {
          anchors.centerIn: parent
          width: 16
          height: 16
          radius: width / 2
          visible: tab.focused
          color: "#a485bf"
          border.width: 1
          border.color: "#c7acd9"
        }

        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: tab.modelData === 10 ? "0" : String(tab.modelData)
          color: tab.focused ? "#160e2d" : (tab.occupied ? "#e7d9ed" : "#a99bb0")
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.weight: tab.focused ? Font.DemiBold : Font.Normal
          Behavior on color { ColorAnimation { duration: Style.duration(130) } }
        }

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 4
          width: tab.focused ? 12 : 3
          height: 2
          radius: 1
          color: tab.focused ? "#e8cedf" : "#c5a1dd"
          opacity: tab.focused || tab.occupied ? 0.9 : 0
          Behavior on width { NumberAnimation { duration: Style.duration(150); easing.type: Easing.OutCubic } }
          Behavior on opacity { NumberAnimation { duration: Style.duration(150) } }
        }

        WidgetButton {
          anchors.fill: parent
          bar: root.bar
          text: " "
          labelVisible: false
          hasVisualContent: true
          fixedWidth: parent.width
          fixedHeight: parent.height
          horizontalMargin: 0
          verticalPadding: 0
          foreground: "transparent"
          useActiveColor: false
          tooltipText: "Workspace " + tab.modelData + (tab.occupied ? " · active windows" : "")
          onPressed: function() { root.focusWorkspace(tab.modelData) }
        }
      }
    }
  }
}
