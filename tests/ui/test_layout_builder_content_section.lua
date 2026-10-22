local FakeUI = require("tests.helpers.fake_ui")
local RetailHud = require("tests.helpers.retail_hud")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local NativeArt = require("WhisperMessenger.UI.Helpers.NativeArt")
local LayoutMetrics = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.Metrics")
local ContentSection = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.ContentSection")

local function buildSection()
  local factory = FakeUI.NewFactory()
  local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
  uiParent:SetSize(920, 580)

  local frame = factory.CreateFrame("Frame", "MainFrame", uiParent)
  frame:SetSize(920, 580)

  local sizing = LayoutMetrics.CalculateRelayout({}, 920, 580, nil, Theme)

  local contactsPane = factory.CreateFrame("Frame", nil, frame)
  contactsPane:SetSize(sizing.contactsWidth, sizing.contactsHeight)
  contactsPane:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -Theme.TOP_BAR_HEIGHT)

  local section = ContentSection.Build(factory, frame, contactsPane, sizing, {
    theme = Theme,
  })
  return section, frame
end

return function()
  -- test_content_section_builds_its_panes
  do
    local section, frame = buildSection()
    assert(section.contentPane ~= nil, "contentPane should exist")
    assert(section.threadPane ~= nil, "threadPane should exist")
    assert(section.composerPane ~= nil, "composerPane should exist")

    assert(section.contentPane.parent == frame, "contentPane should parent to frame")
    assert(section.threadPane.parent == section.contentPane, "threadPane should parent to contentPane")
    assert(section.composerPane.parent == section.contentPane, "composerPane should parent to contentPane")

    assert(section.threadPane.point ~= nil, "threadPane should have anchoring")
    assert(section.composerPane.point ~= nil, "composerPane should have anchoring")
    assert(section.contentPaneBg == nil, "HUD off: no content pane background")
  end

  -- test_retail_hud_content_background_uses_the_panel_atlas
  RetailHud.With(function()
    RetailHud.WithAtlas(true, function()
      local section = buildSection()
      local bg = section.contentPaneBg
      assert(bg ~= nil, "retail: content pane background should exist")
      assert(bg.allPoints == section.contentPane, "retail: content pane background should fill the pane")
      assert(bg.atlas == "auctionhouse-background-index", "retail: content pane background should carry the wide panel atlas")
    end)
  end)

  -- test_retail_hud_content_background_draws_nothing_without_the_atlas
  RetailHud.With(function()
    RetailHud.WithAtlas(false, function()
      local bg = buildSection().contentPaneBg
      assert(bg ~= nil, "retail, no atlas: content pane background should exist")
      assert(bg.atlas == nil and bg.color == nil, "retail, no atlas: content pane background should hold no art")
    end)
  end)

  -- test_classic_hud_has_no_content_background
  Hud.Configure("classic")
  local ok, err = pcall(RetailHud.WithAtlas, true, function()
    assert(buildSection().contentPaneBg == nil, "classic: no content pane background")
  end)
  Hud.Configure("off")
  assert(ok, err)
end
