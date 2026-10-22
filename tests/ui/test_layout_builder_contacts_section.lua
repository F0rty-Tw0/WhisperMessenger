local FakeUI = require("tests.helpers.fake_ui")
local RetailHud = require("tests.helpers.retail_hud")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local NativeArt = require("WhisperMessenger.UI.Helpers.NativeArt")
local LayoutMetrics = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.Metrics")
local ContactsSection = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.ContactsSection")

local function buildSection(withContentArea)
  local factory = FakeUI.NewFactory()
  local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
  uiParent:SetSize(920, 580)

  local frame = factory.CreateFrame("Frame", "MainFrame", uiParent)
  frame:SetSize(920, 580)
  if withContentArea then
    -- Native chrome: ContactsSection treats a content area as the HUD.
    frame.contentArea = factory.CreateFrame("Frame", nil, frame)
  end

  local sizing = LayoutMetrics.CalculateRelayout({}, 920, 580, nil, Theme)
  local section = ContactsSection.Build(factory, frame, sizing, {
    theme = Theme,
  })
  return section, frame
end

local function isTransparent(texture)
  return texture.color ~= nil and texture.color[4] == 0
end

return function()
  -- test_contacts_section_builds_its_parts
  do
    local section, frame = buildSection(false)
    assert(section.contactsPane ~= nil, "contactsPane should exist")
    assert(section.contactsSearch ~= nil, "contactsSearch result should exist")
    assert(section.contactsView ~= nil, "contactsView should exist")
    assert(section.contactsDivider ~= nil, "contactsDivider should exist")
    assert(section.contactsResizeHandle ~= nil, "contactsResizeHandle should exist")
    assert(section.contactsHandleWidth == LayoutMetrics.GetContactsResizeHandleWidth(Theme), "contactsHandleWidth should match layout metrics")
    assert(section.contactsPane.parent == frame, "contactsPane should parent to frame when no inset is present")
    assert(section.contactsView.scrollFrame.point ~= nil, "contactsView.scrollFrame should be positioned")
  end

  -- test_retail_hud_contacts_background_uses_the_panel_atlas
  RetailHud.With(function()
    RetailHud.WithAtlas(true, function()
      local section = buildSection(true)
      assert(section.contactsPaneBg.atlas == NativeArt.PANEL_BACKGROUND, "retail: contacts bg should carry the panel atlas")
    end)
  end)

  -- test_retail_hud_contacts_background_stays_transparent_without_the_atlas
  RetailHud.With(function()
    RetailHud.WithAtlas(false, function()
      local section = buildSection(true)
      assert(section.contactsPaneBg.atlas == nil, "retail, no atlas: contacts bg should get no atlas")
      assert(isTransparent(section.contactsPaneBg), "retail, no atlas: contacts bg should stay transparent")
    end)
  end)

  -- test_classic_hud_contacts_background_stays_transparent
  Hud.Configure("classic")
  local ok, err = pcall(RetailHud.WithAtlas, true, function()
    local section = buildSection(true)
    assert(section.contactsPaneBg.atlas == nil, "classic: contacts bg should get no atlas")
    assert(isTransparent(section.contactsPaneBg), "classic: contacts bg should stay transparent")
  end)
  Hud.Configure("off")
  assert(ok, err)
end
