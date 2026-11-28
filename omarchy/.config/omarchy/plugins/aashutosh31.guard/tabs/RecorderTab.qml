import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Tab 4 — a 15 minute CPU/RAM strip chart fed by the open panel's 5 s poll.
Item {
  id: root

  property color foreground: Commons.Color.popups.text
  property color dim: Commons.Util.alpha(foreground, 0.62)
  property color accent: Commons.Color.accent
  property color urgent: Commons.Color.urgent
  property string fontFamily: Style.font.family
  property var historyModel: null
  property int agentCount: 0

  readonly property int sampleCount: historyModel ? historyModel.count : 0
  readonly property real latestCpu: sampleValue(sampleCount - 1, "cpu")
  readonly property real latestMem: sampleValue(sampleCount - 1, "mem")
  readonly property real peakCpu: peakValue("cpu")

  function sampleValue(index, key) {
    if (!historyModel || index < 0 || index >= sampleCount) return 0
    return Number(historyModel.get(index)[key]) || 0
  }

  function peakValue(key) {
    var peak = 0
    for (var i = 0; i < sampleCount; i++) {
      var v = Number(historyModel.get(i)[key]) || 0
      if (v > peak) peak = v
    }
    return peak
  }

  function css(c, a) {
    return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","
      + Math.round(c.b * 255) + "," + a + ")"
  }

  Column {
    id: header
    width: parent.width
    spacing: Style.space(2)

    Text {
      text: "Flight recorder"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.weight: Font.DemiBold
      textFormat: Text.PlainText
    }

    Text {
      width: parent.width
      text: "Fifteen minutes of system CPU and memory while this panel is open. A sneaky agent shows up as a CPU spike even when its name does not look familiar."
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
    }
  }

  RowLayout {
    id: legend
    anchors.top: header.bottom
    anchors.topMargin: Style.space(8)
    width: parent.width

    Rectangle {
      width: Style.space(7)
      height: width
      radius: width / 2
      color: root.accent
    }

    Text {
      text: "CPU " + Math.round(root.latestCpu) + "%"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      textFormat: Text.PlainText
    }

    Rectangle {
      width: Style.space(7)
      height: width
      radius: width / 2
      color: Commons.Util.alpha(root.foreground, 0.55)
    }

    Text {
      text: "RAM " + Math.round(root.latestMem) + "%"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      textFormat: Text.PlainText
    }

    Item { Layout.fillWidth: true }

    Text {
      text: root.sampleCount + " samples · peak " + Math.round(root.peakCpu) + "%"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      textFormat: Text.PlainText
    }
  }

  Rectangle {
    id: chartFrame
    anchors.top: legend.bottom
    anchors.topMargin: Style.space(6)
    anchors.left: parent.left
    anchors.right: parent.right
    height: parent.height - y - footnote.height - Style.space(8)
    radius: Style.cornerRadius
    color: Commons.Util.alpha(root.foreground, 0.035)

    Canvas {
      id: chart
      anchors.fill: parent
      anchors.margins: Style.space(8)
      antialiasing: true

      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()

      onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)

        var n = root.sampleCount
        if (n < 2 || width < 40 || height < 40) return

        var padLeft = 26
        var padTop = 6
        var padBottom = 14
        var plotW = width - padLeft
        var plotH = height - padTop - padBottom
        if (plotW < 10 || plotH < 10) return

        ctx.lineWidth = 1
        ctx.strokeStyle = root.css(root.foreground, 0.12)
        for (var g = 0; g <= 4; g++) {
          var gridY = padTop + plotH * g / 4
          ctx.beginPath()
          ctx.moveTo(padLeft, gridY)
          ctx.lineTo(width, gridY)
          ctx.stroke()
        }

        var labelFont = Style.font.caption + "px '" + root.fontFamily.replace(/'/g, "") + "'"
        ctx.fillStyle = root.css(root.dim, 1)
        ctx.font = labelFont
        ctx.textBaseline = "middle"
        ctx.fillText("100", 0, padTop + 2)
        ctx.fillText("0", 0, padTop + plotH - 2)

        function xAt(i) { return padLeft + plotW * i / (n - 1) }
        function yAt(v) { return padTop + plotH * (1 - Math.max(0, Math.min(100, v)) / 100) }

        function drawLine(key, color, lineWidth) {
          ctx.beginPath()
          ctx.strokeStyle = color
          ctx.lineWidth = lineWidth
          for (var i = 0; i < n; i++) {
            var x = xAt(i)
            var y = yAt(Number(root.historyModel.get(i)[key]) || 0)
            if (i === 0) ctx.moveTo(x, y)
            else ctx.lineTo(x, y)
          }
          ctx.stroke()
        }

        drawLine("mem", root.css(root.foreground, 0.5), 1.5)
        drawLine("cpu", root.css(root.accent, 1), 2)
      }
    }

    Text {
      anchors.centerIn: parent
      visible: root.sampleCount < 2
      width: parent.width - Style.space(24)
      horizontalAlignment: Text.AlignHCenter
      text: "Collecting samples…\nThe recorder starts when the panel opens and fills 15 minutes at one sample every 5 seconds."
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
    }

    // Repaint twice a second: the canvas follows the ring buffer without
    // rebuilding the ListModel or animating anything else.
    Timer {
      interval: 1000
      running: root.visible
      repeat: true
      onTriggered: chart.requestPaint()
    }
  }

  Text {
    id: footnote
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    text: "Polling: 5 s open · 30 s closed · ring buffer capped at 180 samples"
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
  }
}
