local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local WindowVisibility = {}

-- The options pane and an addon panel (options.panelHost) each replace the
-- contacts and conversation panes; at most one of them shows at a time.
function WindowVisibility.Create(options)
  local optionsPanel = options.optionsPanel
  local contactsPane = options.contactsPane
  local contentPane = options.contentPane
  local frame = options.frame
  local panelHost = options.panelHost
  local onOptionsVisibilityChanged = options.onOptionsVisibilityChanged
  local onPanelVisibilityChanged = options.onPanelVisibilityChanged
  local openPanel = nil

  local function setInsetShown(inset, shown)
    if inset and inset.SetShown then
      inset:SetShown(shown)
    end
  end

  -- The Retail HUD's panel insets paint the pane backgrounds.
  local function setPanesAndInsets(shown)
    contactsPane:SetShown(shown)
    contentPane:SetShown(shown)
    if frame then
      setInsetShown(frame.contactsInset, shown)
      setInsetShown(frame.conversationInset, shown)
    end
  end

  local function closeOpenPanel()
    if openPanel == nil then
      return false
    end
    local key = openPanel
    openPanel = nil
    panelHost.hide(key)
    setPanesAndInsets(true)
    if onPanelVisibilityChanged then
      onPanelVisibilityChanged(false)
    end
    return true
  end

  local function setOptionsVisible(nextVisible)
    closeOpenPanel()
    if nextVisible then
      optionsPanel:Show()
      contactsPane:Hide()
      contentPane:Hide()
      if onOptionsVisibilityChanged then
        onOptionsVisibilityChanged(true)
      end
      return
    end

    optionsPanel:Hide()
    contactsPane:Show()
    contentPane:Show()
    if onOptionsVisibilityChanged then
      onOptionsVisibilityChanged(false)
    end
  end

  -- key opens that panel (closing options or another panel first); nil
  -- closes the open one. Nil with nothing open touches nothing, so a window
  -- hide leaves the options pane as it was.
  local function setPanelVisible(key)
    if key == nil then
      return closeOpenPanel()
    end
    if panelHost == nil then
      return false
    end
    if optionsPanel:IsShown() then
      optionsPanel:Hide()
      if onOptionsVisibilityChanged then
        onOptionsVisibilityChanged(false)
      end
    end
    if openPanel ~= nil and openPanel ~= key then
      closeOpenPanel()
    end
    if openPanel == key then
      return true
    end
    if not panelHost.show(key) then
      setPanesAndInsets(true)
      return false
    end
    openPanel = key
    setPanesAndInsets(false)
    if onPanelVisibilityChanged then
      onPanelVisibilityChanged(true)
    end
    return true
  end

  local function getVisiblePanel()
    return openPanel
  end

  local function togglePanel(key)
    if openPanel == key then
      return setPanelVisible(nil)
    end
    return setPanelVisible(key)
  end

  local function closeWindow()
    setOptionsVisible(false)
    if options.onClose then
      options.onClose()
    elseif options.frame and options.frame.Hide then
      options.frame:Hide()
    end
  end

  return {
    setOptionsVisible = setOptionsVisible,
    setPanelVisible = setPanelVisible,
    getVisiblePanel = getVisiblePanel,
    togglePanel = togglePanel,
    closeWindow = closeWindow,
  }
end

ns.MessengerWindowWindowVisibility = WindowVisibility

return WindowVisibility
