local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PanelHost = ns.MessengerWindowPanelHost or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PanelHost")
local WindowVisibility = ns.MessengerWindowWindowVisibility or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowVisibility")

local PanelWiring = {}

local NO_TAB = {
  setBadge = function() end,
}

-- Builds the addon-panel host and the window visibility controller that
-- switches between the panes, the options pane and a panel.
function PanelWiring.Create(options)
  local frame = options.frame
  local layout = options.layout
  local chrome = options.chrome
  local tabToggle = options.tabToggle
  local getContactsRail = options.getContactsRail
  local onPanelShown = options.onPanelShown

  local leftInset = options.theme.LAYOUT.CONTACTS_PANE_LEFT_INSET
  local windowVisibility -- forward declaration (the panel tabs open through it)
  local panelHost = PanelHost.Create({
    factory = options.factory,
    parent = frame.contentArea or frame,
    nativeChrome = layout.nativeChrome == true,
    theme = options.theme,
    listWidth = (layout.contactsWidth or 0) + leftInset,
    addTab = function(key, title, onClick)
      if tabToggle == nil then
        return NO_TAB
      end
      return tabToggle.addPanelTab(key, title, onClick)
    end,
    -- Opens, never toggles: clicking the open panel's tab does nothing.
    onTabClick = function(key)
      windowVisibility.setPanelVisible(key)
    end,
  })
  windowVisibility = WindowVisibility.Create({
    optionsPanel = layout.optionsPanel,
    contactsPane = layout.contactsPane,
    contentPane = layout.contentPane,
    frame = frame,
    panelHost = panelHost,
    onPanelVisibilityChanged = function(visible, key)
      chrome.setBackVisible(visible)
      if tabToggle then
        tabToggle.setSelectedPanel(visible and key or nil)
      end
      if visible and onPanelShown then
        onPanelShown(key)
      end
    end,
    onClose = options.onClose,
    onConversationUncovered = options.onConversationUncovered,
    onOptionsVisibilityChanged = function(visible)
      chrome.setOptionsActive(visible)
      local contactsRail = getContactsRail()
      if contactsRail then
        contactsRail.setOptionsVisible(visible)
      end
      if tabToggle then
        tabToggle.setOptionsShown(visible)
      end
    end,
  })

  -- A mode-tab click leaves the open panel, even for the current mode. A
  -- different mode selects its own chat next, so only the current mode's tab
  -- reports this chat as back on screen.
  if tabToggle then
    tabToggle.setModeClickHandler(function(mode)
      windowVisibility.setPanelVisible(nil, mode ~= tabToggle.getMode())
    end)
  end

  -- Call after LifecycleWiring: its SetScript("OnHide") would drop an earlier hook.
  local function hookWindowHide()
    if not frame.HookScript then
      return
    end
    -- Not when only the parent hid (Alt+Z): the panel is still there.
    frame:HookScript("OnHide", function()
      if not frame:IsShown() then
        windowVisibility.setPanelVisible(nil, true)
      end
    end)
  end

  return {
    panelHost = panelHost,
    windowVisibility = windowVisibility,
    hookWindowHide = hookWindowHide,
    -- The contacts pane's live width changed: the panel's divider moved with it.
    onContactsWidth = function(width)
      panelHost.setSplit(width + leftInset)
    end,
  }
end

ns.MessengerWindowPanelWiring = PanelWiring

return PanelWiring
