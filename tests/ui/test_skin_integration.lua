local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Composer = require("WhisperMessenger.UI.Composer")
local ScrollViewFactory = require("WhisperMessenger.UI.ScrollView.Factory")
local RowView = require("WhisperMessenger.UI.ContactsList.RowView")

local function makeSelectedContact()
  return {
    conversationKey = "me::WOW::arthas-area52",
    displayName = "Arthas-Area52",
    channel = "WOW",
  }
end

return function()
  local previousPreset = Theme.GetPreset()

  -- ---------------------------------------------------------------------
  -- Send button stays as the modern rounded pill regardless of preset.
  -- Native Blizzard UI-Panel-Button textures didn't fit the composer
  -- layout cleanly (cramped at our small button size, awkward when
  -- enlarged), so the rounded pill carries the send button under both
  -- modern and blizzard skins.
  -- ---------------------------------------------------------------------
  do
    Theme.SetPreset("wow_native")
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "parentNative", nil)
    parent:SetSize(600, 50)

    local composer = Composer.Create(factory, parent, makeSelectedContact(), function() end)
    local btn = composer.sendButton

    assert(btn.normalTexture == nil, "test_send_no_skin_native: should not set normalTexture under any skin")
    assert(btn.pushedTexture == nil, "test_send_no_skin_native: should not set pushedTexture under any skin")
    assert(btn.highlightTexture == nil, "test_send_no_skin_native: should not set highlightTexture under any skin")
    assert(btn.disabledTexture == nil, "test_send_no_skin_native: should not set disabledTexture under any skin")
    assert(btn.sendBg ~= nil, "test_send_no_skin_native: rounded background should drive the look")
    assert(btn.width == 44, "test_send_no_skin_native: stays at modern pill width 44")
    assert(btn.height == 30, "test_send_no_skin_native: stays at modern pill height 30")
  end

  do
    Theme.SetPreset("wow_default")
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "parentModern", nil)
    parent:SetSize(600, 50)

    local composer = Composer.Create(factory, parent, makeSelectedContact(), function() end)
    local btn = composer.sendButton

    assert(btn.normalTexture == nil, "test_send_no_skin_modern: should not set normalTexture")
    assert(btn.sendBg ~= nil, "test_send_no_skin_modern: rounded background drives the look")
    assert(btn.width == 44, "test_send_no_skin_modern: rounded pill width 44")
    assert(btn.height == 30, "test_send_no_skin_modern: rounded pill height 30")
  end

  -- ---------------------------------------------------------------------
  -- ScrollView thumb stays as slim color paint under wow_native (knob
  -- texture intentionally dropped — it doesn't render well at our 4px
  -- slider width; the gold-tinted Phase 1 scrollbar palette carries it)
  -- ---------------------------------------------------------------------
  do
    Theme.SetPreset("wow_native")
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "scrollParentNative", nil)
    parent:SetSize(400, 300)

    local view = ScrollViewFactory.Create(factory, parent, { width = 380, height = 280 })
    assert(
      view.scrollBar.thumb.texturePath == nil,
      "test_scrollbar_blizzard: should not set knob texture, got " .. tostring(view.scrollBar.thumb.texturePath)
    )
    assert(view.scrollBar.thumb.color ~= nil, "test_scrollbar_blizzard: should keep slim color paint under blizzard")
  end

  -- ---------------------------------------------------------------------
  -- ScrollView thumb stays slim color under wow_default
  -- ---------------------------------------------------------------------
  do
    Theme.SetPreset("wow_default")
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "scrollParentModern", nil)
    parent:SetSize(400, 300)

    local view = ScrollViewFactory.Create(factory, parent, { width = 380, height = 280 })
    assert(
      view.scrollBar.thumb.texturePath == nil,
      "test_scrollbar_modern: should not set knob texture, got " .. tostring(view.scrollBar.thumb.texturePath)
    )
    assert(view.scrollBar.thumb.color ~= nil, "test_scrollbar_modern: should keep slim color paint")
  end

  -- ---------------------------------------------------------------------
  -- ScrollView.refreshSkin re-applies thumb paint on live preset switch
  -- ---------------------------------------------------------------------
  do
    Theme.SetPreset("wow_default")
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "scrollRefreshParent", nil)
    parent:SetSize(400, 300)

    local view = ScrollViewFactory.Create(factory, parent, { width = 380, height = 280 })
    assert(view.refreshSkin ~= nil, "test_scroll_refresh: ScrollView should expose refreshSkin")
    assert(
      view.scrollBar.thumb.texturePath == nil,
      "test_scroll_refresh: precondition — modern skin should not set knob"
    )

    Theme.SetPreset("wow_native")
    view.refreshSkin()
    -- Blizzard skin no longer paints a knob texture (see Skins.lua note);
    -- the slim color thumb continues with the Phase 1 gold-tinted palette.
    assert(
      view.scrollBar.thumb.texturePath == nil,
      "test_scroll_refresh: should not paint knob on switch to wow_native"
    )
    assert(view.scrollBar.thumb.color ~= nil, "test_scroll_refresh: slim color paint should remain after refresh")

    Theme.SetPreset("wow_default")
    view.refreshSkin()
    assert(
      view.scrollBar.thumb.texturePath == nil,
      "test_scroll_refresh: should remain nil on switch back to modern, got "
        .. tostring(view.scrollBar.thumb.texturePath)
    )
  end

  -- ---------------------------------------------------------------------
  -- Re-binding a row re-evaluates skin (matches the runtime.refreshWindow
  -- flow that fires on themePreset change)
  -- ---------------------------------------------------------------------
  do
    Theme.SetPreset("wow_default")
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "rowRebindParent", nil)
    parent:SetSize(260, 400)

    local item = {
      conversationKey = "me::WOW::carol",
      displayName = "Carol",
      lastPreview = "hi",
      unreadCount = 0,
      lastActivityAt = 50,
      channel = "WOW",
      classTag = nil,
      pinned = false,
    }
    local row = RowView.bindRow(factory, parent, nil, 1, item, { onSelect = function() end })
    assert(
      row.skinHighlight.texturePath == nil,
      "test_row_rebind: precondition — modern row should have no overlay texture"
    )

    Theme.SetPreset("wow_native")
    row = RowView.bindRow(factory, parent, row, 1, item, { onSelect = function() end })
    assert(
      row.skinHighlight.texturePath == "Interface\\QuestFrame\\UI-QuestTitleHighlight",
      "test_row_rebind: re-binding under wow_native should set overlay texture"
    )

    Theme.SetPreset("wow_default")
    row = RowView.bindRow(factory, parent, row, 1, item, { onSelect = function() end })
    assert(
      row.skinHighlight.texturePath == nil,
      "test_row_rebind: re-binding back to modern should clear overlay texture"
    )
  end

  -- ---------------------------------------------------------------------
  -- ScrollView hides the thumb when no overflow (defensive — was leaking
  -- the textured knob in production even though scrollBar was hidden)
  -- ---------------------------------------------------------------------
  do
    Theme.SetPreset("wow_native")
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "scrollNoOverflow", nil)
    parent:SetSize(400, 300)

    local view = ScrollViewFactory.Create(factory, parent, { width = 380, height = 280 })
    -- No content added: range is 0, no overflow
    assert(
      view.scrollBar.shown == false,
      "test_scroll_no_overflow: scrollBar should be hidden when there's no overflow"
    )
    assert(
      view.scrollBar.thumb.shown == false,
      "test_scroll_no_overflow: thumb should be hidden when there's no overflow"
    )
  end

  -- ---------------------------------------------------------------------
  -- Contact row gets a Blizzard highlight overlay under wow_native
  -- ---------------------------------------------------------------------
  do
    Theme.SetPreset("wow_native")
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "rowParentNative", nil)
    parent:SetSize(260, 400)

    local item = {
      conversationKey = "me::WOW::alice",
      displayName = "Alice",
      lastPreview = "hello",
      unreadCount = 0,
      lastActivityAt = 100,
      channel = "WOW",
      classTag = nil,
      pinned = false,
    }
    local row = RowView.bindRow(factory, parent, nil, 1, item, { onSelect = function() end })

    assert(row.skinHighlight ~= nil, "test_row_blizzard_overlay: skinHighlight texture should be created")
    assert(
      row.skinHighlight.texturePath == "Interface\\QuestFrame\\UI-QuestTitleHighlight",
      "test_row_blizzard_overlay: expected UI-QuestTitleHighlight, got " .. tostring(row.skinHighlight.texturePath)
    )
    assert(
      row.skinHighlight.shown == false,
      "test_row_blizzard_overlay: skinHighlight should be hidden when row is idle"
    )
  end

  -- ---------------------------------------------------------------------
  -- Contact row stays color-only under wow_default (no overlay texture)
  -- ---------------------------------------------------------------------
  do
    Theme.SetPreset("wow_default")
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "rowParentModern", nil)
    parent:SetSize(260, 400)

    local item = {
      conversationKey = "me::WOW::bob",
      displayName = "Bob",
      lastPreview = "ping",
      unreadCount = 0,
      lastActivityAt = 80,
      channel = "WOW",
      classTag = nil,
      pinned = false,
    }
    local row = RowView.bindRow(factory, parent, nil, 1, item, { onSelect = function() end })

    -- skinHighlight may exist (created unconditionally) but must have no
    -- texture path under modern skin so it never paints.
    if row.skinHighlight ~= nil then
      assert(
        row.skinHighlight.texturePath == nil,
        "test_row_modern_overlay: skinHighlight texturePath should be nil under modern skin"
      )
    end
  end

  if previousPreset then
    Theme.SetPreset(previousPreset)
  end

  print("  All skin integration tests passed")
end
