local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Runtime fields that stay nil until something sets them. Every other field
-- gets its default in RuntimeFactory.CreateRuntimeState.
local OptionalFields = {
  -- Identity the client may not know yet, or never reports.
  "activeConversationKey",
  "localPlayerGuid",
  "localPlayerName",
  "localBnetAccountID",
  "getBNetInfo",
  "playerInfoByGUID",
  "localFaction",
  -- Window state: nothing is built until the first open.
  "window",
  "icon",
  "compactLayoutActive",
  "externalPreview",
  "hiddenByCombat",
  "unreadDivider",
  -- Messaging state with no value until the first event.
  "lastIncomingWhisperKey",
  "lastIncomingWhisperAt",
  "messagingNotice",
  -- Built on first use, dropped again when empty.
  "lockdownReplay",
  "messageReactionRuntime",
  "messageReactionCleanupDueAt",
  "messageReactionPendingSequence",
  -- Wired once by Bootstrap.Initialize and PublicApi.Publish.
  "restrictedActions",
  "seenLevelEvents",
  "autoOpenCoordinator",
  "autoOpenHooks",
  "lockdownCatcher",
  "addonIntegrations",
  "integrationAllowedAtLoad",
  "apiCaller",
  -- Callbacks whose absence means something to a caller, so they get no
  -- default: isConversationOpen (falls back to the active key),
  -- isWindowVisible (relationship repaints assume visible), isChatLocked
  -- (held whispers are not ready), getActivePreviewSurface (falls back to
  -- the widget icon), ensureWindow (reply-to-last falls back to toggle).
  "isConversationOpen",
  "isWindowVisible",
  "isChatLocked",
  "getActivePreviewSurface",
  "ensureWindow",
}

ns.BootstrapRuntimeFactoryOptionalFields = OptionalFields
return OptionalFields
