local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local WhispersSettings = require("WhisperMessenger.UI.MessengerWindow.WhispersSettings")

-- "Addon greetings": Show / Send to Requests / Hide for whispers a crafting
-- addon announced as its automated greeting. "Send to Requests" is disabled
-- with a reason while the Requests inbox is off; the saved value is kept.

local LABEL = "Addon greetings"

local function create(config)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  local result = WhispersSettings.Create(factory, parent, config, {
    onChange = function(key, value)
      changes[key] = value
    end,
  })
  return result, changes
end

local function buttonsByLabel(result)
  local byLabel = {}
  for _, button in ipairs(FindUI.selectorButtons(result.frame, LABEL)) do
    byLabel[button.label:GetText()] = button
  end
  return byLabel
end

local function test_selector_offers_three_choices_defaulting_to_show()
  local buttons = buttonsByLabel(create({}))
  assert(buttons["Show"] and buttons["Send to Requests"] and buttons["Hide"], "Show / Send to Requests / Hide offered")
  assert(buttons["Show"]._selected == true, "never-saved value shows Show")
end

local function test_choosing_hide_reports_the_setting()
  local result, changes = create({})
  FindUI.click(buttonsByLabel(result)["Hide"])
  assert(changes.addonGreetings == "hide", "Hide saves addonGreetings = hide")
end

local function test_requests_choice_disabled_while_inbox_off()
  local result, changes = create({ requestsInbox = false })
  local requests = buttonsByLabel(result)["Send to Requests"]
  assert(FindUI.disabledCover(requests) ~= nil, "Send to Requests disabled while Requests is off")
  FindUI.click(requests)
  assert(changes.addonGreetings == nil, "a disabled choice does not save")
end

local function test_requests_choice_enabled_with_inbox_on()
  local result, changes = create({ requestsInbox = true })
  local requests = buttonsByLabel(result)["Send to Requests"]
  assert(FindUI.disabledCover(requests) == nil, "Send to Requests enabled while Requests is on")
  FindUI.click(requests)
  assert(changes.addonGreetings == "requests", "Send to Requests saves addonGreetings = requests")
end

local function test_turning_requests_on_enables_the_choice_live()
  local result = create({ requestsInbox = false })
  FindUI.click(FindUI.toggle(result.frame, "Put whispers from strangers in Requests"))
  assert(FindUI.disabledCover(buttonsByLabel(result)["Send to Requests"]) == nil, "choice enabled once Requests is turned on")
end

local function test_saved_requests_value_is_kept_while_inbox_off()
  local buttons = buttonsByLabel(create({ requestsInbox = false, addonGreetings = "requests" }))
  assert(buttons["Send to Requests"]._selected == true, "saved choice still shows, just disabled")
end

local function test_reset_restores_show()
  local result, changes = create({ addonGreetings = "hide" })
  FindUI.click(FindUI.byLabel(result.frame, "Reset to Defaults"))
  assert(changes.addonGreetings == "show", "reset puts addon greetings back to Show")
end

return function()
  Localization.Configure({ language = "enUS" })
  test_selector_offers_three_choices_defaulting_to_show()
  test_choosing_hide_reports_the_setting()
  test_requests_choice_disabled_while_inbox_off()
  test_requests_choice_enabled_with_inbox_on()
  test_turning_requests_on_enables_the_choice_live()
  test_saved_requests_value_is_kept_while_inbox_off()
  test_reset_restores_show()
end
