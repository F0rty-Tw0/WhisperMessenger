local IconSurfaces = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator.IconSurfaces")

-- The icons get the whole preview table as setIncomingPreview's 4th arg,
-- so the reply row knows which conversation and whisper it answers.
local function run(preview, minimapShown)
  local got = {}
  local function recorder(name)
    return function(_sender, _text, _class, meta)
      got[name] = { called = true, meta = meta }
    end
  end
  local surfaces = {
    getWindow = function()
      return nil
    end,
    isWindowVisible = function()
      return false
    end,
    buildMessagePreview = function()
      return preview
    end,
    getIcon = function()
      return { setIncomingPreview = recorder("icon") }
    end,
    getMinimapIcon = function()
      return {
        setIncomingPreview = recorder("minimap"),
        isShown = function()
          return minimapShown
        end,
      }
    end,
    getLdbObject = function()
      return nil
    end,
  }
  IconSurfaces.Update({}, surfaces)
  return got
end

local function preview()
  return { senderName = "Jaina", messageText = "hi", classTag = "MAGE", conversationKey = "wow::jaina", sentAt = 500, channel = "WOW" }
end

return function()
  local function test_widget_gets_the_preview_as_meta()
    local p = preview()
    local got = run(p, true)
    assert(got.icon.meta == p, "the widget gets the preview table 4th")
  end

  local function test_shown_minimap_gets_the_preview_as_meta()
    local p = preview()
    local got = run(p, true)
    assert(got.minimap.meta == p, "the shown minimap gets the preview table 4th")
  end

  local function test_hidden_minimap_gets_no_meta()
    local got = run(preview(), false)
    assert(got.minimap.called and got.minimap.meta == nil, "a hidden minimap gets nil 4th")
  end

  test_widget_gets_the_preview_as_meta()
  test_shown_minimap_gets_the_preview_as_meta()
  test_hidden_minimap_gets_no_meta()
end
