local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local anchor = factory.CreateFrame("Button", nil, nil)

  local savedShowDropdown = _G.FriendsFrame_ShowDropdown
  local savedShowBNDropdown = _G.FriendsFrame_ShowBNDropdown
  local savedUnitPopupOpenMenu = _G.UnitPopup_OpenMenu

  -- test_open_wow_contact_uses_friends_dropdown
  do
    local called = nil
    rawset(
      _G,
      "FriendsFrame_ShowDropdown",
      function(name, connected, lineID, chatType, chatFrame, friendsList, clubID, streamID, epoch, position, guid)
        called = {
          name = name,
          connected = connected,
          lineID = lineID,
          chatType = chatType,
          chatFrame = chatFrame,
          friendsList = friendsList,
          clubID = clubID,
          streamID = streamID,
          epoch = epoch,
          position = position,
          guid = guid,
        }
      end
    )

    local opened = ContextMenu.Open({
      channel = "WOW",
      displayName = "Arthas-Area52",
      guid = "Player-3678-0A1B2C3D",
    }, anchor)

    assert(opened == true, "wow contact should open context menu")
    assert(called ~= nil, "FriendsFrame_ShowDropdown should be called for wow contact")
    assert(called.name == "Arthas-Area52")
    assert(called.connected == 1)
    assert(called.chatFrame == anchor)
    assert(called.guid == "Player-3678-0A1B2C3D")
  end

  -- test_open_bnet_contact_uses_bnet_dropdown
  do
    local called = nil
    _G.FriendsFrame_ShowBNDropdown = function(
      name,
      connected,
      lineID,
      chatType,
      chatFrame,
      friendsList,
      bnetIDAccount,
      clubID,
      streamID,
      epoch,
      position,
      battleTag
    )
      called = {
        name = name,
        connected = connected,
        lineID = lineID,
        chatType = chatType,
        chatFrame = chatFrame,
        friendsList = friendsList,
        bnetIDAccount = bnetIDAccount,
        clubID = clubID,
        streamID = streamID,
        epoch = epoch,
        position = position,
        battleTag = battleTag,
      }
    end

    local opened = ContextMenu.Open({
      channel = "BN",
      displayName = "Jaina#1234",
      bnetAccountID = 12345,
      battleTag = "Jaina#1234",
    }, anchor)

    assert(opened == true, "bnet contact should open context menu")
    assert(called ~= nil, "FriendsFrame_ShowBNDropdown should be called for bnet contact")
    assert(called.name == "Jaina#1234")
    assert(called.connected == 1)
    assert(called.chatFrame == anchor)
    assert(called.bnetIDAccount == 12345)
    assert(called.battleTag == "Jaina#1234")
  end

  -- test_open_bnet_falls_back_to_bn_unit_popup_without_wow_dropdown
  do
    local wowDropdownCalled = false
    local calledWhich = nil
    local calledContext = nil
    _G.FriendsFrame_ShowBNDropdown = nil
    rawset(_G, "FriendsFrame_ShowDropdown", function()
      wowDropdownCalled = true
    end)
    rawset(_G, "UnitPopup_OpenMenu", function(which, contextData)
      calledWhich = which
      calledContext = contextData
    end)

    local opened = ContextMenu.Open({
      channel = "BN",
      displayName = "Jaina#1234",
      bnetAccountID = 12345,
      battleTag = "Jaina#1234",
    }, anchor)

    assert(opened == true, "bn contact should open via BN_FRIEND fallback when BN dropdown is unavailable")
    assert(wowDropdownCalled == false, "bn fallback should not call FriendsFrame_ShowDropdown")
    assert(calledWhich == "BN_FRIEND", "bn fallback should open BN_FRIEND menu")
    assert(calledContext ~= nil and calledContext.bnetIDAccount == 12345, "bn fallback should pass bnet account id")
  end

  -- test_open_falls_back_to_unit_popup_when_friends_dropdown_missing
  do
    local calledWhich = nil
    local calledContext = nil
    rawset(_G, "FriendsFrame_ShowDropdown", nil)
    _G.FriendsFrame_ShowBNDropdown = nil
    rawset(_G, "UnitPopup_OpenMenu", function(which, contextData)
      calledWhich = which
      calledContext = contextData
    end)

    local opened = ContextMenu.Open({
      channel = "WOW",
      displayName = "Thrall-Doomhammer",
      guid = "Player-57-00000001",
    }, anchor)

    assert(opened == true, "unit popup fallback should open menu")
    assert(calledWhich == "FRIEND", "fallback should open FRIEND menu for wow contact")
    assert(calledContext ~= nil, "fallback should pass contextData")
    assert(calledContext.name == "Thrall-Doomhammer")
    assert(calledContext.chatTarget == "Thrall-Doomhammer")
    assert(calledContext.chatFrame == anchor)
  end

  -- test_open_returns_false_when_no_display_name
  do
    rawset(_G, "FriendsFrame_ShowDropdown", function()
      error("should not be called")
    end)

    local opened = ContextMenu.Open({ channel = "WOW" }, anchor)
    assert(opened == false, "context menu should not open without a contact name")
  end

  -- test_open_returns_false_when_no_menu_api_is_available
  do
    rawset(_G, "FriendsFrame_ShowDropdown", nil)
    _G.FriendsFrame_ShowBNDropdown = nil
    rawset(_G, "UnitPopup_OpenMenu", nil)

    local opened = ContextMenu.Open({
      channel = "WOW",
      displayName = "Thrall-Doomhammer",
    }, anchor)

    assert(opened == false, "context menu should return false when all menu APIs are unavailable")
  end

  rawset(_G, "FriendsFrame_ShowDropdown", savedShowDropdown)
  _G.FriendsFrame_ShowBNDropdown = savedShowBNDropdown
  rawset(_G, "UnitPopup_OpenMenu", savedUnitPopupOpenMenu)
end
