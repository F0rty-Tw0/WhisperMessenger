local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local WindowBounds = ns.MessengerWindowWindowBounds or require("WhisperMessenger.UI.MessengerWindow.WindowBounds")
local WindowScale = ns.MessengerWindowWindowScale or require("WhisperMessenger.UI.MessengerWindow.WindowScale")
local Shapes = ns.UIHelpersShapes or require("WhisperMessenger.UI.Helpers.Shapes")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local BlizzardChrome = ns.MessengerWindowChromeBuilderBlizzard or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.BlizzardChrome")
local RetailChrome = ns.MessengerWindowChromeBuilderRetail or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.RetailChrome")
local ModernChrome = ns.MessengerWindowChromeBuilderModern or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.ModernChrome")
local Buttons = ns.MessengerWindowChromeBuilderButtons or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.Buttons")
local ResizeGrip = ns.MessengerWindowChromeBuilderResizeGrip or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.ResizeGrip")
local PatchNotesButton = ns.MessengerWindowChromeBuilderPatchNotesButton
  or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.PatchNotesButton")
local MarkAllReadButton = ns.MessengerWindowChromeBuilderMarkAllReadButton
  or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.MarkAllReadButton")
local TitleBarLayout = ns.MessengerWindowChromeBuilderTitleBarLayout or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.TitleBarLayout")
local ChromeBuilder = {}

local function applyResizeBounds(frame, parent, theme, windowScale, contactsCollapsed)
  local minWidth, minHeight, maxWidth, maxHeight = WindowBounds.GetResizeBounds(parent, theme, windowScale, contactsCollapsed)
  if frame.SetResizeBounds then
    frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
  else
    frame:SetMinResize(minWidth, minHeight)
    if frame.SetMaxResize and maxWidth and maxHeight then
      frame:SetMaxResize(maxWidth, maxHeight)
    end
  end
end

-- Retail HUD: ButtonFrameTemplate. A client that can't build it drops the
-- session to the Classic HUD so every metric matches the frame on screen.
local function createRetailFrame(factory, parent)
  local frame = UIHelpers.createTemplatedFrame(factory, "Frame", "WhisperMessengerWindow", parent, "ButtonFrameTemplate")
  if not frame then
    Hud.Configure("classic")
  end
  return frame
end

local function createWindowFrame(factory, parent, useBlizzardChrome)
  if not useBlizzardChrome then
    -- BackdropTemplate mixin makes :SetBackdrop available on Retail 9.0+
    -- (the modern path doesn't use SetBackdrop today, but keeping the mixin
    -- lets us paint a backdrop later without recreating the frame).
    return factory.CreateFrame("Frame", "WhisperMessengerWindow", parent, "BackdropTemplate"), ModernChrome
  end
  local retailFrame = Hud.IsRetail() and createRetailFrame(factory, parent)
  if retailFrame then
    return retailFrame, RetailChrome
  end
  return factory.CreateFrame("Frame", "WhisperMessengerWindow", parent, "BasicFrameTemplateWithInset"), BlizzardChrome
end

-- ChromeBuilder builds the messenger window with one of three chrome paths,
-- chosen by the Native WoW HUD style (independent of the color preset):
--
--   * Classic HUD: frame uses BasicFrameTemplateWithInset.
--
--   * Retail HUD: frame uses ButtonFrameTemplate (round portrait, modern
--     title bar); falls back to the Classic HUD when the client lacks it.
--
--     In both HUD paths the border, close X, insets, and centered title come
--     from the Blizzard template — we don't paint them ourselves.
--
--   * Custom chrome (default): frame uses BackdropTemplate. We paint a flat
--     background, our own title bar with header bg, a window edge hairline,
--     and a custom close button.
--
-- Returns: { frame, background, title, newConversationButton, markAllReadButton,
--   patchNotesButton, closeButton, optionsButton, backButton, resizeGrip,
--   applyTheme, refreshScale, setOptionsActive, setPatchNotesGlow,
--   setMarkAllReadShown } in both cases. Non-chrome
-- layout (rows, composer margins, content positioning) is shared and
-- applied universally by callers regardless of which chrome was built.
function ChromeBuilder.Build(factory, parent, initialState, options)
  options = options or {}
  local normalizedWindowScale = WindowScale.Normalize(options.windowScale)

  -- Chrome choice is now controlled by an explicit setting passed in
  -- `options.useNativeChrome` (independent of the color preset). Falls
  -- back to false (modern chrome) if the caller didn't pass it.
  local useBlizzardChrome = options.useNativeChrome == true

  local frame, chromeBranch = createWindowFrame(factory, parent, useBlizzardChrome)
  frame:SetScale(normalizedWindowScale)

  frame:SetSize(initialState.width or Theme.WINDOW_WIDTH, initialState.height or Theme.WINDOW_HEIGHT)
  frame:SetPoint(
    initialState.anchorPoint or "CENTER",
    parent,
    initialState.relativePoint or initialState.anchorPoint or "CENTER",
    initialState.x or 0,
    initialState.y or 0
  )
  if frame.SetFrameStrata then
    frame:SetFrameStrata("MEDIUM")
  end
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetResizable(true)
  -- The rail lets the window shrink further (see WindowBounds).
  local contactsCollapsed = initialState.contactsCollapsed == true
  local currentScale = normalizedWindowScale
  applyResizeBounds(frame, parent, Theme, currentScale, contactsCollapsed)
  frame:SetClampedToScreen(true)

  local frameName = frame.GetName and frame:GetName() or frame.name
  if type(_G.UISpecialFrames) == "table" and frameName ~= nil then
    local alreadyRegistered = false
    for _, specialFrameName in ipairs(_G.UISpecialFrames) do
      if specialFrameName == frameName then
        alreadyRegistered = true
        break
      end
    end
    if not alreadyRegistered then
      table.insert(_G.UISpecialFrames, frameName)
    end
  end

  if frame.SetAlpha then
    frame:SetAlpha(Theme.WINDOW_IDLE_ALPHA)
  else
    frame.alpha = Theme.WINDOW_IDLE_ALPHA
  end

  -- Chrome differs by setting (Retail or Classic template vs custom chrome).
  local chrome = chromeBranch.Build(factory, frame, options, Theme)
  local title, closeButton = chrome.title, chrome.closeButton
  local applyChromePaint = chrome.applyChromePaint

  local newConv = Buttons.CreateNewConversation(factory, frame, Theme)
  local markAllRead = MarkAllReadButton.Create(factory, frame, Theme, options.onMarkAllRead)
  local patchNotes = PatchNotesButton.Create(factory, frame, Theme)
  local options_ = Buttons.CreateOptions(factory, frame, Theme)
  local back = Buttons.CreateBack(factory, frame, Theme)
  local resize = ResizeGrip.Create(factory, frame)
  local titleBarParts = {
    frame = frame,
    titleBar = chrome.titleBar,
    title = title,
    closeButton = closeButton,
    newConversationButton = newConv.button,
    markAllReadButton = markAllRead.button,
    patchNotesButton = patchNotes.button,
    optionsButton = options_.button,
    backButton = back.button,
    blizzardChrome = useBlizzardChrome,
    retailChrome = chromeBranch == RetailChrome,
  }

  local function applyTheme(activeTheme)
    activeTheme = activeTheme or Theme
    TitleBarLayout.Apply(titleBarParts, activeTheme)
    applyChromePaint(activeTheme)
    options_.applyTheme(activeTheme)
    back.applyTheme(activeTheme)
    newConv.applyTheme(activeTheme)
    markAllRead.applyTheme(activeTheme)
    patchNotes.applyTheme(activeTheme)
    resize.applyTheme(activeTheme)
  end

  local function refreshScale(nextScale)
    local normalizedScale = WindowScale.Normalize(nextScale)
    frame:SetScale(normalizedScale)
    Shapes.refreshHairlines()
    currentScale = normalizedScale
    applyResizeBounds(frame, parent, Theme, normalizedScale, contactsCollapsed)
    return normalizedScale
  end

  local function setContactsCollapsed(collapsed)
    contactsCollapsed = collapsed == true
    applyResizeBounds(frame, parent, Theme, currentScale, contactsCollapsed)
  end

  applyTheme(Theme)
  local function setOptionsActive(active)
    options_.setActive(active)
    if active then
      back.button:Show()
    else
      back.button:Hide()
    end
  end

  return {
    frame = frame,
    background = chrome.background,
    title = title,
    newConversationButton = newConv.button,
    markAllReadButton = markAllRead.button,
    patchNotesButton = patchNotes.button,
    closeButton = closeButton,
    optionsButton = options_.button,
    backButton = back.button,
    resizeGrip = resize.grip,
    applyTheme = applyTheme,
    refreshScale = refreshScale,
    setContactsCollapsed = setContactsCollapsed,
    setOptionsActive = setOptionsActive,
    setPatchNotesGlow = patchNotes.setGlowing,
    setMarkAllReadShown = markAllRead.setShown,
    titleBar = chrome.titleBar,
  }
end

ns.MessengerWindowChromeBuilder = ChromeBuilder

return ChromeBuilder
