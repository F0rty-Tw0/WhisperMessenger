local Store = require("WhisperMessenger.Model.ConversationStore")
local RuntimeBindings = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.RuntimeBindings")

return function()
  -- test_set_composer_text_lands_in_the_active_conversation_draft
  local runtime = { activeConversationKey = "wow::jaina", store = Store.New({}) }
  Store.EnsureConversation(runtime.store, "wow::jaina")
  local controller = {}
  RuntimeBindings.Apply({ runtime = runtime, controller = controller })

  -- No window yet (lazy creation): the text must still survive as a draft.
  controller.setComposerText("typed in combat")
  assert(runtime.store.conversations["wow::jaina"].draft == "typed in combat", "combat-typed text becomes the target conversation's draft")

  -- test_set_composer_text_without_active_conversation_is_safe
  runtime.activeConversationKey = nil
  controller.setComposerText("nowhere")
  assert(runtime.store.conversations["wow::jaina"].draft == "typed in combat", "no active conversation -> no draft written")
end
