local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local PanelHost = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PanelHost")

local function build(nativeChrome)
  local factory = FakeUI.NewFactory()
  -- Like the live client, new frames start shown.
  local create = factory.CreateFrame
  factory.CreateFrame = function(...)
    local frame = create(...)
    frame:Show()
    return frame
  end
  local parent = factory.CreateFrame("Frame", "Window", nil)
  local env = { parent = parent, added = {}, badges = {}, clicked = {} }
  local chrome = {
    addPanelButton = function(key, spec, onClick)
      env.added[#env.added + 1] = { key = key, spec = spec, onClick = onClick }
      return {
        setBadge = function(n)
          env.badges[#env.badges + 1] = n
        end,
      }
    end,
  }
  env.host = PanelHost.Create({
    factory = factory,
    parent = parent,
    chrome = chrome,
    nativeChrome = nativeChrome == true,
    theme = Theme,
    onButtonClick = function(key)
      env.clicked[#env.clicked + 1] = key
    end,
  })
  return env
end

local function panel(overrides)
  local p = { title = "Alerts", icon = "x", onShow = function() end }
  for k, v in pairs(overrides or {}) do
    p[k] = v
  end
  return p
end

local function assertPoint(pt, point, rel, relPoint, x, y, label)
  assert(
    pt[1] == point and pt[2] == rel and pt[3] == relPoint and pt[4] == x and pt[5] == y,
    label .. ": got " .. tostring(pt[1]) .. " " .. tostring(pt[4]) .. "," .. tostring(pt[5])
  )
end

return function()
  -- test_host_is_anchored_like_the_options_panel
  do
    local env = build(false)
    env.host.register("ca", panel())
    local frame = env.host.frameOf("ca")
    assert(frame:GetParent() == env.parent, "host frame under the given parent")
    assertPoint(frame.points[1], "TOPLEFT", env.parent, "TOPLEFT", 0, -20, "modern top")
    assertPoint(frame.points[2], "BOTTOMRIGHT", env.parent, "BOTTOMRIGHT", 0, 5, "modern bottom")
    local hud = build(true)
    hud.host.register("ca", panel())
    local p = Theme.LAYOUT.HUD_PANEL_PADDING
    local hudFrame = hud.host.frameOf("ca")
    assertPoint(hudFrame.points[1], "TOPLEFT", hud.parent, "TOPLEFT", 0, -p, "hud top")
    assertPoint(hudFrame.points[2], "BOTTOMRIGHT", hud.parent, "BOTTOMRIGHT", 0, p, "hud bottom")
  end

  -- test_register_creates_button_and_hidden_host
  do
    local env = build(false)
    assert(env.host.register("ca", panel({ icon = 134400 })) == true)
    assert(env.host.has("ca") and not env.host.has("other"))
    assert(env.host.frameOf("ca"):IsShown() == false, "host starts hidden")
    local added = env.added[1]
    assert(added.key == "ca" and added.spec.title == "Alerts" and added.spec.icon == 134400, "button got the caller's title and icon")
    assert(env.badges[1] == 0, "badge refreshed at registration (no badge fn -> 0)")
  end

  -- test_duplicate_and_bad_panels_are_refused
  do
    local env = build(false)
    assert(env.host.register("ca", panel()) == true)
    assert(env.host.register("ca", panel()) == false, "duplicate key refused")
    assert(env.host.register("x", "nope") == false, "non-table refused")
    assert(env.host.register("y", panel({ onShow = false })) == false, "missing onShow refused")
    assert(env.host.register("z", panel({ title = 5 })) == false, "non-string title refused")
    assert(env.host.register("w", panel({ icon = {} })) == false, "table icon refused")
    assert(env.host.register("v", panel({ onHide = "x" })) == false, "non-function onHide refused")
    assert(env.host.register("u", panel({ badge = 5 })) == false, "non-function badge refused")
    assert(#env.added == 1 and not env.host.has("x") and not env.host.has("y"), "refusals add no button")
  end

  -- test_show_runs_on_show_with_the_host_frame_and_refreshes_badge
  do
    local env = build(false)
    local received
    env.host.register(
      "ca",
      panel({
        onShow = function(frame)
          received = frame
        end,
        badge = function()
          return 4
        end,
      })
    )
    assert(env.host.show("ca") == true)
    assert(received == env.host.frameOf("ca") and received:IsShown(), "onShow gets the shown host frame")
    assert(env.badges[#env.badges] == 4, "badge refreshed on show")
  end

  -- test_show_unknown_key_is_false
  do
    local env = build(false)
    assert(env.host.show("nope") == false)
  end

  -- test_hide_runs_on_hide_once
  do
    local env = build(false)
    local hides = 0
    env.host.register(
      "ca",
      panel({
        onHide = function()
          hides = hides + 1
        end,
      })
    )
    env.host.show("ca")
    env.host.hide("ca")
    env.host.hide("ca")
    env.host.hide("unknown")
    assert(hides == 1, "onHide ran once, got " .. hides)
    assert(not env.host.frameOf("ca"):IsShown(), "frame hidden")
  end

  -- test_misbehaving_callbacks_do_not_propagate
  do
    local env = build(false)
    local boom = function()
      error("caller bug")
    end
    env.host.register("ca", panel({ onShow = boom, onHide = boom, badge = boom }))
    assert(env.host.show("ca") == true, "show still true when onShow errors")
    env.host.hide("ca")
    assert(env.badges[#env.badges] == 0, "erroring badge -> 0")
    env.host.register(
      "bad",
      panel({
        badge = function()
          return "lots"
        end,
      })
    )
    env.host.refreshBadge("bad")
    assert(env.badges[#env.badges] == 0, "non-number badge -> 0")
    env.host.refreshBadge("unknown")
  end

  -- test_button_click_reports_the_key
  do
    local env = build(false)
    env.host.register("ca", panel())
    env.added[1].onClick("ca")
    assert(env.clicked[1] == "ca", "button click reaches onButtonClick")
  end
end
