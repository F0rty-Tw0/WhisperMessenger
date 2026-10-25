local IconRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconRuntime")
local MinimapIconRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.MinimapIconRuntime")
local PanelRegistry = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PanelRegistry")

-- A surface created after a panel registered a badge: one unread whisper
-- plus a badge of 2 must show 3 at once, with 1 whisper inside it.
local function runtimeWithBadge()
  local registry = PanelRegistry.New()
  registry.register("ca", {
    badge = function()
      return 2
    end,
  })
  return { panelRegistry = registry }
end

local function oneWhisper()
  return { { conversationKey = "wow::WOW::jaina", unreadCount = 1, channel = "WOW" } }
end

local function recorder()
  local last = {}
  return last, {
    setUnreadCount = function(count, whispers)
      last.count = count
      last.whispers = whispers
    end,
  }
end

local function createMinimap(ldbObject)
  local map, minimap = recorder()
  MinimapIconRuntime.Create({
    runtime = runtimeWithBadge(),
    accountState = {},
    characterState = {},
    buildContacts = oneWhisper,
    minimapIcon = {
      Create = function()
        return minimap
      end,
    },
    dataBroker = {
      Register = function(options)
        options.onRegistered(ldbObject)
      end,
    },
  })
  return map
end

return function()
  -- test_new_widget_counts_whispers_and_panel_badges
  do
    local widget, icon = recorder()
    IconRuntime.Create({
      runtime = runtimeWithBadge(),
      accountState = {},
      characterState = { icon = {} },
      buildContacts = oneWhisper,
      toggleIcon = {
        Create = function()
          return icon
        end,
      },
    })
    assert(widget.count == 3 and widget.whispers == 1, "widget 3 with 1 whisper, got " .. tostring(widget.count) .. "/" .. tostring(widget.whispers))
  end

  -- test_new_minimap_counts_whispers_and_panel_badges
  do
    local map = createMinimap({})
    assert(map.count == 3 and map.whispers == 1, "minimap 3 with 1 whisper, got " .. tostring(map.count) .. "/" .. tostring(map.whispers))
  end

  -- test_new_ldb_object_counts_whispers_and_panel_badges
  do
    local ldb = {}
    createMinimap(ldb)
    assert(ldb.unread == 3 and ldb.whispers == 1, "ldb 3 with 1 whisper, got " .. tostring(ldb.unread) .. "/" .. tostring(ldb.whispers))
  end

  -- test_new_ldb_text_splits_whispers_and_panel_items
  do
    local ldb = {}
    createMinimap(ldb)
    assert(ldb.text == "1 unread, 2 in addon pages", "got " .. tostring(ldb.text))
  end
end
