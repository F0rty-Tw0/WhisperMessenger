-- A preview card wired to a fake quickReply that logs every call, plus
-- helpers that drive the reply row's input like a player would.
local FakeUI = require("tests.helpers.fake_ui")
local IncomingPreview = require("WhisperMessenger.UI.ToggleIcon.IncomingPreview")

local PreviewReplyCard = {}

function PreviewReplyCard.Jaina(sentAt)
  return { conversationKey = "wow::jaina", sentAt = sentAt or 500, channel = "WOW" }
end

-- A preview another addon put up.
function PreviewReplyCard.External()
  local noop = function() end
  return { sender = "Crafter", text = "Needs Plate Belt", classTag = "WARRIOR", onClick = noop, onDismiss = noop, onShown = noop }
end

-- opts (mutable after build): enabled, lock, submit(meta, text) -> bool, open(meta, text) -> bool
local function fakeQuickReply(opts, calls)
  return {
    isEnabled = function()
      return opts.enabled ~= false
    end,
    getLockReasonText = function()
      return opts.lock
    end,
    onSubmit = function(meta, text)
      calls.submit[#calls.submit + 1] = { meta = meta, text = text }
      if opts.submit then
        return opts.submit(meta, text)
      end
      return true
    end,
    onSaveDraft = function(meta, text)
      calls.saveDraft[#calls.saveDraft + 1] = { meta = meta, text = text }
    end,
    onDismissThrough = function(meta)
      calls.dismissThrough[#calls.dismissThrough + 1] = meta
    end,
    onOpen = function(meta, text)
      calls.open[#calls.open + 1] = { meta = meta, text = text }
      if opts.open then
        return opts.open(meta, text)
      end
      return true
    end,
    onRefresh = function()
      calls.refresh = calls.refresh + 1
    end,
  }
end

function PreviewReplyCard.Build(opts)
  opts = opts or {}
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:SetSize(48, 48)
  parent:Show()
  local calls = { submit = {}, saveDraft = {}, dismissThrough = {}, open = {}, refresh = 0, dismissed = 0, opened = 0 }
  local state = { opts = opts, calls = calls }
  state.card = IncomingPreview.Create(factory, parent, {
    quickReply = fakeQuickReply(opts, calls),
    getPreviewAutoDismissSeconds = function()
      return 5
    end,
    onDismissPreview = function()
      calls.dismissed = calls.dismissed + 1
    end,
    onOpenPreview = function()
      calls.opened = calls.opened + 1
    end,
  })
  return state
end

function PreviewReplyCard.ShowJaina(state, meta)
  state.card.setIncomingPreview("Jaina", "Need help?", "MAGE", meta or PreviewReplyCard.Jaina())
end

function PreviewReplyCard.ShowThrall(state)
  state.card.setIncomingPreview("Thrall", "Lok'tar", "SHAMAN", { conversationKey = "wow::thrall", sentAt = 510, channel = "WOW" })
end

function PreviewReplyCard.Input(state)
  return state.card.replyHold.row.input
end
local input = PreviewReplyCard.Input

function PreviewReplyCard.Fire(frame, script, ...)
  local handler = frame:GetScript(script)
  assert(type(handler) == "function", "frame has a " .. script .. " handler")
  return handler(frame, ...)
end
local fire = PreviewReplyCard.Fire

function PreviewReplyCard.Focus(state)
  input(state):SetFocus()
end

function PreviewReplyCard.Blur(state)
  input(state):ClearFocus()
end

-- fake_ui's SetText does not fire OnTextChanged, so fire it by hand.
function PreviewReplyCard.TypeText(state, text)
  input(state):SetText(text)
  fire(input(state), "OnTextChanged")
end

function PreviewReplyCard.Enter(state)
  fire(input(state), "OnEnterPressed")
end

function PreviewReplyCard.Text(state)
  return input(state):GetText()
end

function PreviewReplyCard.Sender(state)
  return state.card.senderLabel:GetText()
end

-- Runs fn(timers) with a C_Timer stub that records every timer it makes.
function PreviewReplyCard.WithTimers(fn)
  local saved = _G.C_Timer
  local timers = {}
  rawset(_G, "C_Timer", {
    NewTimer = function(seconds, callback)
      local timer = { seconds = seconds, callback = callback, cancelled = false }
      timer.Cancel = function(self)
        self.cancelled = true
      end
      timers[#timers + 1] = timer
      return timer
    end,
  })
  local ok, err = pcall(fn, timers)
  rawset(_G, "C_Timer", saved)
  if not ok then
    error(err, 0)
  end
end

function PreviewReplyCard.LiveTimers(timers)
  local live = 0
  for _, timer in ipairs(timers) do
    if not timer.cancelled then
      live = live + 1
    end
  end
  return live
end

return PreviewReplyCard
