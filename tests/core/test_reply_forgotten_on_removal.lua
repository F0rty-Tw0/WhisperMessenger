local Store = require("WhisperMessenger.Model.ConversationStore")
local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")
local RuntimeBindings = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.RuntimeBindings")
local Composer = require("WhisperMessenger.UI.Composer")
local FakeUI = require("tests.helpers.fake_ui")

-- Removing a conversation drops its pending "Replying to" target, so a new
-- chat with the same player never starts out replying to a gone message.
return function()
  -- test_store_removal_notifies_the_runtime
  do
    local runtime = RuntimeFactory.CreateRuntimeState({}, {}, "me", {})
    Store.EnsureConversation(runtime.store, "wow::thrall")
    local removed = {}
    runtime.onConversationRemoved = function(key)
      removed[#removed + 1] = key
    end
    Store.Remove(runtime.store, "wow::thrall")
    assert(removed[1] == "wow::thrall", "runtime hook called with the removed key")
  end

  -- test_bindings_forward_removal_to_the_composer
  do
    local forgotten = {}
    local window = {
      composer = {
        forgetReply = function(key)
          forgotten[#forgotten + 1] = key
        end,
      },
    }
    local runtime = { store = Store.New({}) }
    RuntimeBindings.Apply({
      runtime = runtime,
      controller = {},
      getWindow = function()
        return window
      end,
    })
    runtime.onConversationRemoved("wow::thrall")
    assert(forgotten[1] == "wow::thrall", "open window forgets the reply")
  end

  -- test_composer_forget_reply_clears_the_target
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "parent", nil)
    parent:SetSize(600, 50)
    local sent = {}
    local composer = Composer.Create(factory, parent, { conversationKey = "a", displayName = "Thrall", channel = "WOW" }, function(payload)
      sent[#sent + 1] = payload
      return true
    end)
    composer.setReply("a", { wireId = "w1", direction = "in", snippet = "hi" })
    composer.forgetReply("a")
    composer.input:SetText("hello")
    composer.input.scripts.OnEnterPressed(composer.input)
    assert(sent[1].replyTo == nil, "no reply after the conversation was removed")
  end
end
