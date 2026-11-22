local FakeUI = require("tests.helpers.fake_ui")
local GamepadWiring = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.GamepadWiring")

local TOP_BAR = { "newConversationButton", "patchNotesButton", "markAllReadButton", "backButton", "optionsButton", "closeButton" }

local function fakeNav(active)
  ---@type table<string, any>
  local nav = { seen = {} }
  function nav.isActive()
    return active
  end
  for _, name in ipairs({
    "onShow",
    "onHide",
    "refresh",
    "setCloseHandler",
    "setScrollFrame",
    "ignore",
    "markFocusable",
    "setJumpTarget",
    "setOrder",
    "popupShown",
    "popupHidden",
    "setPopupCloseHandler",
  }) do
    nav[name] = function(...)
      table.insert(nav.seen, { name = name, args = { ... } })
    end
  end
  function nav.calls(name)
    local out = {}
    for _, s in ipairs(nav.seen) do
      if s.name == name then
        out[#out + 1] = s.args
      end
    end
    return out
  end
  return nav
end

local function shownButton(factory, parent)
  local button = factory.CreateFrame("Button", nil, parent)
  button:Show()
  return button
end

-- A window whose top bar has the 6 buttons, two settings tabs and two
-- contact tabs, wired to a fake nav.
local function setup(active)
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", "WhisperMessengerWindow", nil)
  local chrome = {}
  for _, name in ipairs(TOP_BAR) do
    chrome[name] = shownButton(factory, frame)
  end
  local t1, t2 = shownButton(factory, frame), shownButton(factory, frame)
  local x, y = shownButton(factory, frame), shownButton(factory, frame)
  local shell = { frame = frame, chrome = chrome, layout = { settingsTabs = { t1, t2 } } }
  local refs = {
    compactMode = {},
    windowVisibility = {},
    tabToggle = {
      getTabButtons = function()
        return { x, y }
      end,
    },
  }
  local nav = fakeNav(active ~= false)
  local wiring = GamepadWiring.Create(shell, nav)
  wiring.attach(refs)
  return { nav = nav, wiring = wiring, chrome = chrome, tabs = { t1, t2 }, contactTabs = { x, y } }
end

local function sameList(got, want)
  if #got ~= #want then
    return false
  end
  for i = 1, #want do
    if got[i] ~= want[i] then
      return false
    end
  end
  return true
end

local function assertOrder(args, key, frames, backDir, forwardDir)
  assert(args ~= nil, key .. ": setOrder seen")
  assert(args[1] == key and sameList(args[2], frames) and args[3] == backDir and args[4] == forwardDir, key .. ": frames and directions")
end

return function()
  -- test_attach_orders_top_bar_settings_tabs_and_contact_tabs
  do
    local t = setup()
    local orders = t.nav.calls("setOrder")
    local bar = {}
    for _, name in ipairs(TOP_BAR) do
      bar[#bar + 1] = t.chrome[name]
    end
    assert(#orders == 3, "three chains")
    assertOrder(orders[1], "topBar", bar, "LEFT", "RIGHT")
    assertOrder(orders[2], "settingsTabs", t.tabs, "UP", "DOWN")
    assertOrder(orders[3], "contactTabs", t.contactTabs, "LEFT", "RIGHT")
  end

  -- test_refresh_reorders_before_the_rescan
  do
    local t = setup()
    t.nav.seen = {}
    t.wiring.refresh()
    local names = {}
    for _, s in ipairs(t.nav.seen) do
      names[#names + 1] = s.name
    end
    assert(table.concat(names, ",") == "setOrder,setOrder,setOrder,refresh", "chains first, then the re-scan")
  end

  -- test_hiding_a_top_bar_button_reorders
  do
    local t = setup()
    t.nav.seen = {}
    t.chrome.markAllReadButton:Hide()
    local orders = t.nav.calls("setOrder")
    assert(#orders >= 1 and orders[1][1] == "topBar", "Mark all read hiding re-chains the top bar")
  end

  -- test_each_stop_is_hooked_once
  do
    local t = setup()
    t.wiring.refresh()
    t.wiring.refresh()
    t.nav.seen = {}
    t.chrome.closeButton:Hide()
    assert(#t.nav.calls("setOrder") == 3, "one reorder per hide, however many refreshes ran")
  end

  -- test_contact_tabs_are_never_ignored
  do
    local t = setup()
    for _, args in ipairs(t.nav.calls("ignore")) do
      assert(args[1] ~= t.contactTabs[1] and args[1] ~= t.contactTabs[2], "contact tab passed to nav.ignore")
      assert(args[1] ~= t.tabs[1] and args[1] ~= t.tabs[2], "settings tab passed to nav.ignore")
    end
  end

  -- test_refresh_before_attach_orders_nothing
  do
    local factory = FakeUI.NewFactory()
    local nav = fakeNav(true)
    local frame = factory.CreateFrame("Frame", nil, nil)
    GamepadWiring.Create({ frame = frame, chrome = { closeButton = shownButton(factory, frame) } }, nav).refresh()
    assert(#nav.calls("setOrder") == 0 and #nav.calls("refresh") == 1, "no refs yet: rescan only")
  end

  -- test_inactive_nav_orders_nothing
  do
    local t = setup(false)
    t.wiring.refresh()
    assert(#t.nav.calls("setOrder") == 0, "no gamepad UI: no chains")
  end
end
