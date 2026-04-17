local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local TableUtils = ns.TableUtils or require("WhisperMessenger.Util.TableUtils")
local clamp = TableUtils.clamp

local Metrics = ns.ScrollViewMetrics or require("WhisperMessenger.UI.ScrollView.Metrics")

local Navigation = {}

function Navigation.Sync(view, skipValueSync)
  if view == nil or view.scrollFrame == nil or view.scrollBar == nil then
    return 0
  end

  Metrics._captureLiveGeometry(view)

  local range = Metrics.GetRange(view)
  local hasOverflow = range > 0
  Metrics._applyViewportLayout(view, hasOverflow)
  range = Metrics.GetRange(view)

  if view.scrollBar.SetMinMaxValues then
    view.scrollBar:SetMinMaxValues(0, range)
  end

  if view.scrollBar.SetValueStep then
    view.scrollBar:SetValueStep(view.step or 1)
  end

  -- When called from SetVerticalScroll, skip the value reset — the caller
  -- will set the correct value immediately after. Without this guard, dragging
  -- the Slider fights: Sync pushes the thumb to the *old* position while the
  -- user drags to a *new* one, causing a jump loop.
  if not skipValueSync then
    local current = clamp(Metrics.GetOffset(view), 0, range)

    view.syncingScrollBar = true
    if view.scrollBar.SetValue then
      view.scrollBar:SetValue(current)
    else
      view.scrollBar.value = current
    end
    view.syncingScrollBar = false
  end

  -- Show/hide both the scrollBar and its thumb. Hiding scrollBar should
  -- propagate to its child thumb in production, but the textured Blizzard
  -- knob (Stage 2B) was leaking through the parent hide — we now flip the
  -- thumb explicitly to make the contract unambiguous in both fake_ui and
  -- live WoW.
  if hasOverflow then
    if view.scrollBar.Show then
      view.scrollBar:Show()
    end
    if view.scrollBar.thumb and view.scrollBar.thumb.Show then
      view.scrollBar.thumb:Show()
    end
  else
    if view.scrollBar.Hide then
      view.scrollBar:Hide()
    end
    if view.scrollBar.thumb and view.scrollBar.thumb.Hide then
      view.scrollBar.thumb:Hide()
    end
  end

  return range
end

function Navigation.SetVerticalScroll(view, offset)
  if view == nil or view.scrollFrame == nil then
    return 0
  end

  local range = Navigation.Sync(view, true)
  local clamped = clamp(offset or 0, 0, range)

  view.syncingScrollFrame = true
  if view.scrollFrame.SetVerticalScroll then
    view.scrollFrame:SetVerticalScroll(clamped)
  else
    view.scrollFrame.verticalScroll = clamped
  end
  view.syncingScrollFrame = false

  view.syncingScrollBar = true
  if view.scrollBar and view.scrollBar.SetValue then
    view.scrollBar:SetValue(clamped)
  elseif view.scrollBar then
    view.scrollBar.value = clamped
  end
  view.syncingScrollBar = false

  return clamped
end

function Navigation.ScrollBy(view, delta)
  return Navigation.SetVerticalScroll(view, Metrics.GetOffset(view) + (delta or 0))
end

local function wrapScriptWithCallback(target, scriptName, callback)
  if target == nil or type(target.SetScript) ~= "function" then
    return
  end

  local original = nil
  if type(target.GetScript) == "function" then
    original = target:GetScript(scriptName)
  end

  target:SetScript(scriptName, function(...)
    if original then
      original(...)
    end
    callback()
  end)
end

function Navigation.InstallPostScrollHook(view, callback)
  if view == nil or type(callback) ~= "function" then
    return
  end

  wrapScriptWithCallback(view.scrollFrame, "OnMouseWheel", callback)
  wrapScriptWithCallback(view.scrollBar, "OnValueChanged", callback)
end

ns.ScrollViewNavigation = Navigation
return Navigation
