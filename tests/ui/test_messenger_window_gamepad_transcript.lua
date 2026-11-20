local FakeUI = require("tests.helpers.fake_ui")
local FakeGamepad = require("tests.helpers.fake_gamepad")
local LayoutMessages = require("tests.helpers.layout_messages")
local Localization = require("WhisperMessenger.Locale.Localization")
local ChatContextMenu = require("WhisperMessenger.UI.ChatBubble.ContextMenu")
local GamepadNav = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadNav")
local GamepadTranscript = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.GamepadTranscript")

local function recordingNav()
  local nav = { ignored = {}, refreshes = 0 }
  function nav.ignore(widget, dontPropagate)
    nav.ignored[widget] = dontPropagate == true and "self" or "tree"
  end
  function nav.refresh()
    nav.refreshes = nav.refreshes + 1
  end
  return nav
end

-- Frames SmartNav would stop on under `root` (Utility.lua#L263-L277):
-- Buttons, EditBoxes and frames with mouse-up/down scripts, minus ignored
-- ones (Utility.lua#L59-L79: "tree" hides the subtree, "self" only the frame).
local function navTargets(nav, root, out)
  out = out or {}
  for _, child in ipairs(root.children or {}) do
    local mark = nav.ignored[child]
    if mark ~= "tree" then
      local isTarget = child.frameType == "Button"
        or child.frameType == "EditBox"
        or (child.GetScript and (child:GetScript("OnMouseUp") or child:GetScript("OnMouseDown")))
      if isTarget and mark == nil then
        out[#out + 1] = child
      end
      navTargets(nav, child, out)
    end
  end
  return out
end

local function incoming(text, sentAt)
  return { direction = "in", kind = "user", text = text, sentAt = sentAt, playerName = "Arthas", senderName = "Arthas", classTag = "PALADIN" }
end

local function outgoing(text, sentAt, delivery)
  return { direction = "out", kind = "user", text = text, sentAt = sentAt, delivery = delivery, playerName = "Thrall", senderName = "Me" }
end

local function layout(messages, options)
  local factory = FakeUI.NewFactory()
  local content = factory.CreateFrame("Frame", nil, nil)
  content:SetSize(400, 600)
  LayoutMessages(factory, content, messages, 400, options or {})
  return content
end

local function firstBubble(content)
  for _, child in ipairs(content.children) do
    if child._wmBubbleResult then
      return child
    end
  end
  return nil
end

return function()
  Localization.Configure({ language = "enUS" })
  local savedUIParent = _G.UIParent
  _G.UIParent = FakeUI.NewFactory().CreateFrame("Frame", "UIParent", nil)

  -- test_attach_keeps_the_chat_reachable
  do
    local nav = recordingNav()
    local content = layout({ incoming("hi", 0) })
    GamepadTranscript.Attach(nav, { content = content })
    assert(nav.ignored[content] == nil, "bubbles are no longer skipped")
  end

  -- test_only_bubbles_and_real_buttons_are_stops (Review Focus 5)
  do
    local nav = recordingNav()
    local reacted = incoming("hi", 0)
    reacted.reaction = { key = "heart", actorName = "Thrall", updatedAt = 1 }
    local content = layout({ reacted, outgoing("sent", 1), outgoing("oops", 2, "failed") }, { onMessageAction = function() end })
    GamepadTranscript.Attach(nav, { content = content })
    local reactionPill = firstBubble(content)._wmBubbleResult.reactionFrame
    assert(reactionPill ~= nil and reactionPill:IsShown(), "test precondition: the reaction pill is drawn")
    local bubbles, delivery, other = 0, 0, {}
    for _, target in ipairs(navTargets(nav, content)) do
      if target._wmBubbleResult then
        bubbles = bubbles + 1
      elseif target == (target:GetParent() or {})._wmDeliveryButton then
        delivery = delivery + 1
      else
        other[#other + 1] = target
      end
    end
    assert(bubbles == 3, "one stop per message, got " .. bubbles)
    assert(delivery == 1, "the unsent message's status button stays a stop")
    assert(#other == 0, "no stop on sender labels, avatars, copy buttons or reaction pills, got " .. #other)
  end

  -- test_reused_sender_label_keeps_the_status_button_reachable
  -- Pooled frames keep their SmartNav marks: an incoming label skipped
  -- once may come back as an outgoing one holding the status button.
  do
    local nav = recordingNav()
    local factory = FakeUI.NewFactory()
    local content = factory.CreateFrame("Frame", nil, nil)
    content:SetSize(400, 600)
    local transcript = { content = content }
    LayoutMessages(factory, content, { incoming("hi", 0) }, 400, {})
    GamepadTranscript.Attach(nav, transcript)
    local skipped = {}
    for widget in pairs(nav.ignored) do
      skipped[widget] = true
    end
    LayoutMessages(factory, content, { outgoing("oops", 2, "failed") }, 400, { onMessageAction = function() end })
    transcript.onNavTargetsChanged()
    local reused = false
    for _, target in ipairs(navTargets(nav, content)) do
      local label = target:GetParent()
      reused = reused or (label and label._wmDeliveryButton == target and skipped[label] == true)
    end
    assert(reused, "the status button sits in the reused, skipped label and is still a stop")
  end

  -- test_render_and_viewport_rerender_report_new_targets
  do
    local nav = recordingNav()
    local transcript = { content = layout({}) }
    GamepadTranscript.Attach(nav, transcript)
    assert(type(transcript.onNavTargetsChanged) == "function", "hook installed")
    LayoutMessages(FakeUI.NewFactory(), transcript.content, { incoming("late", 5) }, 400, {})
    transcript.onNavTargetsChanged()
    assert(nav.refreshes == 1, "a re-render asks for one re-scan")
  end

  -- test_bubbles_have_no_button_context_at_attach_or_after_a_rerender
  -- The game's buff refresh reads buttonContext on the focused frame; an
  -- addon value there taints it.
  do
    local nav = recordingNav()
    local transcript = { content = layout({ incoming("hi", 0) }) }
    GamepadTranscript.Attach(nav, transcript)
    local first = firstBubble(transcript.content)
    LayoutMessages(FakeUI.NewFactory(), transcript.content, { incoming("late", 5) }, 400, {})
    transcript.onNavTargetsChanged()
    local later = firstBubble(transcript.content)
    assert(first and later, "test precondition: bubbles were laid out")
    assert(first.buttonContext == nil and later.buttonContext == nil, "no bubble carries a buttonContext")
  end

  -- test_game_right_click_on_a_bubble_opens_its_menu_once
  do
    local env = FakeGamepad.New()
    local window = FakeUI.NewFactory().CreateFrame("Frame", "WhisperMessengerWindow", nil)
    local nav = GamepadNav.New(window, env.deps())
    nav.onShow()
    local content = layout({ incoming("hi", 0) })
    GamepadTranscript.Attach(nav, { content = content })
    local opened, original = 0, ChatContextMenu.Open
    rawset(ChatContextMenu, "Open", function()
      opened = opened + 1
      return true
    end)
    local ok, err = pcall(env.rightClick, firstBubble(content))
    rawset(ChatContextMenu, "Open", original)
    assert(ok, err)
    assert(opened == 1, "MouseDown opens the menu, MouseUp does not open it again; got " .. opened)
  end

  _G.UIParent = savedUIParent
end
