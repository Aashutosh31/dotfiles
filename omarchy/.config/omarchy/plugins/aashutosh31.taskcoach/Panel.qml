import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "aashutosh31.taskcoach"
  ipcTarget: "aashutosh31.taskcoach"
  manageIpc: false

  property var tasks: []
  property string notice: ""
  property string editingId: ""
  property string reschedulingId: ""
  property string confirmDeleteId: ""
  property var actionCommand: []
  property bool clearTitleAfterAction: false
  property string pendingAction: ""
  property string actionErrorText: ""
  property string dueErrorText: ""
  readonly property string helper: Quickshell.env("HOME") + "/.config/omarchy/plugins/aashutosh31.taskcoach/taskcoach.py"
  readonly property color surface: Commons.Color.popups.background
  readonly property color foreground: Commons.Color.popups.text
  readonly property color accent: Commons.Color.accent
  readonly property color dim: Qt.darker(foreground, 1.6)
  readonly property int openCount: tasks.filter(function(task) { return !task.done }).length
  readonly property double defaultDueMs: {
    var date = new Date(Date.now() + 60 * 60 * 1000)
    date.setMinutes(Math.ceil(date.getMinutes() / 5) * 5, 0, 0)
    return date.getTime()
  }
  property int selectedYear: new Date(defaultDueMs).getFullYear()
  property int selectedMonth: new Date(defaultDueMs).getMonth() + 1
  property int selectedDay: new Date(defaultDueMs).getDate()
  property int selectedHour: {
    var hour = new Date(defaultDueMs).getHours() % 12
    return hour === 0 ? 12 : hour
  }
  property int selectedMinute: new Date(defaultDueMs).getMinutes()
  property string selectedMeridiem: new Date(defaultDueMs).getHours() >= 12 ? "PM" : "AM"
  readonly property var monthOptions: [
    { value: "1", label: "Jan" }, { value: "2", label: "Feb" },
    { value: "3", label: "Mar" }, { value: "4", label: "Apr" },
    { value: "5", label: "May" }, { value: "6", label: "Jun" },
    { value: "7", label: "Jul" }, { value: "8", label: "Aug" },
    { value: "9", label: "Sep" }, { value: "10", label: "Oct" },
    { value: "11", label: "Nov" }, { value: "12", label: "Dec" }
  ]
  readonly property var meridiemOptions: [
    { value: "AM", label: "AM" }, { value: "PM", label: "PM" }
  ]
  readonly property var yearOptions: {
    var options = []
    var first = Math.min(new Date().getFullYear(), selectedYear)
    var last = Math.max(new Date().getFullYear() + 3, selectedYear)
    for (var year = first; year <= last; year++)
      options.push({ value: String(year), label: String(year) })
    return options
  }
  readonly property var dayOptions: {
    var days = new Date(selectedYear, selectedMonth, 0).getDate()
    var options = []
    for (var day = 1; day <= days; day++)
      options.push({ value: String(day), label: String(day) })
    return options
  }
  readonly property var hourOptions: {
    var options = []
    for (var hour = 1; hour <= 12; hour++)
      options.push({ value: String(hour), label: String(hour) })
    return options
  }
  readonly property var minuteOptions: {
    var options = []
    for (var minute = 0; minute < 60; minute++) {
      var label = minute < 10 ? "0" + minute : String(minute)
      options.push({ value: label, label: label })
    }
    return options
  }
  readonly property var delayOptions: [
    { value: "900", label: "15 minutes" },
    { value: "1800", label: "30 minutes" },
    { value: "3600", label: "1 hour" },
    { value: "7200", label: "2 hours" },
    { value: "14400", label: "4 hours" },
    { value: "28800", label: "8 hours" },
    { value: "86400", label: "24 hours" }
  ]
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!listProc.running) listProc.running = true
  }

  function loadTasks(raw) {
    try {
      var parsed = JSON.parse(raw || "[]")
      tasks = Array.isArray(parsed) ? parsed : []
      notice = ""
    } catch (error) {
      notice = "Couldn’t read your tasks. Your saved file was left untouched."
    }
  }

  function runAction(args, clearOnSuccess) {
    if (actionProc.running) {
      notice = "One moment—I'm still saving that task."
      return false
    }
    actionErrorText = ""
    clearTitleAfterAction = clearOnSuccess === true
    pendingAction = String(args[0] || "")
    actionCommand = ["python3", helper].concat(args)
    actionProc.running = true
    return true
  }

  function addTask() {
    var form = panel.loadedContent
    if (!form) return
    var title = form.titleInput.text.trim()
    var parsedDue = form.dueEpochMs()
    if (!title) {
      notice = "Give the task a name first."
      return
    }
    if (!isFinite(parsedDue) || parsedDue <= Date.now()) {
      notice = "Choose a future time, challenger."
      return
    }
    if (editingId) {
      runAction(["edit", editingId, title, form.priorityPicker.value, String(parsedDue / 1000)], true)
    } else {
      runAction(["add", title, form.priorityPicker.value, String(parsedDue / 1000)], true)
    }
  }

  function beginEdit(task) {
    var form = panel.loadedContent
    if (!form) return
    editingId = task.id
    form.titleInput.text = task.title
    form.priorityPicker.value = task.priority
    var due = new Date(Number(task.due) * 1000)
    selectedYear = due.getFullYear()
    selectedMonth = due.getMonth() + 1
    selectedDay = due.getDate()
    var hour = due.getHours() % 12
    selectedHour = hour === 0 ? 12 : hour
    selectedMinute = due.getMinutes()
    selectedMeridiem = due.getHours() >= 12 ? "PM" : "AM"
    form.monthSelector.value = String(selectedMonth)
    form.daySelector.value = String(selectedDay)
    form.yearSelector.value = String(selectedYear)
    form.hourSelector.value = String(selectedHour)
    form.minuteSelector.value = selectedMinute < 10 ? "0" + selectedMinute : String(selectedMinute)
    form.meridiemSelector.value = selectedMeridiem
    form.titleInput.forceActiveFocus()
  }

  function cancelEdit() {
    var form = panel.loadedContent
    editingId = ""
    clearTitleAfterAction = false
    if (form) form.titleInput.text = ""
  }

  function scheduleLater(taskId, delaySeconds) {
    if (!isFinite(delaySeconds) || delaySeconds < 60) {
      notice = "Pick a delay of at least one minute."
      return
    }
    runAction(["later", taskId, String(delaySeconds)], false)
  }

  function clampSelectedDay() {
    selectedDay = Math.min(selectedDay, new Date(selectedYear, selectedMonth, 0).getDate())
  }

  function formatDue(seconds) {
    return Qt.formatDateTime(new Date(Number(seconds) * 1000),
                            Qt.locale(Commons.I18n.formatLocale),
                            "ddd, MMM d · h:mm AP")
  }

  Component.onCompleted: refresh()

  Timer {
    interval: 30 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: dueProc.running = true
  }

  Timer {
    id: refreshTimer
    interval: 350
    onTriggered: root.refresh()
  }

  Process {
    id: listProc
    command: ["python3", root.helper, "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.loadTasks(text)
    }
  }

  Process {
    id: dueProc
    command: ["python3", root.helper, "notify-due"]
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.dueErrorText = text.trim()
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.notice = root.dueErrorText || "A reminder couldn't be delivered. It will be retried."
        console.warn("Task Coach due check failed:", root.dueErrorText)
      } else {
        root.dueErrorText = ""
      }
      root.refresh()
    }
  }

  Process {
    id: actionProc
    command: root.actionCommand
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.actionErrorText = text.trim()
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.notice = root.actionErrorText || "I couldn't save that. Your task is still here—try again."
        root.clearTitleAfterAction = false
        return
      }
      if (root.clearTitleAfterAction) {
        var form = panel.loadedContent
        if (form) form.titleInput.text = ""
        root.editingId = ""
      }
      if (root.pendingAction === "later") root.reschedulingId = ""
      if (root.pendingAction === "delete") root.confirmDeleteId = ""
      root.clearTitleAfterAction = false
      root.pendingAction = ""
      root.notice = ""
      refreshTimer.restart()
    }
  }

  ShellIpc {
    target: root.ipcTarget
    function open(): void { root.open(); root.refresh() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle(); root.refresh() }
    function later(taskId: string): void {
      root.open()
      root.reschedulingId = taskId
      root.refresh()
    }
    function done(taskId: string): void {
      root.runAction(["done", taskId], false)
    }
    function snooze30(taskId: string): void {
      root.scheduleLater(taskId, 30 * 60)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰀠"
    active: root.openCount > 0
    activeColor: root.accent
    useActiveColor: true
    tooltipText: root.openCount === 0 ? "Task Coach" : root.openCount + " open tasks"
    onPressed: root.toggle()

    Rectangle {
      visible: root.openCount > 0
      width: Math.max(Style.space(14), badgeText.implicitWidth + Style.space(6))
      height: Style.space(14)
      radius: height / 2
      color: root.accent
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.rightMargin: Style.space(3)
      anchors.topMargin: Style.space(2)
      Text {
        id: badgeText
        anchors.centerIn: parent
        text: root.openCount > 99 ? "99+" : String(root.openCount)
        textFormat: Text.PlainText
        color: root.surface
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(760))

    content: Item {
      id: panelContent
      property alias titleInput: titleField
      property alias priorityPicker: priorityGroup
      property alias monthSelector: monthPicker
      property alias daySelector: dayPicker
      property alias yearSelector: yearPicker
      property alias hourSelector: hourPicker
      property alias minuteSelector: minutePicker
      property alias meridiemSelector: meridiemPicker
      function dueEpochMs() {
        var hour = root.selectedHour % 12
        if (root.selectedMeridiem === "PM") hour += 12
        return new Date(root.selectedYear, root.selectedMonth - 1, root.selectedDay,
                        hour, root.selectedMinute, 0, 0).getTime()
      }
      implicitWidth: Style.space(420)
      implicitHeight: contentColumn.implicitHeight

      Column {
        id: contentColumn
        anchors.fill: parent
        spacing: Style.space(12)

        Row {
          width: parent.width
          spacing: Style.space(10)
          Column {
            width: parent.width - countLabel.implicitWidth - Style.space(10)
            Text {
              text: "Task Coach"
              textFormat: Text.PlainText
              color: root.foreground
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Text {
              text: "Small promises. Kept."
              textFormat: Text.PlainText
              color: root.dim
              font.pixelSize: Style.font.bodySmall
            }
          }
          Text {
            id: countLabel
            text: root.openCount + " open"
            textFormat: Text.PlainText
            color: root.accent
            font.pixelSize: Style.font.bodySmall
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Rectangle { width: parent.width; height: 1; color: Util.alpha(root.foreground, 0.12) }

        Row {
          width: parent.width
          TextField {
            id: titleField
            width: parent.width
            placeholderText: "What will you get done?"
            selectByMouse: true
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(8)
          ButtonGroup {
            id: priorityGroup
            options: [
              { value: "low", label: "Low" },
              { value: "medium", label: "Medium" },
              { value: "high", label: "High" }
            ]
            value: "medium"
            foreground: root.foreground
            background: root.surface
            accent: root.accent
            fontFamily: Style.font.family
            onChanged: function(value) { priorityGroup.value = value }
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(6)
          Text {
            text: "Date"
            textFormat: Text.PlainText
            color: root.dim
            font.pixelSize: Style.font.bodySmall
            anchors.verticalCenter: parent.verticalCenter
          }
          Dropdown {
            id: monthPicker
            width: Style.space(112)
            height: Style.spacing.controlHeight
            showLabel: false
            value: String(root.selectedMonth)
            options: root.monthOptions
            foreground: root.foreground
            background: root.surface
            popupBorder: Commons.Color.popups.border
            accent: root.accent
            onChanged: function(value) {
              root.selectedMonth = Number(value)
              root.clampSelectedDay()
              panelContent.daySelector.value = String(root.selectedDay)
            }
          }
          Dropdown {
            id: dayPicker
            width: Style.space(68)
            height: Style.spacing.controlHeight
            showLabel: false
            value: String(root.selectedDay)
            options: root.dayOptions
            foreground: root.foreground
            background: root.surface
            popupBorder: Commons.Color.popups.border
            accent: root.accent
            onChanged: function(value) { root.selectedDay = Number(value) }
          }
          Dropdown {
            id: yearPicker
            width: Style.space(84)
            height: Style.spacing.controlHeight
            showLabel: false
            value: String(root.selectedYear)
            options: root.yearOptions
            foreground: root.foreground
            background: root.surface
            popupBorder: Commons.Color.popups.border
            accent: root.accent
            onChanged: function(value) {
              root.selectedYear = Number(value)
              root.clampSelectedDay()
              panelContent.daySelector.value = String(root.selectedDay)
            }
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(6)
          Text {
            text: "Time"
            textFormat: Text.PlainText
            color: root.dim
            font.pixelSize: Style.font.bodySmall
            anchors.verticalCenter: parent.verticalCenter
          }
          Dropdown {
            id: hourPicker
            width: Style.space(68)
            height: Style.spacing.controlHeight
            showLabel: false
            value: String(root.selectedHour)
            options: root.hourOptions
            foreground: root.foreground
            background: root.surface
            popupBorder: Commons.Color.popups.border
            accent: root.accent
            onChanged: function(value) { root.selectedHour = Number(value) }
          }
          Dropdown {
            id: minutePicker
            width: Style.space(76)
            height: Style.spacing.controlHeight
            showLabel: false
            value: root.selectedMinute < 10 ? "0" + root.selectedMinute : String(root.selectedMinute)
            options: root.minuteOptions
            foreground: root.foreground
            background: root.surface
            popupBorder: Commons.Color.popups.border
            accent: root.accent
            onChanged: function(value) { root.selectedMinute = Number(value) }
          }
          Dropdown {
            id: meridiemPicker
            width: Style.space(72)
            height: Style.spacing.controlHeight
            showLabel: false
            value: root.selectedMeridiem
            options: root.meridiemOptions
            foreground: root.foreground
            background: root.surface
            popupBorder: Commons.Color.popups.border
            accent: root.accent
            onChanged: function(value) { root.selectedMeridiem = value }
          }
          Item { width: 1; height: 1 }
          Button {
            id: addButton
            text: root.editingId ? "Save" : "Add task"
            onClicked: root.addTask()
          }
        }
        Button {
          visible: root.editingId !== ""
          text: "Cancel edit"
          onClicked: root.cancelEdit()
        }

        Text {
          visible: root.notice !== ""
          width: parent.width
          text: root.notice
          textFormat: Text.PlainText
          color: "#e8a0a0"
          wrapMode: Text.Wrap
          font.pixelSize: Style.font.bodySmall
        }

        ListView {
          id: taskList
          width: parent.width
          height: Math.min(contentHeight, Style.space(500))
          implicitHeight: Math.min(contentHeight, Style.space(500))
          clip: true
          spacing: Style.space(6)
          model: root.tasks
          delegate: Rectangle {
            required property var modelData
            width: taskList.width
            height: cardColumn.implicitHeight + Style.space(14)
            radius: Style.cornerRadius
            color: Util.alpha(root.foreground, 0.055)

            Column {
              id: cardColumn
              anchors.fill: parent
              anchors.margins: Style.space(7)
              spacing: Style.space(5)

              Row {
                id: taskRow
                width: parent.width
                spacing: Style.space(8)
                Rectangle {
                  width: Style.space(3)
                  height: parent.height
                  radius: width / 2
                  color: modelData.priority === "high" ? Commons.Color.urgent :
                         modelData.priority === "medium" ? root.accent : root.dim
                }
                Column {
                  width: parent.width - Style.space(12)
                  spacing: Style.space(3)
                  Text {
                    width: parent.width
                    text: modelData.title
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: modelData.done ? root.dim : root.foreground
                    font.pixelSize: Style.font.body
                    font.strikeout: modelData.done
                  }
                  Text {
                    text: modelData.priority.toUpperCase() + "  ·  " + root.formatDue(modelData.due) +
                          (modelData.laterCount > 0 ? "  ·  LATER × " + modelData.laterCount : "") +
                          (modelData.done ? "  ·  DONE" : "")
                    textFormat: Text.PlainText
                    color: modelData.laterCount >= 3 ? Commons.Color.urgent : root.dim
                    font.pixelSize: Style.font.caption
                  }
                }
              }

              Row {
                width: parent.width
                spacing: Style.space(4)
                Button {
                  text: "Edit"
                  enabled: !modelData.done
                  onClicked: root.beginEdit(modelData)
                }
                Button {
                  text: modelData.done ? "Undo" : "Later"
                  selected: root.reschedulingId === modelData.id
                  onClicked: {
                    if (modelData.done) {
                      root.runAction(["undo", modelData.id], false)
                    } else {
                      root.confirmDeleteId = ""
                      root.reschedulingId = root.reschedulingId === modelData.id ? "" : modelData.id
                    }
                  }
                }
                Button {
                  text: "Done"
                  visible: !modelData.done
                  onClicked: root.runAction(["done", modelData.id], false)
                }
                Button {
                  text: "Delete"
                  onClicked: {
                    root.reschedulingId = ""
                    root.confirmDeleteId = root.confirmDeleteId === modelData.id ? "" : modelData.id
                  }
                }
              }

              Row {
                visible: root.reschedulingId === modelData.id && !modelData.done
                width: parent.width
                spacing: Style.space(6)
                Text {
                  text: "Move it to"
                  textFormat: Text.PlainText
                  color: root.dim
                  font.pixelSize: Style.font.bodySmall
                  anchors.verticalCenter: parent.verticalCenter
                }
                Dropdown {
                  id: delayPicker
                  width: Style.space(150)
                  height: Style.spacing.controlHeight
                  showLabel: false
                  value: "1800"
                  options: root.delayOptions
                  foreground: root.foreground
                  background: root.surface
                  popupBorder: Commons.Color.popups.border
                  accent: root.accent
                }
                Button {
                  text: "Reschedule"
                  onClicked: root.scheduleLater(modelData.id, Number(delayPicker.value))
                }
              }

              Row {
                visible: root.confirmDeleteId === modelData.id
                width: parent.width
                spacing: Style.space(6)
                Text {
                  text: "Delete this task permanently?"
                  textFormat: Text.PlainText
                  color: root.dim
                  font.pixelSize: Style.font.bodySmall
                  anchors.verticalCenter: parent.verticalCenter
                }
                Button {
                  text: "Confirm delete"
                  onClicked: root.runAction(["delete", modelData.id], false)
                }
                Button {
                  text: "Cancel"
                  onClicked: root.confirmDeleteId = ""
                }
              }
            }
          }
        }

        Text {
          visible: root.tasks.length === 0
          width: parent.width
          text: "No tasks yet. Enjoy the rare moment—or add one."
          textFormat: Text.PlainText
          color: root.dim
          wrapMode: Text.Wrap
          font.pixelSize: Style.font.body
        }
      }
    }
  }
}
