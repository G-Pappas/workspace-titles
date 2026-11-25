.pragma library

// Shared by the service (popup) and the bar widget (settings panel).

var LAST = 10

var defaults = {
  enabled: true,        // show the popup when you switch workspace
  duration: 10,         // seconds before it closes itself
  display: "both",      // "both" (number + title), "title", "number"
  autoFromWindows: true,// no custom title: name it after the focused window
  defaultText: "Workspace {n}",  // used when there is nothing to name it after
  pauseOnHover: true,   // keep it open while the pointer is over it
  topOffset: 8          // gap below the bar, in pixels
}

function clamp(value, lo, hi, fallback) {
  var n = Number(value)
  if (!isFinite(n)) return fallback
  return Math.max(lo, Math.min(hi, Math.round(n)))
}

function resolveSettings(raw) {
  var r = raw || {}
  var out = {}
  out.enabled = r.enabled === undefined ? defaults.enabled : r.enabled === true
  out.duration = clamp(r.duration, 1, 120, defaults.duration)
  out.display = ["both", "title", "number"].indexOf(r.display) >= 0 ? r.display : defaults.display
  out.autoFromWindows = r.autoFromWindows === undefined ? defaults.autoFromWindows : r.autoFromWindows === true
  out.defaultText = typeof r.defaultText === "string" && r.defaultText.trim() !== ""
    ? r.defaultText : defaults.defaultText
  out.pauseOnHover = r.pauseOnHover === undefined ? defaults.pauseOnHover : r.pauseOnHover === true
  out.topOffset = clamp(r.topOffset, 0, 200, defaults.topOffset)
  return out
}

var TERMINALS = ["alacritty", "kitty", "foot", "ghostty", "xterm", "org.wezfurlong.wezterm"]

function prettyClass(cls) {
  var last = String(cls || "").split(".").pop().replace(/[-_]/g, " ")
  return last.replace(/\b\w/g, function(c) { return c.toUpperCase() })
}

// windows: [{ cls, title, active }]
function autoTitle(windows, ws, cfg) {
  var fallback = String(cfg.defaultText).replace("{n}", ws)
  if (!cfg.autoFromWindows || !windows || windows.length === 0) return fallback
  var top = windows[0]
  for (var i = 0; i < windows.length; i++) if (windows[i].active) { top = windows[i]; break }
  var name = TERMINALS.indexOf(String(top.cls).toLowerCase()) >= 0 && top.title
    ? top.title : (top.cls ? prettyClass(top.cls) : top.title)
  name = String(name || "").trim()
  if (name === "") return fallback
  if (windows.length > 1) name += " +" + (windows.length - 1)
  return name.length > 40 ? name.slice(0, 40) : name
}

// titles: { "<ws>": { title, auto } }. Only custom (auto === false) entries
// count; an old automatic one is ignored so the title keeps following the windows.
function titleFor(titles, ws, windows, cfg) {
  var entry = titles ? titles[String(ws)] : null
  if (entry && entry.auto === false && String(entry.title).trim() !== "") return String(entry.title)
  return autoTitle(windows, ws, cfg)
}

function parseJson(text, fallback) {
  try {
    var v = JSON.parse(text)
    return v && typeof v === "object" ? v : fallback
  } catch (e) { return fallback }
}

function withTitle(titles, ws, title) {
  var next = {}
  for (var k in titles) next[k] = titles[k]
  var t = String(title || "").trim()
  if (t === "") delete next[String(ws)]
  else next[String(ws)] = { title: t.slice(0, 40), auto: false }
  return next
}
