import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Bar button for Workspace Titles. Click it for the list of workspaces (click a
// row to switch, the pencil to rename) and for the popup's settings.
Panel {
  id: root
  moduleName: "gpappas.ws-title"
  ipcTarget: "gpappas.ws-title.widget"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string icon: "󰓹"

  readonly property string home: Quickshell.env("HOME")
  readonly property string settingsPath: home + "/.config/omarchy/extensions/ws-title.json"
  readonly property string titlesPath: home + "/.local/state/ws-titles.json"

  property var rawSettings: ({})
  property var titles: ({})
  readonly property var cfg: Model.resolveSettings(rawSettings)
  readonly property int activeWs: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0

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

  function titleOf(id) { return Model.titleFor(titles, id, windowsOn(id), cfg) }

  function switchTo(id) {
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + id + "\" })"])
    root.close()
  }

  function renameWs(id) {
    root.close()
    Quickshell.execDetached(["omarchy-shell", "-q", "gpappas.ws-title", "renameWs", String(id)])
  }

  // Every change rewrites the whole file with the full resolved settings.
  function apply(delta) {
    var next = Object.assign({}, root.cfg, delta)
    root.rawSettings = next
    settingsFile.setText(JSON.stringify(next, null, 2) + "\n")
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

  // The list re-reads window state each time the panel opens.
  property int stamp: 0
  onOpenedChanged: if (opened) {
    stamp++
    Qt.callLater(function() { keys.forceActiveFocus() })
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    slotSize: Style.bar.statusSlot
    active: root.opened
    tooltipText: "Workspace titles — " + root.activeWs + " · " + root.titleOf(root.activeWs)
    onPressed: function(code) {
      if (code === Qt.LeftButton) root.toggle()
      else Quickshell.execDetached(["omarchy-shell", "-q", "gpappas.ws-title", "rename"])
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keys
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: content
          width: parent.width
          spacing: Style.space(10)

          PanelHero {
            iconComponent: Component {
              Text {
                text: root.icon
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
            title: "Workspace titles"
            meta: root.activeWs > 0 ? "Now: " + root.activeWs + " · " + root.titleOf(root.activeWs) : ""
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          PanelSeparator { foreground: root.foreground }

          PanelSectionHeader { text: "Workspaces"; foreground: root.foreground; fontFamily: root.fontFamily }

          Repeater {
            model: { root.stamp; root.titles; return Model.LAST }
            delegate: Item {
              id: line
              required property int index
              readonly property int id: index + 1
              readonly property bool current: root.activeWs === id
              width: content.width
              height: Math.max(Style.space(26), label.implicitHeight + Style.space(6))

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.switchTo(line.id)
              }

              Text {
                id: num
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(26)
                text: line.id
                horizontalAlignment: Text.AlignHCenter
                color: line.current ? Color.accent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }

              Text {
                id: label
                anchors.left: num.right
                anchors.leftMargin: Style.space(8)
                anchors.right: pencil.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                text: { root.stamp; root.titles; root.cfg; return root.titleOf(line.id) }
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: line.current ? root.foreground : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: line.current
              }

              PanelActionButton {
                id: pencil
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰏫"
                tooltipText: "Rename workspace " + line.id
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.renameWs(line.id)
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          PanelSectionHeader { text: "Popup"; foreground: root.foreground; fontFamily: root.fontFamily }

          Toggle {
            width: content.width
            label: "Show on workspace switch"
            description: "Rename any time with SUPER + ALT + R, or right-click this button"
            checked: root.cfg.enabled
            onClicked: root.apply({ enabled: !root.cfg.enabled })
          }

          Text {
            text: "Show"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          ButtonGroup {
            options: [
              { value: "both", label: "Number + title" },
              { value: "title", label: "Title" },
              { value: "number", label: "Number only" }
            ]
            value: root.cfg.display
            onChanged: function(v) { root.apply({ display: v }) }
          }

          NumberField {
            label: "Seconds before it closes"
            value: root.cfg.duration
            from: 1
            to: 120
            onModified: function(v) { root.apply({ duration: v }) }
          }

          Toggle {
            width: content.width
            label: "Name new workspaces after their window"
            description: "Off: they get the default text below"
            checked: root.cfg.autoFromWindows
            onClicked: root.apply({ autoFromWindows: !root.cfg.autoFromWindows })
          }

          Text {
            text: "Default text ({n} = workspace number)"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          TextField {
            id: defaultField
            width: content.width
            text: root.cfg.defaultText
            onEditingFinished: if (text.trim() !== "") root.apply({ defaultText: text.trim() })
          }

          Toggle {
            width: content.width
            label: "Keep open while hovered"
            checked: root.cfg.pauseOnHover
            onClicked: root.apply({ pauseOnHover: !root.cfg.pauseOnHover })
          }

          NumberField {
            label: "Gap below the bar (px)"
            value: root.cfg.topOffset
            from: 0
            to: 200
            onModified: function(v) { root.apply({ topOffset: v }) }
          }

          Button {
            text: "Preview popup"
            onClicked: Quickshell.execDetached(["omarchy-shell", "-q", "gpappas.ws-title", "show"])
          }
        }
      }
    }
  }
}
