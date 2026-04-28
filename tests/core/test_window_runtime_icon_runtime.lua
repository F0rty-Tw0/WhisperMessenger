local IconRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconRuntime")

return function()
  local createOptions
  local copiedIconState
  local acknowledgedContacts
  local refreshes = 0
  local toggles = 0
  local unreadInputs = {}
  local previewInputs = {}
  local contacts = {
    { conversationKey = "wow::WOW::jaina", unreadCount = 2, channel = "WOW" },
    { conversationKey = "party::jaina", unreadCount = 7, channel = "PARTY" },
  }

  local accountState = {
    settings = {
      iconSize = 44,
      showUnreadBadge = false,
      badgePulse = false,
      iconDesaturated = true,
      widgetPreviewAutoDismissSeconds = "12",
      widgetPreviewPosition = "left",
    },
  }
  local characterState = {
    icon = { anchorPoint = "CENTER", x = 1 },
  }

  local icon = IconRuntime.Create({
    accountState = accountState,
    characterState = characterState,
    uiFactory = { tag = "factory" },
    toggleIcon = {
      Create = function(factory, options)
        assert(factory.tag == "factory", "icon should receive ui factory")
        createOptions = options
        return {
          setUnreadCount = function(count)
            unreadInputs[#unreadInputs + 1] = count
          end,
          setIncomingPreview = function(senderName, messageText, classTag)
            previewInputs[#previewInputs + 1] = { senderName, messageText, classTag }
          end,
        }
      end,
    },
    tableUtils = {
      copyState = function(value)
        copiedIconState = value
        local copy = {}
        for key, nextValue in pairs(value) do
          copy[key] = nextValue
        end
        return copy
      end,
    },
    badgeFilter = {
      SumWhisperUnread = function(nextContacts)
        assert(nextContacts == contacts, "unread setup should use built contacts")
        return 2
      end,
    },
    buildContacts = function()
      return contacts
    end,
    buildLatestIncomingPreview = function(nextContacts)
      assert(nextContacts == contacts, "preview setup should use built contacts")
      return { senderName = "Jaina", messageText = "Need assistance?", classTag = "MAGE" }
    end,
    acknowledgeLatestWidgetPreview = function(nextContacts)
      acknowledgedContacts = nextContacts
    end,
    refreshWindow = function()
      refreshes = refreshes + 1
      return "refreshed"
    end,
    onToggle = function()
      toggles = toggles + 1
      return "toggled"
    end,
  })

  assert(icon ~= nil, "IconRuntime should return icon")
  assert(createOptions.state == characterState.icon, "icon should receive persisted icon state")
  assert(createOptions.iconSize == 44, "icon should receive saved icon size")
  assert(createOptions.getShowUnreadBadge() == false, "showUnreadBadge=false should hide badge")
  assert(createOptions.getBadgePulse() == false, "badgePulse=false should disable pulse")
  assert(createOptions.getIconDesaturated() == true, "iconDesaturated=true should desaturate icon")
  assert(createOptions.getPreviewAutoDismissSeconds() == 12, "auto-dismiss should parse numeric setting")
  assert(createOptions.getPreviewPosition() == "left", "preview position should use saved string")
  assert(createOptions.onToggle() == "toggled" and toggles == 1, "icon toggle should call supplied toggle")

  createOptions.onPositionChanged({ anchorPoint = "TOPLEFT", x = 20 })
  assert(copiedIconState.x == 20, "position change should copy next icon state")
  assert(characterState.icon.x == 20, "position change should persist copied icon state")

  assert(createOptions.onDismissPreview() == "refreshed", "dismiss preview should refresh window")
  assert(acknowledgedContacts == contacts, "dismiss preview should acknowledge current contacts")
  assert(refreshes == 1, "dismiss preview should refresh once")

  assert(unreadInputs[1] == 2, "initial setup should set whisper unread count")
  assert(previewInputs[1][1] == "Jaina", "initial setup should set preview sender")
  assert(previewInputs[1][2] == "Need assistance?", "initial setup should set preview text")
  assert(previewInputs[1][3] == "MAGE", "initial setup should set preview class")

  accountState.settings.widgetPreviewAutoDismissSeconds = nil
  accountState.settings.widgetPreviewPosition = ""
  assert(createOptions.getPreviewAutoDismissSeconds() == 30, "nil auto-dismiss should default to 30")
  assert(createOptions.getPreviewPosition() == "right", "blank preview position should default right")

  accountState.settings.widgetPreviewAutoDismissSeconds = "bad"
  assert(createOptions.getPreviewAutoDismissSeconds() == 0, "invalid auto-dismiss should coerce to 0")
end
