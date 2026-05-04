local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChatReplyState = ns.ChatReplyState or (type(require) == "function" and require("WhisperMessenger.Util.ChatReplyState")) or nil
local Localization = ns.Localization or (type(require) == "function" and require("WhisperMessenger.Locale.Localization")) or nil
local function L(key)
  return Localization and Localization.Text(key) or key
end

local MythicSuspendController = {}
local DEFAULT_MYTHIC_PAUSE_NOTICE_KEY = "Whispers are paused in Mythic content. Incoming and outgoing messages will resume after you leave."
local SUSPEND_PRINT_KEY = "Suspended for mythic content. Whispers will resume when you leave."
local RESUME_PRINT_KEY = "Resumed. Whispers are active again."
local R_REPLY_ADVISORY_KEY =
  '/r and R-key may fail in Mythic while "Hide whispers from default chat" is on. Use |cffffff00/wr|r to reply (or bind it to R via macro).'

function MythicSuspendController.Attach(runtime, deps)
  deps = deps or {}

  local Bootstrap = deps.Bootstrap or {}
  local isWindowVisible = deps.isWindowVisible or function()
    return false
  end
  local setWindowVisible = deps.setWindowVisible or function(...)
    local _ = ...
  end
  local refreshWindow = deps.refreshWindow or function(...)
    local _ = ...
  end
  local getNumChatWindows = deps.getNumChatWindows
  local getEditBox = deps.getEditBox

  runtime.suspend = function()
    runtime.messagingNotice = deps.mythicPauseNotice or L(DEFAULT_MYTHIC_PAUSE_NOTICE_KEY)
    Bootstrap._wasVisibleBeforeMythic = isWindowVisible()
    setWindowVisible(false)
    if Bootstrap.unregisterChatFilters then
      Bootstrap.unregisterChatFilters()
    end

    -- Unregister live AND non-essential lifecycle events so our OnEvent
    -- handler doesn't run at all during mythic content — any addon code
    -- in the event dispatch taints Blizzard's chat frame context.
    local EventBridge = deps.getEventBridge and deps.getEventBridge() or ns.BootstrapEventBridge
    if EventBridge and Bootstrap._loadFrame then
      EventBridge.UnregisterLiveEvents(Bootstrap._loadFrame)
      EventBridge.UnregisterSuspendableLifecycleEvents(Bootstrap._loadFrame)
    end

    -- Signal hooksecurefunc hooks (LinkHooks) to bail with zero addon code.
    _G._wmSuspended = true

    -- Release our R-key override so Blizzard's default /r takes over in M+.
    -- Our messenger composer is disabled here anyway, so R on our button
    -- would accomplish nothing.
    if runtime.syncReplyKey then
      runtime.syncReplyKey()
    end

    local printFn = deps.print or _G.print
    if type(printFn) == "function" then
      printFn("|cff888888[WhisperMessenger]|r " .. L(SUSPEND_PRINT_KEY))
      local settings = runtime.accountState and runtime.accountState.settings
      if settings and settings.hideFromDefaultChat == true then
        printFn("|cff888888[WhisperMessenger]|r " .. L(R_REPLY_ADVISORY_KEY))
      end
    end
  end

  runtime.resume = function()
    runtime.messagingNotice = nil
    _G._wmSuspended = nil
    local printFn = deps.print or _G.print
    if type(printFn) == "function" then
      printFn("|cff888888[WhisperMessenger]|r " .. L(RESUME_PRINT_KEY))
    end

    -- Clear our own stale reply key. We did NOT receive whispers during M+
    -- (LIVE_EVENTS were unregistered), so any value here is pre-M+ and not
    -- a valid reply target after resume.
    --
    -- IMPORTANT: do NOT call ChatEdit_SetLastTellTarget from here (even via
    -- securecall). Writing literal arguments from our stack still attributes
    -- caller taint to the upvalue slots inside Blizzard's chatEditLastTell,
    -- which then propagates taint into MessageEventHandler on the NEXT
    -- incoming whisper. Blizzard's tainted lastTell state after receiving
    -- whispers during M+ can only be cleared by /reload — document, don't
    -- scrub.
    runtime.lastIncomingWhisperKey = nil

    -- If Blizzard handled a whisper while we were suspended, its default chat
    -- edit box may still hold the latest reply target. Capture it into our own
    -- taint-safe reply state before scrubbing Blizzard's sticky attributes.
    if ChatReplyState and ChatReplyState.CaptureStaleWhisperReplyTarget then
      ChatReplyState.CaptureStaleWhisperReplyTarget(runtime, getNumChatWindows, getEditBox)
    end

    -- Scrub Blizzard's stale whisper sticky state on the default chat edit
    -- box. If the user replied via /r or R-key during M+ (Blizzard handled
    -- the whisper because we were suspended), chatType=WHISPER and
    -- tellTarget remain set. On the next Enter our auto-open poller would
    -- intercept that focused edit box and re-open the messenger to that
    -- conversation — even though the user has not asked for it.
    if ChatReplyState and ChatReplyState.ClearStaleWhisperReplyState then
      ChatReplyState.ClearStaleWhisperReplyState(getNumChatWindows, getEditBox)
    end

    local EventBridge = deps.getEventBridge and deps.getEventBridge() or ns.BootstrapEventBridge
    if EventBridge and Bootstrap._loadFrame then
      EventBridge.RegisterLiveEvents(Bootstrap._loadFrame)
      EventBridge.RegisterSuspendableLifecycleEvents(Bootstrap._loadFrame)
    end

    if Bootstrap.syncChatFilters then
      Bootstrap.syncChatFilters()
    elseif Bootstrap.registerChatFilters then
      Bootstrap.registerChatFilters()
    end

    -- Re-bind R → /wr now that we are out of M+ (if hide-whispers is on).
    if runtime.syncReplyKey then
      runtime.syncReplyKey()
    end
    if Bootstrap._wasVisibleBeforeMythic then
      setWindowVisible(true)
    end
    refreshWindow()
    Bootstrap._wasVisibleBeforeMythic = nil
  end

  return runtime
end

ns.BootstrapMythicSuspendController = MythicSuspendController
return MythicSuspendController
