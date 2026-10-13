-- The window surface exposes chrome, layout and runtime pieces as one table.
local WindowSurface = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowSurface")
local SettingsPanels = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsPanels")

local function makeParts()
  local calls = { selected = nil, refreshed = 0, themed = 0, relayouts = 0, tabModes = {} }
  local row = { item = { conversationKey = "me::WOW::jaina" } }
  local parts = {
    chrome = { frame = "frame", title = "title" },
    layout = { contactsPane = "pane", whatsNewTab = "whatsNew" },
    settingsRuntime = {
      settingsPanels = "panels",
      refreshThemeVisuals = function()
        calls.themed = calls.themed + 1
      end,
      getSettings = function(index)
        return "settings" .. index
      end,
    },
    settingsResult = { whispersSettings = "lazyWhispers" },
    contactsRuntime = {
      contacts = { rows = { {}, row } },
      refreshContacts = "refreshContacts",
      tabToggle = {
        getMode = function()
          return "groups"
        end,
        setMode = function(mode)
          table.insert(calls.tabModes, mode)
        end,
      },
    },
    conversation = "conversation",
    composer = "composer",
    handleContactSelected = function(item)
      calls.selected = item
    end,
    refreshSelection = function()
      calls.refreshed = calls.refreshed + 1
    end,
    relayoutCurrentSize = function()
      calls.relayouts = calls.relayouts + 1
    end,
  }
  return parts, calls, row
end

return function()
  -- test_surface_maps_chrome_layout_and_settings
  do
    local window = WindowSurface.Build(makeParts())
    assert(window.frame == "frame" and window.title == "title", "chrome fields")
    assert(window.contactsPane == "pane" and window.whatsNewTab == "whatsNew", "layout fields")
    assert(window.settingsPanels == "panels", "settings panels")
    assert(window.generalSettings == "settings1", "general settings by index")
    assert(window.patchNotesSettings == "settings" .. SettingsPanels.PATCH_NOTES_INDEX, "patch notes settings")
    assert(window.conversation == "conversation" and window.composer == "composer", "runtime pieces")
  end

  -- test_lazily_built_settings_fall_back_to_the_result_table
  do
    local window = WindowSurface.Build(makeParts())
    assert(window.whispersSettings == "lazyWhispers", "missing fields read the lazily built settings")
  end

  -- test_select_conversation_selects_the_matching_row
  do
    local parts, calls, row = makeParts()
    local window = WindowSurface.Build(parts)
    assert(window.selectConversation("me::WOW::jaina") == true, "found the row")
    assert(calls.selected == row.item, "selected the row item")
  end

  -- test_select_unknown_conversation_refreshes_selection
  do
    local parts, calls = makeParts()
    local window = WindowSurface.Build(parts)
    assert(window.selectConversation("missing") == false, "no row matched")
    assert(calls.refreshed == 1 and calls.selected == nil, "refreshed instead of selecting")
  end

  -- test_refresh_theme_repaints_tabs_and_relayouts
  do
    local parts, calls = makeParts()
    WindowSurface.Build(parts).refreshTheme()
    assert(calls.themed == 1, "theme visuals refreshed")
    assert(calls.tabModes[1] == "groups", "tab bar repainted at its current mode")
    assert(calls.relayouts == 1, "layout re-applied")
  end
end
