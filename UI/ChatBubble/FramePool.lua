local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ReactionPicker = ns.ChatBubbleReactionPicker or require("WhisperMessenger.UI.ChatBubble.ReactionPicker")
local select = select

local FramePool = {}

function FramePool.initPool(contentFrame)
  if not contentFrame._freeFrames then
    contentFrame._freeFrames = {}
    contentFrame._activeFrames = {}
    -- Migrate legacy _bubblePool if present
    if contentFrame._bubblePool then
      for _, f in ipairs(contentFrame._bubblePool) do
        if f.Hide then
          f:Hide()
        end
        table.insert(contentFrame._freeFrames, f)
      end
      contentFrame._bubblePool = nil
    end
  end
end

function FramePool.acquireFrame(realFactory, contentFrame, frameType, parent)
  local free = contentFrame._freeFrames
  local frame
  for index = #free, 1, -1 do
    local candidate = free[index]
    if candidate._wmPoolFrameType == frameType or (candidate._wmPoolFrameType == nil and frameType == "Frame") then
      frame = table.remove(free, index)
      break
    end
  end
  if frame then
    if frame.Show then
      frame:Show()
    end
    if frame.ClearAllPoints then
      frame:ClearAllPoints()
    end
  else
    frame = realFactory.CreateFrame(frameType, nil, parent)
    frame._wmPoolFrameType = frameType
  end
  table.insert(contentFrame._activeFrames, frame)
  return frame
end

function FramePool.getFactory(realFactory, contentFrame)
  local state = contentFrame._wmPooledFactoryState
  if state == nil then
    state = {
      contentFrame = contentFrame,
      realFactory = realFactory,
    }
    contentFrame._wmPooledFactoryState = state
    contentFrame._wmPooledFactory = {
      CreateFrame = function(frameType, _name, parent)
        return FramePool.acquireFrame(state.realFactory, state.contentFrame, frameType, parent)
      end,
    }
  else
    state.realFactory = realFactory
  end
  return contentFrame._wmPooledFactory
end

local function hideRegions(...)
  for index = 1, select("#", ...) do
    local region = select(index, ...)
    if region and region.Hide then
      region:Hide()
    end
  end
end

function FramePool.hideAllRegions(frame)
  if frame.GetRegions then
    hideRegions(frame:GetRegions())
  end
  if frame.GetChildren then
    hideRegions(frame:GetChildren())
  end
end

-- Interactive scripts wired by pooled chat widgets. Cleared on release so a
-- recycled frame cannot replay its old role's handlers in a new role.
local POOLED_INTERACTIVE_SCRIPTS = {
  "OnEnter",
  "OnLeave",
  "OnMouseDown",
  "OnMouseUp",
}

local function clearInteractiveScripts(frame)
  if type(frame.SetScript) ~= "function" then
    return
  end
  for _, name in ipairs(POOLED_INTERACTIVE_SCRIPTS) do
    frame:SetScript(name, nil)
  end
  if frame._wmPoolFrameType == "Button" then
    frame:SetScript("OnDoubleClick", nil)
    frame:SetScript("OnClick", nil)
  end
end
local function clearReactionState(frame)
  local reactionFrame = frame._reactionFrame
  if reactionFrame then
    if reactionFrame._reactionTooltipOwned and _G.GameTooltip and type(_G.GameTooltip.Hide) == "function" then
      _G.GameTooltip:Hide()
    end
    reactionFrame._reactionTooltipOwned = nil
    clearInteractiveScripts(reactionFrame)
    if reactionFrame.Hide then
      reactionFrame:Hide()
    end
    if reactionFrame.ClearAllPoints then
      reactionFrame:ClearAllPoints()
    end
  end
  local texture = frame._reactionTexture
  if texture then
    if texture.SetTexture then
      texture:SetTexture(nil)
    end
    if texture.SetTexCoord then
      texture:SetTexCoord(0, 1, 0, 1)
    end
    if texture.Hide then
      texture:Hide()
    end
  end
  frame._reactionKey = nil
  if reactionFrame then
    reactionFrame._wmReactionKey = nil
  end

  local pickerFrame = type(ReactionPicker.GetFrame) == "function" and ReactionPicker.GetFrame() or nil
  if pickerFrame and pickerFrame._anchor == frame and type(ReactionPicker.Close) == "function" then
    ReactionPicker.Close()
  end
end

local function clearBindingState(frame)
  frame._wmMessage = nil
  frame._wmVirtualIndex = nil
  frame._wmOnRevealCensored = nil
  frame._wmOnReact = nil
  frame._wmCanReact = nil
  frame._wmPersistentFactory = nil
  frame._wmOpenedOnMouseDown = nil
  frame._wmPlayerMenuMessage = nil
  frame._wmPlayerMenuOpener = nil

  local menuOptions = frame._wmContextMenuOptions
  if menuOptions then
    menuOptions.message = nil
    menuOptions.onReact = nil
    menuOptions.canReact = nil
    menuOptions.factory = nil
  end
  local copyButton = frame._copyButton
  if copyButton then
    copyButton._wmCopyMessage = nil
    copyButton._wmCopyText = nil
  end
end

function FramePool.releaseAll(contentFrame)
  local active = contentFrame._activeFrames
  local free = contentFrame._freeFrames
  for i = #active, 1, -1 do
    local f = active[i]
    FramePool.hideAllRegions(f)
    clearInteractiveScripts(f)
    clearReactionState(f)
    clearBindingState(f)
    if f.Hide then
      f:Hide()
    end
    if f.ClearAllPoints then
      f:ClearAllPoints()
    end
    table.insert(free, f)
    active[i] = nil
  end
end

ns.ChatBubbleFramePool = FramePool
return FramePool
