local FakeUI = require("tests.helpers.fake_ui")
local RetailHud = require("tests.helpers.retail_hud")
local IncomingPreview = require("WhisperMessenger.UI.ToggleIcon.IncomingPreview")

local LINK_TEMPLATE = "InlineHyperlinkFrameTemplate"
local TOOLTIP_TEMPLATE = "TooltipBackdropTemplate"
local ITEM_LINK = "item:12345::"

-- Runs fn with C_XMLUtil reporting every template as present, restoring it after.
local function withTemplate(fn)
  local previous = rawget(_G, "C_XMLUtil")
  rawset(_G, "C_XMLUtil", {
    GetTemplateInfo = function()
      return { type = "Frame" }
    end,
  })
  local ok, err = pcall(fn)
  rawset(_G, "C_XMLUtil", previous)
  if not ok then
    error(err, 0)
  end
end

local function build(factory, opts)
  factory = factory or FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:SetSize(48, 48)
  parent:Show()
  return IncomingPreview.Create(factory, parent, opts or {})
end

-- A client whose CreateFrame throws for any template list naming the tooltip border.
local function factoryWithoutTooltipTemplate()
  local factory = FakeUI.NewFactory()
  local createFrame = factory.CreateFrame
  factory.CreateFrame = function(frameType, name, parent, template)
    if template and string.find(template, TOOLTIP_TEMPLATE, 1, true) then
      error("Couldn't find inherited node " .. TOOLTIP_TEMPLATE)
    end
    return createFrame(frameType, name, parent, template)
  end
  return factory
end

-- A client that skips a missing tooltip border without an error: any template
-- list naming it yields a plain frame, so the link template is lost too.
local function factorySkippingTooltipTemplate()
  local factory = FakeUI.NewFactory()
  local createFrame = factory.CreateFrame
  factory.CreateFrame = function(frameType, name, parent, template)
    if template and string.find(template, TOOLTIP_TEMPLATE, 1, true) then
      template = nil
    end
    return createFrame(frameType, name, parent, template)
  end
  return factory
end

-- Clicks a link the way the live client does: the template's own script, then each post-hook.
local function clickLink(frame, link)
  frame.templateHyperlinkClick(frame, link, "[Signet]", "LeftButton")
  for _, hook in ipairs((frame._hookScripts or {}).OnHyperlinkClick or {}) do
    hook(frame, link, "[Signet]", "LeftButton")
  end
end

return function()
  local function test_preview_hud_off_uses_link_template()
    withTemplate(function()
      local frame = build().frame
      assert(frame.template == LINK_TEMPLATE, "preview uses the link template, got " .. tostring(frame.template))
      assert(frame._wmSecureLinks == true, "preview is marked as a secure link frame")
    end)
  end

  local function test_preview_hud_on_combines_templates()
    RetailHud.With(function()
      local frame = build().frame
      local expected = TOOLTIP_TEMPLATE .. ", " .. LINK_TEMPLATE
      assert(frame.template == expected, "HUD preview combines both templates, got " .. tostring(frame.template))
      assert(frame._wmSecureLinks == true, "HUD preview is marked as a secure link frame")
    end)
  end

  local function test_preview_hud_template_error_falls_back_to_link_template()
    RetailHud.With(function()
      local frame = build(factoryWithoutTooltipTemplate()).frame
      assert(frame.template == LINK_TEMPLATE, "fallback preview keeps the link template, got " .. tostring(frame.template))
      assert(frame._wmSecureLinks == true, "fallback preview is marked as a secure link frame")
    end)
  end

  local function test_preview_skipped_template_is_not_marked_secure()
    RetailHud.With(function()
      local frame = build(factorySkippingTooltipTemplate()).frame
      assert(frame.templateHyperlinkClick == nil, "the plain frame has no template click handler")
      assert(frame._wmSecureLinks == false, "a frame without the link template is not a secure link frame")
      assert(frame:GetScript("OnHyperlinkClick") ~= nil, "link clicks still have a handler")
    end)
  end

  local function test_preview_link_click_still_swallows_mouse_up()
    local saved = { setItemRef = rawget(_G, "SetItemRef"), getTime = rawget(_G, "GetTime") }
    local itemRefs = 0
    rawset(_G, "SetItemRef", function()
      itemRefs = itemRefs + 1
    end)
    rawset(_G, "GetTime", function()
      return 10
    end)
    local ok, err = pcall(withTemplate, function()
      local opened = false
      local preview = build(nil, {
        onOpenPreview = function()
          opened = true
          return true
        end,
      })
      preview.setIncomingPreview("Arthas", "hi", "PALADIN", { sentAt = 1 })
      local frame = preview.frame
      clickLink(frame, ITEM_LINK)
      frame:GetScript("OnMouseUp")(frame, "LeftButton")
      assert(itemRefs == 1, "the template's own handler runs the click")
      assert(opened == false, "a link click does not open the chat")
    end)
    rawset(_G, "SetItemRef", saved.setItemRef)
    rawset(_G, "GetTime", saved.getTime)
    if not ok then
      error(err, 0)
    end
  end

  test_preview_hud_off_uses_link_template()
  test_preview_hud_on_combines_templates()
  test_preview_hud_template_error_falls_back_to_link_template()
  test_preview_skipped_template_is_not_marked_secure()
  test_preview_link_click_still_swallows_mouse_up()
end
