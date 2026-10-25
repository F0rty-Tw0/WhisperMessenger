local IconSurfaces = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator.IconSurfaces")

local function recorder()
  local calls = {}
  return calls, {
    setUnreadCount = function(count, pulseCount)
      calls[#calls + 1] = { count = count, pulseCount = pulseCount }
    end,
  }
end

-- unread whispers and a panel badge sum (nil leaves the field out).
local function run(unread, badgeSum)
  local widgetCalls, widget = recorder()
  local minimapCalls, minimap = recorder()
  local ldb = {}
  local surfaces = {
    getWindow = function()
      return nil
    end,
    isWindowVisible = function()
      return false
    end,
    buildMessagePreview = function()
      return nil
    end,
    getIcon = function()
      return widget
    end,
    getMinimapIcon = function()
      return minimap
    end,
    getLdbObject = function()
      return ldb
    end,
  }
  if badgeSum ~= nil then
    surfaces.getPanelRegistry = function()
      return {
        badgeSum = function()
          return badgeSum
        end,
      }
    end
  end
  local contacts = {}
  if unread > 0 then
    contacts[1] = { channel = "WOW", unreadCount = unread }
  end
  IconSurfaces.Update(contacts, surfaces)
  return { widget = widgetCalls[#widgetCalls], minimap = minimapCalls[#minimapCalls], ldb = ldb }
end

return function()
  -- test_icon_count_is_whispers_plus_panel_badges
  do
    local out = run(1, 2)
    assert(out.widget.count == 3, "widget shows 3, got " .. tostring(out.widget.count))
    assert(out.minimap.count == 3, "minimap shows 3, got " .. tostring(out.minimap.count))
    assert(out.ldb.unread == 3, "LDB count is 3, got " .. tostring(out.ldb.unread))
    assert(out.ldb.text == "1 unread, 2 in addon pages", "LDB text splits, got " .. tostring(out.ldb.text))
  end

  -- test_icons_pulse_on_whispers_only
  do
    local out = run(1, 2)
    assert(out.widget.pulseCount == 1, "widget pulses on the whisper count, got " .. tostring(out.widget.pulseCount))
    assert(out.minimap.pulseCount == 1, "minimap pulses on the whisper count, got " .. tostring(out.minimap.pulseCount))
  end

  -- test_panel_badges_alone_give_no_pulse_count
  do
    local out = run(0, 2)
    assert(out.widget.count == 2 and out.widget.pulseCount == 0, "widget: count 2, pulse count 0")
    assert(out.minimap.count == 2 and out.minimap.pulseCount == 0, "minimap: count 2, pulse count 0")
  end

  -- test_ldb_text_panel_items_alone
  do
    local out = run(0, 2)
    assert(out.ldb.text == "2 in addon pages", "got " .. tostring(out.ldb.text))
    assert(out.ldb.whispers == 0, "LDB keeps the whisper count for its tooltip")
  end

  -- test_surfaces_without_panel_badges_count_whispers
  do
    local out = run(2, nil)
    assert(out.widget.count == 2 and out.minimap.count == 2 and out.ldb.unread == 2, "whispers only")
    assert(out.ldb.text == "2 unread", "LDB text is today's, got " .. tostring(out.ldb.text))
  end
end
