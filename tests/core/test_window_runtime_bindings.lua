local RuntimeBindings = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.RuntimeBindings")

return function()
  local visible = true
  local builtContacts = { { conversationKey = "wow::jaina" } }
  local selectedKey = nil
  local windowText = nil
  local window = {
    composer = {
      input = {
        SetText = function(_, text)
          windowText = text
        end,
      },
    },
  }
  local icon = { tag = "icon" }
  local runtime = {
    activeConversationKey = "wow::jaina",
  }
  local controller = {}

  local bindings = RuntimeBindings.Apply({
    runtime = runtime,
    controller = controller,
    icon = icon,
    getWindow = function()
      return window
    end,
    getIcon = function()
      return icon
    end,
    isWindowVisible = function()
      return visible
    end,
    buildContacts = function()
      return builtContacts
    end,
    ensureWindow = function()
      return "ensured"
    end,
    refreshWindow = function()
      return "refreshed"
    end,
    selectConversation = function(conversationKey)
      selectedKey = conversationKey
      return "selected"
    end,
    setWindowVisible = function(nextVisible)
      visible = nextVisible
      return "visibility"
    end,
    toggle = function()
      return "toggled"
    end,
    startConversation = function(name)
      return name == "Jaina"
    end,
  })

  assert(bindings.setComposerText == controller.setComposerText, "setComposerText should be exposed on controller")
  controller.setComposerText("hello")
  assert(windowText == "hello", "setComposerText should write composer input text")
  controller.setComposerText(nil)
  assert(windowText == "", "setComposerText should coerce nil to empty string")

  assert(controller.getWindow() == window, "controller.getWindow should return current window")
  assert(controller.getIcon() == icon, "controller.getIcon should return icon")
  assert(controller.isWindowVisible() == true, "controller.isWindowVisible should delegate visibility")

  assert(controller.buildContacts() == builtContacts, "controller.buildContacts should be wired")
  assert(controller.ensureWindow() == "ensured", "controller.ensureWindow should be wired")
  assert(controller.refreshWindow() == "refreshed", "controller.refreshWindow should be wired")
  assert(controller.selectConversation("wow::thrall") == "selected", "controller.selectConversation should be wired")
  assert(selectedKey == "wow::thrall", "selectConversation should receive key")
  assert(controller.setWindowVisible(false) == "visibility", "controller.setWindowVisible should be wired")
  assert(visible == false, "setWindowVisible should receive requested visibility")
  assert(controller.toggle() == "toggled", "controller.toggle should be wired")

  visible = true
  runtime.activeConversationKey = "wow::jaina"
  assert(runtime.isConversationOpen("wow::jaina") == true, "active visible conversation should be open")
  assert(runtime.isConversationOpen("wow::thrall") == false, "different conversation should not be open")
  visible = false
  assert(runtime.isConversationOpen("wow::jaina") == false, "hidden window should not report open conversation")

  -- test_covered_chat_is_not_open: a panel or the options pane hides the chat panes
  visible = true
  local panesShown = false
  window.isConversationPaneShown = function()
    return panesShown
  end
  assert(runtime.isConversationOpen("wow::jaina") == false, "a covered chat is not open")
  panesShown = true
  assert(runtime.isConversationOpen("wow::jaina") == true, "the uncovered chat is open again")
  window.isConversationPaneShown = nil
  visible = false

  assert(runtime.icon == icon, "runtime.icon should be wired")
  assert(runtime.toggle == controller.toggle, "runtime.toggle should share controller toggle")
  assert(runtime.refreshWindow == controller.refreshWindow, "runtime.refreshWindow should share controller refresh")
  assert(runtime.ensureWindow == controller.ensureWindow, "runtime.ensureWindow should share controller ensure")
  assert(runtime.setWindowVisible == controller.setWindowVisible, "runtime.setWindowVisible should share controller visibility")
  assert(runtime.isWindowVisible == controller.isWindowVisible, "runtime.isWindowVisible should share controller visibility")
  assert(runtime.isWindowVisible() == false, "runtime.isWindowVisible should delegate visibility")
  assert(runtime.setComposerText == controller.setComposerText, "runtime.setComposerText should share controller composer setter")

  assert(runtime.startConversation("Jaina") == true, "runtime.startConversation should be wired")

  local bare = {}
  RuntimeBindings.Apply({ runtime = bare, controller = {} })
  assert(bare.startConversation("x") == false, "startConversation should default to a refusal")

  -- test_external_preview_wiring_reaches_the_runtime
  local holder, widget, updates = {}, {}, 0
  local wired = {}
  RuntimeBindings.Apply({
    runtime = wired,
    controller = {},
    externalPreview = holder,
    getWidgetIcon = function()
      return widget
    end,
    updateIconSurfaces = function()
      updates = updates + 1
    end,
  })
  wired.updateIconSurfaces()
  assert(wired.externalPreview == holder and wired.getWidgetIcon() == widget and updates == 1, "external preview wiring reaches the runtime")
  assert(bare.getWidgetIcon() == nil, "getWidgetIcon should default to no widget")
  bare.updateIconSurfaces()
end
