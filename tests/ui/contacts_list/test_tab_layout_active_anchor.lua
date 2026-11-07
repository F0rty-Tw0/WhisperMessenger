local FakeUI = require("tests.helpers.fake_ui")
local TabLayout = require("WhisperMessenger.UI.ContactsList.TabLayout")

local function noop() end

-- A controller on stub tabs; `calls` records every anchor(visible, activeTab).
local function build()
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", nil, nil)
  local tabs = {}
  for _, mode in ipairs(TabLayout.MODES) do
    tabs[mode] = { mode = mode, btn = factory.CreateFrame("Button", nil, frame), unread = 0 }
  end
  local calls = {}
  local toggle = {}
  TabLayout.BindController(toggle, frame, tabs, {
    paint = noop,
    relabel = noop,
    anchor = function(visible, activeTab)
      calls[#calls + 1] = { visible = visible, active = activeTab }
    end,
    createPanelTab = function()
      return { btn = factory.CreateFrame("Button", nil, frame), unread = 0 }
    end,
  })
  return toggle, tabs, calls
end

local function lastCall(calls)
  return calls[#calls]
end

local ALL_MODES = { "whispers", "groups", "channels", "requests" }

-- test_initial_anchor_names_the_whispers_tab
do
  local _, tabs, calls = build()
  assert(calls[1].active == tabs.whispers, "first anchor names the Whispers tab")
end

-- test_mode_change_re_anchors_with_the_new_tab
do
  local toggle, tabs, calls = build()
  toggle.setModes(ALL_MODES)
  local before = #calls
  toggle.setMode("groups")
  assert(#calls == before + 1, "one more anchor, got " .. (#calls - before))
  assert(lastCall(calls).active == tabs.groups, "anchor names Groups")
end

-- test_repaint_set_mode_does_not_re_anchor
do
  local toggle, _, calls = build()
  toggle.setModes(ALL_MODES)
  local before = #calls
  toggle.setMode(toggle.getMode())
  assert(#calls == before, "a repaint keeps the scroll")
end

-- test_selecting_a_panel_re_anchors_once
do
  local toggle, tabs, calls = build()
  toggle.addPanelTab("ca", "Alerts", noop)
  local visible = lastCall(calls).visible
  local panel = visible[#visible]
  toggle.setSelectedPanel("ca")
  assert(lastCall(calls).active == panel, "anchor names the panel tab")
  local before = #calls
  toggle.setSelectedPanel("ca")
  assert(#calls == before, "selecting the same panel again does not re-anchor")
  toggle.setSelectedPanel(nil)
  assert(lastCall(calls).active == tabs.whispers, "leaving the panel names Whispers again")
end

-- test_unread_update_does_not_re_anchor
do
  local toggle, _, calls = build()
  local before = #calls
  toggle.setUnreadCounts(3, 1, 0, 0)
  assert(#calls == before, "badge updates do not re-anchor")
end

-- test_dropping_the_current_mode_anchors_whispers
do
  local toggle, tabs, calls = build()
  toggle.setModes(ALL_MODES)
  toggle.setMode("channels")
  toggle.setModes({ "whispers", "groups" })
  assert(lastCall(calls).active == tabs.whispers, "falls back to Whispers")
end

-- test_language_change_anchors_with_the_active_tab
do
  local toggle, tabs, calls = build()
  toggle.setMode("groups")
  local before = #calls
  toggle.setLanguage()
  assert(#calls == before + 1, "one more anchor, got " .. (#calls - before))
  assert(lastCall(calls).active == tabs.groups, "anchor names Groups")
end

-- test_unknown_panel_key_anchors_nil
do
  local toggle, _, calls = build()
  toggle.setSelectedPanel("missing")
  assert(lastCall(calls).active == nil, "no tab is active")
end

print("PASS: test_tab_layout_active_anchor")
