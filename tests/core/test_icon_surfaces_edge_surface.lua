-- IconSurfaces.Update hands the edge surface the icon number and the whispers.
local IconSurfaces = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator.IconSurfaces")

local function surfacesWith(getEdgeSurface)
  return {
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
      return nil
    end,
    getMinimapIcon = function()
      return nil
    end,
    getLdbObject = function()
      return nil
    end,
    getEdgeSurface = getEdgeSurface,
  }
end

local contacts = { { conversationKey = "a", unreadCount = 2 } }

return function()
  local function test_update_hands_the_edge_surface_total_and_whispers()
    local got
    local edge = {
      setUnreadCount = function(total, whispers)
        got = { total, whispers }
      end,
    }
    IconSurfaces.Update(
      contacts,
      surfacesWith(function()
        return edge
      end)
    )
    assert(got and got[1] == 2 and got[2] == 2, "the edge surface got (2, 2)")
  end

  local function test_a_missing_getter_or_surface_raises_nothing()
    IconSurfaces.Update(contacts, surfacesWith(nil))
    IconSurfaces.Update(
      contacts,
      surfacesWith(function()
        return nil
      end)
    )
  end

  test_update_hands_the_edge_surface_total_and_whispers()
  test_a_missing_getter_or_surface_raises_nothing()
end
