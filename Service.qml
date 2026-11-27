import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Shows a small card under the bar clock each time the focused workspace
// changes: its number and title, with rename and close buttons. It closes by
// itself after the configured seconds (not while hovered or being edited).
// Settings and titles live in files so the bar widget can share them:
//   ~/.config/omarchy/extensions/ws-title.json   (written by the widget)
//   ~/.local/state/ws-titles.json                (written only here)
Item {
  id: root

  // Injected by omarchy-shell.
  property var shell: null
  property var manifest: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string settingsPath: home + "/.config/omarchy/extensions/ws-title.json"
  readonly property string titlesPath: home + "/.local/state/ws-titles.json"

  property var rawSettings: ({})
  property var titles: ({})
  readonly property var cfg: Model.resolveSettings(rawSettings)

  property bool opened: false
  property bool editing: false
  property bool hovered: false
  property int ws: 1
  property bool ready: false
  property var targetScreen: null

  readonly property string title: Model.titleFor(titles, ws, windowsOn(ws), cfg)

  function windowsOn(id) {
    var out = []
    var all = Hyprland.toplevels.values
    for (var i = 0; i < all.length; i++) {
      var t = all[i]
      if (!t.workspace || t.workspace.id !== id) continue
      var o = t.lastIpcObject || ({})
      out.push({ cls: o["class"] || "", title: o.title || t.title || "", active: t.activated === true })
    }
    return out
  }

  function focusedScreen() {
    var monitor = Hyprland.focusedMonitor
    var name = monitor ? String(monitor.name || "") : ""
    for (var i = 0; i < Quickshell.screens.length; i++)
      if (Quickshell.screens[i].name === name) return Quickshell.screens[i]
    return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
  }

  function show(id, edit) {
    if (id < 1) return
    ws = id
    targetScreen = focusedScreen()
    opened = true
    if (edit) beginEdit()
    else { editing = false; restartTimer() }
  }

  function hide() {
    opened = false
    editing = false
    hovered = false
    hideTimer.stop()
  }

  function restartTimer() { hideTimer.restart() }

  function beginEdit() {
    editing = true
    hideTimer.stop()
    field.text = root.title
    Qt.callLater(function() { field.forceActiveFocus(); field.selectAll() })
  }

  function commit(save) {
    if (!editing) return
    if (save) setTitle(ws, field.text)
    editing = false
    restartTimer()
  }

  function setTitle(id, text) {
    var next = Model.withTitle(titles, id, text)
    titles = next
    titlesFile.setText(JSON.stringify(next, null, 2) + "\n")
  }

  Timer {
    id: hideTimer
    interval: root.cfg.duration * 1000
    onTriggered: if (!(root.hovered && root.cfg.pauseOnHover)) root.hide()
  }

  onHoveredChanged: if (opened && !editing && !hovered) restartTimer()

  // Show on every workspace switch (not on shell start).
  Connections {
    target: Hyprland
    function onFocusedWorkspaceChanged() {
      var w = Hyprland.focusedWorkspace
      if (!root.ready || !w || !root.cfg.enabled || w.id < 1) return
      root.show(w.id, false)
    }
  }

  // A workspace with no windows left has nothing to be titled: when its last
  // window closes (or at start, for workspaces emptied while the shell was off)
  // its custom title is cleared. Checked against `hyprctl clients`, debounced
  // on window changes. `occupied` is the set of workspaces that had windows at
  // the previous check; null until the first one.
  property var occupied: null

  function sweep(text) {
    var list
    try { list = JSON.parse(text) } catch (e) { return }
    if (!Array.isArray(list)) return
    var now = ({})
    for (var i = 0; i < list.length; i++) {
      var c = list[i]
      if (c.mapped !== false && c.workspace && c.workspace.id > 0) now[String(c.workspace.id)] = true
    }
    var next = ({}), changed = false
    for (var k in titles) {
      var gone = !now[k] && (occupied === null || occupied[k] === true)
      if (gone) changed = true
      else next[k] = titles[k]
    }
    occupied = now
    if (changed) {
      titles = next
      titlesFile.setText(JSON.stringify(next, null, 2) + "\n")
    }
  }

  Timer { id: sweepTimer; interval: 600; onTriggered: if (!clients.running) clients.running = true }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var n = event.name
      if (n === "openwindow" || n === "closewindow" || n === "movewindowv2" || n === "movewindow")
        sweepTimer.restart()
    }
  }

  Process {
    id: clients
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.sweep(text) }
  }

  // Offers (once, by notification) to hook SUPER + ALT + R into the Hyprland
  // config. Nothing changes unless accepted or `setup.sh apply` is run.
  Process {
    id: setup
    command: ["bash", decodeURIComponent(String(Qt.resolvedUrl("setup.sh")).replace(/^file:\/\//, ""))]
  }
  Component.onCompleted: {
    setup.running = true
    sweepTimer.start()
    Qt.callLater(function() { root.ready = true })
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.rawSettings = Model.parseJson(text(), ({}))
    onLoadFailed: root.rawSettings = ({})
  }

  FileView {
    id: titlesFile
    path: root.titlesPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.titles = Model.parseJson(text(), ({}))
    onLoadFailed: root.titles = ({})
  }

  ShellIpc {
    target: "gpappas.ws-title"
    function show(): string {
      var w = Hyprland.focusedWorkspace
      root.show(w ? w.id : 1, false)
      return "ok"
    }
    function rename(): string {
      var w = Hyprland.focusedWorkspace
      root.show(w ? w.id : 1, true)
      return "ok"
    }
    function renameWs(n: string): string {
      root.show(parseInt(n), true)
      return "ok"
    }
    function setTitle(n: string, text: string): string {
      root.setTitle(parseInt(n), text)
      return "ok"
    }
    function hide(): string { root.hide(); return "ok" }
    function ping(): string { return "ok" }
  }

  PanelWindow {
    id: win
    visible: root.opened && !!root.targetScreen
    screen: root.targetScreen
    anchors { top: true }
    margins { top: root.cfg.topOffset }
    implicitWidth: card.width
    implicitHeight: card.height
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-ws-title"
    WlrLayershell.keyboardFocus: root.editing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
      id: card
      width: row.implicitWidth + Style.space(20)
      height: row.implicitHeight + Style.space(12)
      radius: Math.max(Style.cornerRadius, Style.space(8))
      color: Qt.rgba(Commons.Color.background.r, Commons.Color.background.g, Commons.Color.background.b, 0.94)
      border.width: 1
      border.color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.25)

      HoverHandler { onHoveredChanged: root.hovered = hovered }

      Row {
        id: row
        anchors.centerIn: parent
        spacing: Style.space(8)

        // Workspace number.
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          visible: root.cfg.display !== "title"
          width: Math.max(numText.implicitWidth + Style.space(14), height)
          height: numText.implicitHeight + Style.space(6)
          radius: Style.space(6)
          color: Commons.Color.accent
          Text {
            id: numText
            anchors.centerIn: parent
            text: root.ws
            color: Commons.Color.background
            font.family: Style.font.family
            font.pixelSize: root.cfg.display === "number" ? Style.font.title : Style.font.body
            font.bold: true
          }
          MouseArea {
            anchors.fill: parent
            enabled: root.cfg.display === "number"
            cursorShape: Qt.PointingHandCursor
            onClicked: root.beginEdit()
          }
        }

        // Title, or the editor while renaming.
        Text {
          id: titleText
          anchors.verticalCenter: parent.verticalCenter
          visible: root.cfg.display !== "number" && !root.editing
          text: root.title
          textFormat: Text.PlainText
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.beginEdit()
          }
        }

        TextField {
          id: field
          anchors.verticalCenter: parent.verticalCenter
          visible: root.editing
          width: Style.space(240)
          maximumLength: 40
          placeholderText: "Empty = automatic"
          onAccepted: root.commit(true)
          Keys.onEscapePressed: root.commit(false)
        }

        PanelActionButton {
          anchors.verticalCenter: parent.verticalCenter
          iconText: root.editing ? "󰄬" : "󰏫"
          tooltipText: root.editing ? "Save" : "Rename"
          onClicked: root.editing ? root.commit(true) : root.beginEdit()
        }

        PanelActionButton {
          anchors.verticalCenter: parent.verticalCenter
          iconText: "󰅖"
          tooltipText: "Close"
          onClicked: root.hide()
        }
      }
    }
  }
}
