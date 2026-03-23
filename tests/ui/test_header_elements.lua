local FakeUI = require("tests.helpers.fake_ui")
local HeaderElements = require("WhisperMessenger.UI.ConversationPane.HeaderElements")

return function()
  local factory = FakeUI.NewFactory()
  local pane = factory.CreateFrame("Frame", nil, nil)
  pane:SetSize(600, 420)

  -- test_create_header_frame_returns_frame
  do
    local HEADER_HEIGHT = 56
    local headerFrame = HeaderElements.createHeaderFrame(factory, pane, HEADER_HEIGHT)
    assert(headerFrame ~= nil, "createHeaderFrame should return a frame")
    assert(
      headerFrame.height == HEADER_HEIGHT,
      "headerFrame should have correct height, got: " .. tostring(headerFrame.height)
    )
  end

  -- test_create_class_icon_with_known_class
  do
    local headerFrame = HeaderElements.createHeaderFrame(factory, pane, 56)
    local contact = { classTag = "WARRIOR", displayName = "Arthas" }
    local result = HeaderElements.createClassIcon(factory, headerFrame, contact)
    assert(result ~= nil, "createClassIcon should return a result table")
    assert(result.frame ~= nil, "result should have a frame")
    assert(result.texture ~= nil, "result should have a texture")
    assert(result.texture.texturePath ~= nil, "texture should have a path set for known class")
  end

  -- test_create_class_icon_without_class_uses_bnet
  do
    local headerFrame = HeaderElements.createHeaderFrame(factory, pane, 56)
    local result = HeaderElements.createClassIcon(factory, headerFrame, nil)
    assert(result ~= nil, "createClassIcon should return a result table for nil contact")
    assert(result.texture ~= nil, "result should have a texture")
    -- With no classTag, should fall back to bnet_icon
    assert(result.texture.texturePath ~= nil, "texture should have a fallback bnet_icon path")
  end

  -- test_create_contact_name_sets_text
  do
    local headerFrame = HeaderElements.createHeaderFrame(factory, pane, 56)
    local contact = { displayName = "Arthas", classTag = "WARRIOR" }
    local headerName = HeaderElements.createContactName(headerFrame, contact)
    assert(headerName ~= nil, "createContactName should return a FontString")
    assert(headerName.text == "Arthas", "headerName should have displayName set, got: " .. tostring(headerName.text))
    assert(headerName.shown == true, "headerName should be visible when contact provided")
  end

  -- test_create_contact_name_hides_when_no_contact
  do
    local headerFrame = HeaderElements.createHeaderFrame(factory, pane, 56)
    local headerName = HeaderElements.createContactName(headerFrame, nil)
    assert(headerName ~= nil, "createContactName should return a FontString for nil contact")
    assert(headerName.shown == false, "headerName should be hidden when no contact")
  end

  -- test_create_status_dot_returns_frame
  do
    local headerFrame = HeaderElements.createHeaderFrame(factory, pane, 56)
    local contact = { displayName = "Arthas", classTag = "WARRIOR" }
    local iconResult = HeaderElements.createClassIcon(factory, headerFrame, contact)
    local statusDot = HeaderElements.createStatusDot(factory, headerFrame, iconResult.frame, contact)
    assert(statusDot ~= nil, "createStatusDot should return a frame")
    assert(statusDot.bg ~= nil, "statusDot should have a bg texture")
    assert(statusDot.shown == true, "statusDot should be shown when contact is provided")
  end

  -- test_create_empty_state_shown_when_no_contact
  do
    local emptyLabel = HeaderElements.createEmptyState(pane, nil)
    assert(emptyLabel ~= nil, "createEmptyState should return a FontString")
    assert(emptyLabel.shown == true, "emptyLabel should be shown when contact is nil")
  end
end
