-- The contacts runtime forwards the window's row actions table to the
-- contacts controller as one table, not key by key.
local FakeUI = require("tests.helpers.fake_ui")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local ContactsRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsRuntime")
local ContactsController = require("WhisperMessenger.UI.MessengerWindow.ContactsController")

local ROW_ACTIONS = { "onPin", "onRemove", "onMarkUnread", "onUpdatePrefs", "onIgnorePlayer", "onUnblockPlayer", "isPlayerBlocked", "whoPlayer" }

-- Builds the runtime and returns the options its controller was created with.
local function controllerOptionsFor(runtimeOptions)
  local factory = FakeUI.NewFactory()
  local window = factory.CreateFrame("Frame", nil, nil)
  local pane = factory.CreateFrame("Frame", nil, window)
  pane:SetSize(200, 400)
  runtimeOptions.contactsPane = pane
  runtimeOptions.contactsView = ScrollView.Create(factory, pane, { width = 200, height = 400 })
  runtimeOptions.settingsConfig = {}
  local controllerOptions
  local create = ContactsController.Create
  rawset(ContactsController, "Create", function(controllerFactory, view, contacts, options)
    controllerOptions = options
    return create(controllerFactory, view, contacts, options)
  end)
  ContactsRuntime.Create(factory, runtimeOptions)
  rawset(ContactsController, "Create", create)
  return controllerOptions
end

return function()
  -- test_controller_gets_the_row_actions_table_itself
  do
    local rowActions = { onPin = function() end, whoPlayer = function() end }
    local controllerOptions = controllerOptionsFor({ rowActions = rowActions })
    assert(controllerOptions.rowActions == rowActions, "the controller gets the same table the runtime was given")
  end

  -- test_actions_outside_the_row_actions_table_are_not_forwarded
  do
    local controllerOptions = controllerOptionsFor({ onPin = function() end, whoPlayer = function() end })
    assert(controllerOptions.rowActions == nil, "only options.rowActions reaches the controller")
  end

  -- test_row_actions_are_not_listed_again_for_the_controller
  do
    local rowActions = {}
    for _, name in ipairs(ROW_ACTIONS) do
      rowActions[name] = function() end
    end
    local controllerOptions = controllerOptionsFor({ rowActions = rowActions })
    for _, name in ipairs(ROW_ACTIONS) do
      assert(controllerOptions[name] == nil, name .. " travels only inside the row actions table")
    end
  end
end
