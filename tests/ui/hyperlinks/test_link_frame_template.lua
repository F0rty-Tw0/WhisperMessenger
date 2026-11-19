-- Link frames take InlineHyperlinkFrameTemplate when the game has it, so the
-- click runs Blizzard's secure handler. LinkFrameTemplate picks the template
-- string; CreateLinkFrame builds the frame and records whether it is secure.
local FakeUI = require("tests.helpers.fake_ui")
local LinkClicks = require("WhisperMessenger.UI.Hyperlinks.LinkClicks")
local Hyperlinks = require("WhisperMessenger.UI.Hyperlinks")

local INLINE = "InlineHyperlinkFrameTemplate"
local EXTRA = "TooltipBackdropTemplate"

local function eq(actual, expected, label)
  assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function withTemplate(present, fn)
  local saved = rawget(_G, "C_XMLUtil")
  if present then
    rawset(_G, "C_XMLUtil", {
      GetTemplateInfo = function(name)
        if name == INLINE then
          return { type = "Frame" }
        end
        return nil
      end,
    })
  else
    rawset(_G, "C_XMLUtil", nil)
  end
  local ok, err = pcall(fn)
  rawset(_G, "C_XMLUtil", saved)
  if not ok then
    error(err, 0)
  end
end

return function()
  -- test_template_present_without_extra_uses_inline_template
  withTemplate(true, function()
    local template, secure = LinkClicks.LinkFrameTemplate()
    eq(template, INLINE, "present, no extra template")
    eq(secure, true, "present, no extra secure")
  end)

  -- test_template_present_with_extra_appends_inline_template
  withTemplate(true, function()
    local template, secure = LinkClicks.LinkFrameTemplate(EXTRA)
    eq(template, EXTRA .. ", " .. INLINE, "present, extra template")
    eq(secure, true, "present, extra secure")
  end)

  -- test_template_absent_without_extra_returns_nil
  withTemplate(false, function()
    local template, secure = LinkClicks.LinkFrameTemplate()
    eq(template, nil, "absent, no extra template")
    eq(secure, false, "absent, no extra secure")
  end)

  -- test_template_absent_with_extra_returns_extra
  withTemplate(false, function()
    local template, secure = LinkClicks.LinkFrameTemplate(EXTRA)
    eq(template, EXTRA, "absent, extra template")
    eq(secure, false, "absent, extra secure")
  end)

  -- test_create_link_frame_present_uses_inline_template
  withTemplate(true, function()
    local factory = FakeUI.NewFactory()
    local frame = LinkClicks.CreateLinkFrame(factory, "Frame", "WMLinkFrame", nil)
    eq(frame.frameType, "Frame", "present frame type")
    eq(frame.name, "WMLinkFrame", "present frame name")
    eq(frame.template, INLINE, "present frame template")
    eq(frame._wmSecureLinks, true, "present frame secure flag")
  end)

  -- test_create_link_frame_absent_has_no_template
  withTemplate(false, function()
    local factory = FakeUI.NewFactory()
    local frame = LinkClicks.CreateLinkFrame(factory, "Frame", nil, nil)
    eq(frame.template, nil, "absent frame template")
    eq(frame._wmSecureLinks, false, "absent frame secure flag")
  end)

  -- test_create_link_frame_without_template_click_is_not_secure
  withTemplate(true, function()
    local factory = FakeUI.NewFactory()
    local createFrame = factory.CreateFrame
    factory.CreateFrame = function(frameType, name, parent)
      return createFrame(frameType, name, parent)
    end
    local frame = LinkClicks.CreateLinkFrame(factory, "Frame", nil, nil)
    eq(frame._wmSecureLinks, false, "frame that lost the template secure flag")
  end)

  -- test_reused_frame_keeps_its_secure_flag_after_our_click_script
  -- A pooled frame that lost the template gets our own click script from
  -- BindClick; handed out again, that script must not make it look secure.
  withTemplate(true, function()
    local factory = FakeUI.NewFactory()
    local pooled = factory.CreateFrame("Frame", nil, nil)
    factory.CreateFrame = function()
      return pooled
    end
    local first = LinkClicks.CreateLinkFrame(factory, "Frame", nil, nil)
    eq(first._wmSecureLinks, false, "first hand-out secure flag")
    first:SetScript("OnHyperlinkClick", function() end)
    local again = LinkClicks.CreateLinkFrame(factory, "Frame", nil, nil)
    eq(again._wmSecureLinks, false, "reused frame with our click script secure flag")
  end)

  -- test_hyperlinks_re_exports_same_functions
  eq(Hyperlinks.LinkFrameTemplate, LinkClicks.LinkFrameTemplate, "LinkFrameTemplate re-export")
  eq(Hyperlinks.CreateLinkFrame, LinkClicks.CreateLinkFrame, "CreateLinkFrame re-export")
end
