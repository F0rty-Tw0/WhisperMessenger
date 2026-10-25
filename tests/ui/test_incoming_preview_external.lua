local FakeUI = require("tests.helpers.fake_ui")
local IncomingPreview = require("WhisperMessenger.UI.ToggleIcon.IncomingPreview")

local function build(options)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:SetSize(48, 48)
  parent:Show()
  local state = { ownDismissed = 0 }
  options = options or {}
  options.onDismissPreview = function()
    state.ownDismissed = state.ownDismissed + 1
  end
  state.preview = IncomingPreview.Create(factory, parent, options)
  return state.preview, state
end

local function entry(log, sender)
  return {
    sender = sender or "Crafter",
    text = "Needs Plate Belt",
    classTag = "WARRIOR",
    onClick = function()
      log[#log + 1] = "click"
    end,
    onDismiss = function()
      log[#log + 1] = "dismiss"
    end,
    onShown = function()
      log[#log + 1] = "shown"
    end,
  }
end

local function mouseUp(p, button)
  p.frame:GetScript("OnMouseUp")(p.frame, button)
end

local function joined(log)
  return table.concat(log, ",")
end

local function has(log, word)
  for _, item in ipairs(log) do
    if item == word then
      return true
    end
  end
  return false
end

return function()
  local function test_external_shows_labels_and_runs_on_shown_once()
    local p = build()
    local log = {}
    p.setExternalPreview(entry(log))
    assert(p.frame.shown and p.senderLabel.text == "Crafter" and p.messageLabel.text == "Needs Plate Belt", "external content is painted")
    assert(p.isExternalShown() == true, "external reports shown")
    assert(joined(log) == "shown", "onShown runs once, got " .. joined(log))
  end

  local function test_same_entry_again_does_not_re_run_on_shown()
    local p = build()
    local log = {}
    local e = entry(log)
    p.setExternalPreview(e)
    p.setExternalPreview(e)
    assert(joined(log) == "shown", "same entry keeps one onShown, got " .. joined(log))
  end

  local function test_new_entry_while_visible_runs_its_on_shown()
    local p = build()
    local first, second = {}, {}
    p.setExternalPreview(entry(first))
    p.setExternalPreview(entry(second, "Other"))
    assert(joined(second) == "shown", "the new entry's onShown runs once, got " .. joined(second))
    assert(p.senderLabel.text == "Other", "the new entry is painted")
  end

  local function test_on_shown_runs_again_when_the_frame_shows_again()
    local p = build()
    local log = {}
    p.setExternalPreview(entry(log))
    p.frame:GetScript("OnShow")(p.frame)
    assert(joined(log) == "shown,shown", "showing the frame again reports it again, got " .. joined(log))
  end

  local function test_left_click_runs_on_click_then_hides()
    local p = build()
    local log = {}
    p.setExternalPreview(entry(log))
    mouseUp(p, "LeftButton")
    assert(joined(log) == "shown,click", "left click runs onClick, got " .. joined(log))
    assert(p.frame.shown == false and p.isExternalShown() == false, "left click hides the external preview")
  end

  local function test_right_click_dismisses_without_acknowledging_own()
    local p, state = build()
    local log = {}
    p.setExternalPreview(entry(log))
    mouseUp(p, "RightButton")
    assert(has(log, "dismiss"), "right click runs onDismiss")
    assert(state.ownDismissed == 0, "right click on an external never acknowledges the own whisper")
    assert(p.frame.shown == false, "right click hides the preview")
  end

  local function test_x_button_dismisses_without_acknowledging_own()
    local p, state = build()
    local log = {}
    p.setExternalPreview(entry(log))
    p.dismissButton:GetScript("OnClick")(p.dismissButton)
    assert(has(log, "dismiss"), "x runs onDismiss")
    assert(state.ownDismissed == 0, "x on an external never acknowledges the own whisper")
    assert(p.frame.shown == false, "x hides the preview")
  end

  local function test_no_auto_dismiss_timer()
    local savedTimer = _G.C_Timer
    local timers = 0
    rawset(_G, "C_Timer", {
      NewTimer = function()
        timers = timers + 1
        return { Cancel = function() end }
      end,
    })
    local ok, err = pcall(function()
      local p = build({
        getPreviewAutoDismissSeconds = function()
          return 30
        end,
      })
      p.setExternalPreview(entry({}))
    end)
    rawset(_G, "C_Timer", savedTimer)
    assert(ok, err)
    assert(timers == 0, "an external preview never schedules auto-dismiss, got " .. timers)
  end

  local function test_own_left_click_still_does_nothing()
    local p = build()
    p.setIncomingPreview("A", "hi", "MAGE")
    mouseUp(p, "LeftButton")
    assert(p.frame.shown == true, "left click on the own preview keeps it")
  end

  local function test_own_preview_replaces_external()
    local p, state = build()
    local log = {}
    p.setExternalPreview(entry(log))
    p.setIncomingPreview("A", "hi")
    assert(p.isExternalShown() == false, "own preview takes the slot")
    mouseUp(p, "RightButton")
    assert(state.ownDismissed == 1, "right click now dismisses the own preview")
    assert(not has(log, "dismiss"), "the replaced external is not dismissed")
  end

  local function test_click_that_shows_another_preview_keeps_it()
    local p = build()
    local second = entry({}, "Second")
    local first = entry({})
    first.onClick = function()
      p.setExternalPreview(second)
    end
    p.setExternalPreview(first)
    mouseUp(p, "LeftButton")
    assert(p.frame.shown == true and p.senderLabel.text == "Second", "a preview shown from onClick stays up")
  end

  local function test_nil_hides_without_callbacks()
    local p = build()
    local log = {}
    p.setExternalPreview(entry(log))
    p.setExternalPreview(nil)
    assert(p.frame.shown == false, "nil hides the external")
    assert(not has(log, "click") and not has(log, "dismiss"), "nil runs no callbacks, got " .. joined(log))
  end

  local function test_on_external_changed_fires_once_per_entry_change()
    local changes = 0
    local p = build({
      onExternalChanged = function()
        changes = changes + 1
      end,
    })
    local e1, e2, e3 = entry({}), entry({}), entry({})
    p.setExternalPreview(e1)
    assert(changes == 1, "a new entry fires")
    p.setExternalPreview(e1)
    assert(changes == 1, "the same entry does not fire")
    mouseUp(p, "RightButton")
    assert(changes == 2, "dismiss clears it")
    p.setExternalPreview(e2)
    p.setIncomingPreview("Own", "hi")
    assert(changes == 4, "an own whisper drops it")
    p.setExternalPreview(e3)
    p.setExternalPreview(nil)
    assert(changes == 6, "nil drops it")
    p.setIncomingPreview("Own", "again")
    assert(changes == 6, "own previews alone never fire")
    p.setIncomingPreview("Own", "")
    assert(changes == 6, "clearing an own preview never fires")
  end

  local function test_on_external_changed_runs_after_the_frame_changes()
    local seen = {}
    local p
    p = build({
      onExternalChanged = function()
        seen[#seen + 1] = p.isExternalShown()
      end,
    })
    p.setExternalPreview(entry({}))
    p.setExternalPreview(nil)
    assert(seen[1] == true and seen[2] == false, "the hook sees the frame already shown, then hidden")
  end

  test_on_external_changed_fires_once_per_entry_change()
  test_on_external_changed_runs_after_the_frame_changes()
  test_external_shows_labels_and_runs_on_shown_once()
  test_same_entry_again_does_not_re_run_on_shown()
  test_new_entry_while_visible_runs_its_on_shown()
  test_on_shown_runs_again_when_the_frame_shows_again()
  test_left_click_runs_on_click_then_hides()
  test_right_click_dismisses_without_acknowledging_own()
  test_x_button_dismisses_without_acknowledging_own()
  test_no_auto_dismiss_timer()
  test_own_left_click_still_does_nothing()
  test_own_preview_replaces_external()
  test_click_that_shows_another_preview_keeps_it()
  test_nil_hides_without_callbacks()
end
