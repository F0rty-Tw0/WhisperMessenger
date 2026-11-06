local WindowStrata = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.WindowStrata")

local function makeFrame(mouseOver)
  local frame = { strata = "MEDIUM", level = 0 }
  function frame:SetFrameStrata(strata)
    self.strata = strata
  end
  function frame:SetFrameLevel(level)
    self.level = level
  end
  function frame:IsMouseOver()
    return mouseOver
  end
  return frame
end

-- An EditBox whose focus drops whenever the window's strata changes.
local function makeComposer(frame)
  local composer = { focused = true }
  function composer:HasFocus()
    return self.focused
  end
  function composer:SetFocus()
    self.focused = true
  end
  local setStrata = frame.SetFrameStrata
  function frame:SetFrameStrata(strata)
    composer.focused = false
    setStrata(self, strata)
  end
  return composer
end

local function withoutPointerFocus(fn)
  local savedFoci, savedFocus = rawget(_G, "GetMouseFoci"), rawget(_G, "GetMouseFocus")
  rawset(_G, "GetMouseFoci", nil)
  rawset(_G, "GetMouseFocus", nil)
  local ok, err = pcall(fn)
  rawset(_G, "GetMouseFoci", savedFoci)
  rawset(_G, "GetMouseFocus", savedFocus)
  assert(ok, err)
end

return function()
  withoutPointerFocus(function()
    -- test_a_part_of_the_window_outside_it_counts_as_the_window
    do
      local part = { GetParent = function() end }
      local saved = rawget(_G, "GetMouseFocus")
      rawset(_G, "GetMouseFocus", function()
        return part
      end)
      local frame = makeFrame(false)
      local strata = WindowStrata.New(frame, {
        isWindowPart = function(candidate)
          return candidate == part
        end,
      })
      local onWindow = strata.isPointerOnWindow()
      rawset(_G, "GetMouseFocus", saved)
      assert(onWindow == true, "the docked button is the window's")
    end

    -- test_strata_changes_are_reported
    do
      local reported = {}
      local frame = makeFrame(false)
      local strata = WindowStrata.New(frame, {
        onStrataChanged = function(value)
          reported[#reported + 1] = value
        end,
      })
      strata.promote()
      strata.demoteIfIdle()
      assert(reported[1] == "HIGH" and reported[2] == "MEDIUM", "both ways")
    end

    -- test_staying_up_reports_nothing
    do
      local reported = 0
      local strata = WindowStrata.New(makeFrame(true), {
        onStrataChanged = function()
          reported = reported + 1
        end,
      })
      strata.demoteIfIdle()
      assert(reported == 0, "the pointer is on the window, so nothing moved")
    end

    -- test_promote_raises_to_high_and_claims_escape
    do
      local frame = makeFrame(false)
      local claims = 0
      local strata = WindowStrata.New(frame, {}, {
        claim = function()
          claims = claims + 1
        end,
      })
      strata.promote()
      assert(frame.strata == "HIGH", "promoted to HIGH, got " .. tostring(frame.strata))
      assert(frame.level == 2000, "kept above Blizzard panel borders, got " .. tostring(frame.level))
      assert(claims == 1, "ESC claimed once")
    end

    -- test_promote_gives_composer_focus_back
    do
      local frame = makeFrame(false)
      local composer = makeComposer(frame)
      WindowStrata.New(frame, { composerInput = composer }, nil).promote()
      assert(composer.focused == true, "composer keeps focus across the strata change")
    end

    -- test_demote_skips_while_pointer_is_on_window
    do
      local frame = makeFrame(true)
      frame.strata = "HIGH"
      WindowStrata.New(frame, {}, nil).demoteIfIdle()
      assert(frame.strata == "HIGH", "hovered window stays raised")
    end

    -- test_demote_lowers_idle_window_to_medium
    do
      local frame = makeFrame(false)
      frame.strata = "HIGH"
      WindowStrata.New(frame, {}, nil).demoteIfIdle()
      assert(frame.strata == "MEDIUM", "idle window sent back, got " .. tostring(frame.strata))
    end
  end)
end
