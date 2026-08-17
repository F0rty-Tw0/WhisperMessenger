local IconRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconRuntime")

local function capturePositionOptions(accountState, characterState)
  local createOptions
  IconRuntime.Create({
    accountState = accountState,
    characterState = characterState,
    toggleIcon = {
      Create = function(_, options)
        createOptions = options
        return {}
      end,
    },
    tableUtils = {
      copyState = function(value)
        local copy = {}
        for key, nextValue in pairs(value) do
          copy[key] = nextValue
        end
        return copy
      end,
    },
  })
  return createOptions
end

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
      shareWidgetPosition = false,
      iconSize = 44,
      showUnreadBadge = false,
      badgePulse = false,
      iconDesaturated = true,
      transparentWidget = true,
      widgetTransparency = 0.4,
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
  assert(createOptions.getTransparentWidget == nil, "IconRuntime should not expose getTransparentWidget")
  assert(createOptions.getWidgetTransparency() == 0.4, "widgetTransparency should use saved numeric setting")
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
  accountState.settings.widgetTransparency = nil
  assert(createOptions.getPreviewAutoDismissSeconds() == 30, "nil auto-dismiss should default to 30")
  assert(createOptions.getPreviewPosition() == "right", "blank preview position should default right")
  assert(createOptions.getWidgetTransparency() == 0, "unknown transparentWidget field should not change the default transparency")

  accountState.settings.widgetPreviewAutoDismissSeconds = "bad"
  assert(createOptions.getPreviewAutoDismissSeconds() == 0, "invalid auto-dismiss should coerce to 0")
  accountState.settings.transparentWidget = false
  assert(createOptions.getWidgetTransparency() == 0, "fresh settings should default widget transparency to 0")

  -- test_startup_with_sharing_uses_the_account_position
  do
    local localPosition = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 3, y = 4 }
    local sharedPosition = { anchorPoint = "TOP", relativePoint = "TOP", x = 30, y = -40 }
    local sharedAccountState = {
      settings = { shareWidgetPosition = true },
      sharedWidgetPosition = sharedPosition,
    }

    local positionOptions = capturePositionOptions(sharedAccountState, { icon = localPosition })

    assert(positionOptions.state == sharedPosition, "sharing startup should create the widget at the account position")
  end

  -- test_startup_with_sharing_seeds_a_missing_account_position
  do
    local localPosition = { anchorPoint = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT", x = -13, y = 17 }
    local sharedAccountState = {
      settings = { shareWidgetPosition = true },
    }

    local positionOptions = capturePositionOptions(sharedAccountState, { icon = localPosition })

    local seededPosition = sharedAccountState.sharedWidgetPosition
    assert(seededPosition ~= nil, "sharing startup should seed a missing account position")
    assert(seededPosition ~= localPosition, "sharing startup should copy rather than alias the character position")
    assert(
      seededPosition.anchorPoint == "BOTTOMRIGHT"
        and seededPosition.relativePoint == "BOTTOMRIGHT"
        and seededPosition.x == -13
        and seededPosition.y == 17,
      "sharing startup should seed the exact character position"
    )
    assert(positionOptions.state == seededPosition, "sharing startup should create the widget from the seeded account position")
  end

  -- test_drag_with_sharing_updates_only_the_account_position
  do
    local localPosition = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 1, y = 2 }
    local sharedAccountState = {
      settings = { shareWidgetPosition = true },
      sharedWidgetPosition = { anchorPoint = "TOP", relativePoint = "TOP", x = 5, y = -6 },
    }
    local positionOptions = capturePositionOptions(sharedAccountState, { icon = localPosition })

    positionOptions.onPositionChanged({ anchorPoint = "LEFT", relativePoint = "LEFT", x = 21, y = 22 })

    local persistedPosition = sharedAccountState.sharedWidgetPosition
    assert(
      persistedPosition.anchorPoint == "LEFT"
        and persistedPosition.relativePoint == "LEFT"
        and persistedPosition.x == 21
        and persistedPosition.y == 22,
      "sharing drag should persist the exact account position"
    )
    assert(persistedPosition ~= localPosition, "sharing drag should not replace the character position")
    assert(localPosition.x == 1 and localPosition.y == 2, "sharing drag should leave the character position untouched")
  end
end
