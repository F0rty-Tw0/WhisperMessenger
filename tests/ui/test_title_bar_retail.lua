local FakeUI = require("tests.helpers.fake_ui")
local RetailHud = require("tests.helpers.retail_hud")
local Theme = require("WhisperMessenger.UI.Theme")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")

local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  return ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, { useNativeChrome = true })
end

local function assertLeftOf(region, target, label)
  local point, relativeTo, relativePoint = region:GetPoint()
  assert(
    point == "RIGHT" and relativeTo == target and relativePoint == "LEFT",
    label .. ": expected RIGHT of it on the LEFT of its neighbour, got " .. tostring(point) .. "/" .. tostring(relativePoint)
  )
end

return function()
  local L = Theme.LAYOUT

  -- test_retail_gear_and_close_keep_the_classic_right_cluster
  RetailHud.With(function()
    local chrome = build()
    assertLeftOf(chrome.optionsButton, chrome.closeButton, "gear")
  end)

  -- test_retail_buttons_keep_the_no_hud_arrangement
  -- Same order as the other looks (user): new whisper, What's New and
  -- mark-all-read on the left, starting where the title bar clears the round
  -- portrait (the template's TitleContainer); back next to the gear.
  RetailHud.With(function()
    local chrome = build()
    local point, relativeTo, relativePoint = chrome.newConversationButton:GetPoint()
    assert(
      point == "LEFT" and relativeTo == chrome.frame.TitleContainer and relativePoint == "LEFT",
      "new whisper: starts at the title bar's left, right of the portrait"
    )
    local _, patchTo = chrome.patchNotesButton:GetPoint()
    assert(patchTo == chrome.newConversationButton, "What's New follows new whisper")
    local _, markTo = chrome.markAllReadButton:GetPoint()
    assert(markTo == chrome.patchNotesButton, "mark all read follows What's New")
    assertLeftOf(chrome.backButton, chrome.optionsButton, "back")
  end)

  -- test_retail_title_buttons_keep_the_hud_size
  RetailHud.With(function()
    local chrome = build()
    for _, button in ipairs({ chrome.newConversationButton, chrome.patchNotesButton, chrome.markAllReadButton, chrome.optionsButton }) do
      assert(button.width == L.CHROME_BUTTON_SIZE, "retail: HUD button size, got " .. tostring(button.width))
    end
  end)

  -- test_retail_title_buttons_draw_above_the_template_title_art
  -- In game the ButtonFrameTemplate title-bar art sat over our buttons: only
  -- the template's own close button (raised high) stayed visible.
  RetailHud.With(function()
    local factory = RetailHud.Factory(FakeUI, {
      decorate = function(frame, template)
        if template == "ButtonFrameTemplate" and frame.CloseButton then
          frame.CloseButton:SetFrameLevel(510)
        end
      end,
    })
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local chrome = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, { useNativeChrome = true })
    for _, key in ipairs({ "newConversationButton", "patchNotesButton", "markAllReadButton", "optionsButton", "backButton" }) do
      local level = chrome[key]:GetFrameLevel()
      assert(level >= 510, key .. ": drawn at the close button's level or above, got " .. tostring(level))
    end
  end)

  -- test_classic_left_cluster_stays_top_left
  do
    local chrome = build()
    local point, relativeTo = chrome.newConversationButton:GetPoint()
    assert(point == "TOPLEFT" and relativeTo == chrome.frame, "classic: new whisper stays in the top-left corner")
  end
end
