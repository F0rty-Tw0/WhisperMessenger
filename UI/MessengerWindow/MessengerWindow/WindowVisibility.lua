local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local WindowVisibility = {}

function WindowVisibility.Create(options)
  local optionsPanel = options.optionsPanel
  local contactsPane = options.contactsPane
  local contentPane = options.contentPane
  local onOptionsVisibilityChanged = options.onOptionsVisibilityChanged

  local function setOptionsVisible(nextVisible)
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
    closeWindow = closeWindow,
  }
end

ns.MessengerWindowWindowVisibility = WindowVisibility

return WindowVisibility
