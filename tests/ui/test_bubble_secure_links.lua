local FakeUI = require("tests.helpers.fake_ui")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
local FramePool = require("WhisperMessenger.UI.ChatBubble.FramePool")

local LINK_TEMPLATE = "InlineHyperlinkFrameTemplate"
local ITEM_LINK = "item:19019"

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

local function pooledSetup()
  local factory = FakeUI.NewFactory()
  local content = factory.CreateFrame("Frame", nil, nil)
  content:SetSize(400, 600)
  FramePool.initPool(content)
  return factory, content, FramePool.getFactory(factory, content)
end

local function createBubble(pooled, factory, content)
  local message = { text = "hello", kind = "user", direction = "in", sentAt = 1000, playerName = "Arthas" }
  local options = { paneWidth = 400, showIcon = false, persistentFactory = factory }
  return BubbleFrame.CreateBubble(pooled, content, message, options).frame
end

local function clickLink(frame, link)
  frame.templateHyperlinkClick(frame, link, "[Thunderfury]", "LeftButton")
  for _, hook in ipairs((frame._hookScripts or {}).OnHyperlinkClick or {}) do
    hook(frame, link, "[Thunderfury]", "LeftButton")
  end
end

local function test_bubble_uses_link_template()
  withTemplate(function()
    local factory, content, pooled = pooledSetup()
    -- A plain pooled Button must not be handed to a bubble that wants the template.
    pooled.CreateFrame("Button", nil, content)
    FramePool.releaseAll(content)

    local frame = createBubble(pooled, factory, content)

    assert(frame.template == LINK_TEMPLATE, "bubble frame created with the link template, got " .. tostring(frame.template))
    assert(frame._wmSecureLinks == true, "bubble frame marked as secure-link frame")
    assert(frame:GetScript("OnHyperlinkClick") == frame.templateHyperlinkClick, "template click script kept")
  end)
end

local function test_reacquired_bubble_keeps_one_hook()
  withTemplate(function()
    local factory, content, pooled = pooledSetup()
    local first = createBubble(pooled, factory, content)
    FramePool.releaseAll(content)
    createBubble(pooled, factory, content)
    FramePool.releaseAll(content)
    local frame = createBubble(pooled, factory, content)

    assert(frame == first, "pooled bubble frame reused")
    assert(#frame._hookScripts.OnHyperlinkClick == 1, "one click hook per frame, got " .. #frame._hookScripts.OnHyperlinkClick)

    local itemRefs = 0
    local previousSetItemRef = rawget(_G, "SetItemRef")
    rawset(_G, "SetItemRef", function()
      itemRefs = itemRefs + 1
    end)
    local ok, err = pcall(clickLink, frame, ITEM_LINK)
    rawset(_G, "SetItemRef", previousSetItemRef)
    if not ok then
      error(err, 0)
    end
    assert(itemRefs == 1, "one item click calls SetItemRef once, got " .. itemRefs)
  end)
end

local function test_bubble_without_template_keeps_old_click_script()
  local factory, content, pooled = pooledSetup()
  local frame = createBubble(pooled, factory, content)

  assert(frame.template == nil, "no template without client support")
  assert(frame:GetScript("OnHyperlinkClick") ~= nil, "addon click script set")
  assert((frame._hookScripts or {}).OnHyperlinkClick == nil, "no click hook on plain frame")
end

return function()
  test_bubble_uses_link_template()
  test_reacquired_bubble_keeps_one_hook()
  test_bubble_without_template_keeps_old_click_script()
end
