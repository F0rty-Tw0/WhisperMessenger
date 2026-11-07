local FakeUI = require("tests.helpers.fake_ui")
local IconArt = require("WhisperMessenger.UI.ToggleIcon.IconArt")
local IconScripts = require("WhisperMessenger.UI.ToggleIcon.IconScripts")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  local function build(summary, competitive)
    local calls = {}
    local state = { summary = summary, competitive = competitive }
    local art = {}
    local frame = factory.CreateFrame("Button", nil, parent)
    local hover = { active = false }
    local deps = {
      hover = hover,
      art = art,
      options = {},
      isLocked = function()
        return false
      end,
      syncLockGlyphVisibility = function()
        calls[#calls + 1] = "sync"
      end,
      refreshTransparency = function()
        calls[#calls + 1] = "refreshTransparency"
      end,
      squareLook = {
        setHover = function(value)
          calls[#calls + 1] = "setHover:" .. tostring(value)
        end,
        setPushed = function(value)
          calls[#calls + 1] = "setPushed:" .. tostring(value)
        end,
      },
      tooltip = {
        show = function(shownSummary, shownCompetitive)
          calls[#calls + 1] = "show:" .. tostring(shownSummary) .. ":" .. tostring(shownCompetitive)
        end,
        hide = function()
          calls[#calls + 1] = "hide"
        end,
      },
      getUnreadSummary = function()
        return state.summary
      end,
      getCompetitiveActive = function()
        return state.competitive
      end,
    }
    local drag = IconScripts.Attach(frame, deps)
    return frame, hover, calls, state, art, drag
  end

  local function withPaintFaceSpy(calls, run)
    local original = IconArt.PaintFace
    IconArt.PaintFace = function(art, hovered)
      calls[#calls + 1] = "PaintFace:" .. tostring(hovered)
    end
    local ok, err = pcall(run)
    IconArt.PaintFace = original
    assert(ok, err)
  end

  local function sameList(actual, expected)
    return table.concat(actual, ",") == table.concat(expected, ",")
  end

  -- test_enter_repaints_face_before_square_hover_then_shows_current_tooltip

  do
    local frame, hover, calls, state = build("2 unread", true)
    state.summary = "5 unread"
    withPaintFaceSpy(calls, function()
      frame:GetScript("OnEnter")()
    end)
    assert(hover.active == true, "OnEnter should mark the icon hovered")
    local expected = { "sync", "refreshTransparency", "PaintFace:true", "setHover:true", "show:5 unread:true" }
    assert(sameList(calls, expected), "OnEnter order was: " .. table.concat(calls, ","))
  end

  -- test_leave_clears_hover_and_hides_tooltip

  do
    local frame, hover, calls = build("", false)
    hover.active = true
    withPaintFaceSpy(calls, function()
      frame:GetScript("OnLeave")()
    end)
    assert(hover.active == false, "OnLeave should clear the hover flag")
    local expected = { "sync", "refreshTransparency", "PaintFace:false", "setHover:false", "hide" }
    assert(sameList(calls, expected), "OnLeave order was: " .. table.concat(calls, ","))
  end

  -- test_mouse_down_and_up_push_and_release_square_look

  do
    local frame, _, calls = build("", false)
    frame:GetScript("OnMouseDown")()
    frame:GetScript("OnMouseUp")()
    assert(sameList(calls, { "setPushed:true", "setPushed:false" }), "mouse scripts were: " .. table.concat(calls, ","))
  end

  -- test_attach_returns_drag_handle_for_a_scriptable_frame

  do
    local _, _, _, _, _, drag = build("", false)
    assert(type(drag.setRideHandlers) == "function", "Attach should return the drag handle")
  end

  -- test_attach_without_set_script_returns_empty_table

  do
    local drag = IconScripts.Attach({}, { hover = { active = false }, options = {} })
    assert(type(drag) == "table" and next(drag) == nil, "a frame without SetScript should give an empty table")
  end
end
