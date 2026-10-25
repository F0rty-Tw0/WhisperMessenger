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
  local onConversationUncovered = options.onConversationUncovered
  local openPanel = nil
  local closing = false

  -- True while the selected chat's panes are on screen: no addon panel and no
  -- options pane covers them.
  local function isConversationPaneShown()
    return openPanel == nil and not optionsPanel:IsShown()
  end

  -- The chat just came back on screen (a panel or the options pane closed).
  -- Not while the window itself closes, and not when the covering pane only
  -- changed from one kind to the other.
  local function reportIfUncovered(wasCovered, quiet)
    if not wasCovered or quiet or closing or not onConversationUncovered then
      return
    end
    if isConversationPaneShown() then
      onConversationUncovered()
    end
  end

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

  local function applyOptionsVisible(nextVisible)
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

  -- quiet: as for setPanelVisible.
  local function setOptionsVisible(nextVisible, quiet)
    local wasCovered = not isConversationPaneShown()
    applyOptionsVisible(nextVisible)
    reportIfUncovered(wasCovered, quiet)
  end

  -- key opens that panel (closing options or another panel first); nil
  -- closes the open one. Nil with nothing open touches nothing, so a window
  -- hide leaves the options pane as it was.
  local function applyPanelVisible(key)
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
    -- Tracked before the host runs the panel's onShow: a panel that opens
    -- another one from there closes this one first, so one stays tracked.
    openPanel = key
    if not panelHost.show(key) then
      if openPanel == key then
        openPanel = nil
      end
      setPanesAndInsets(true)
      return false
    end
    if openPanel ~= key then
      return true
    end
    setPanesAndInsets(false)
    if onPanelVisibilityChanged then
      onPanelVisibilityChanged(true, key)
    end
    return true
  end

  -- quiet: close without the uncover report (a mode-tab click that moves to
  -- another tab selects that tab's chat itself).
  local function setPanelVisible(key, quiet)
    local wasCovered = not isConversationPaneShown()
    local result = applyPanelVisible(key)
    reportIfUncovered(wasCovered, quiet)
    return result
  end

  local function getVisiblePanel()
    return openPanel
  end

  -- The options pane and any panel close first, but the chat does not come
  -- back on screen: the window goes with them. A throwing onClose still
  -- clears the guard, then the error carries on.
  local function closeWindow()
    closing = true
    local ok, err = pcall(function()
      setOptionsVisible(false)
      if options.onClose then
        options.onClose()
      elseif options.frame and options.frame.Hide then
        options.frame:Hide()
      end
    end)
    closing = false
    if not ok then
      error(err, 0)
    end
  end

  return {
    setOptionsVisible = setOptionsVisible,
    setPanelVisible = setPanelVisible,
    getVisiblePanel = getVisiblePanel,
    isConversationPaneShown = isConversationPaneShown,
    closeWindow = closeWindow,
  }
end

ns.MessengerWindowWindowVisibility = WindowVisibility

return WindowVisibility
