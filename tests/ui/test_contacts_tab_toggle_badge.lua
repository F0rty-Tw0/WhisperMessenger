local FakeUI = require("tests.helpers.fake_ui")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")
local Localization = require("WhisperMessenger.Locale.Localization")

local function findChildFontString(frame, predicate)
  for _, child in ipairs(frame.children or {}) do
    if child.SetText and predicate(child) then
      return child
    end
    local nested = findChildFontString(child, predicate)
    if nested then
      return nested
    end
  end
  return nil
end

return function()
  local factory = FakeUI.NewFactory()

  local function createToggle()
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent:SetSize(260, 500)
    return TabToggle.Create(factory, parent, { initialMode = "whispers" })
  end

  -- test_labels_stay_plain_when_no_unread
  do
    local toggle = createToggle()
    toggle.setUnreadCounts(0, 0)
    assert(toggle.whispersLabel.text == "Whispers", "expected whispers label to be 'Whispers', got " .. tostring(toggle.whispersLabel.text))
    assert(toggle.groupsLabel.text == "Groups", "expected groups label to be 'Groups', got " .. tostring(toggle.groupsLabel.text))
  end

  -- test_labels_stay_plain_when_unread_present
  do
    local toggle = createToggle()
    toggle.setUnreadCounts(3, 5)
    assert(toggle.whispersLabel.text == "Whispers", "label must not embed count; got " .. tostring(toggle.whispersLabel.text))
    assert(toggle.groupsLabel.text == "Groups", "label must not embed count; got " .. tostring(toggle.groupsLabel.text))
  end

  -- test_russian_tab_labels
  do
    Localization.Configure({ language = "ruRU" })
    local toggle = createToggle()
    toggle.setUnreadCounts(0, 0)
    assert(toggle.whispersLabel.text == "Шепот", "expected localized whispers label")
    assert(toggle.groupsLabel.text == "Группы", "expected localized groups label")
    Localization.Configure({ language = "enUS" })
  end

  -- test_badge_shown_with_count_when_unread_positive
  do
    local toggle = createToggle()
    toggle.setUnreadCounts(3, 5)

    assert(toggle.whispersBadge ~= nil, "expected whispersBadge to be exposed on return value")
    assert(toggle.groupsBadge ~= nil, "expected groupsBadge to be exposed on return value")

    assert(toggle.whispersBadge.shown ~= false, "expected whispers badge to be shown when count > 0")
    assert(toggle.groupsBadge.shown ~= false, "expected groups badge to be shown when count > 0")

    local whispersText = findChildFontString(toggle.whispersBadge, function(c)
      return c.text == "3"
    end)
    assert(whispersText ~= nil, "expected whispers badge to render '3'")

    local groupsText = findChildFontString(toggle.groupsBadge, function(c)
      return c.text == "5"
    end)
    assert(groupsText ~= nil, "expected groups badge to render '5'")
  end

  -- test_badge_hidden_when_count_zero
  do
    local toggle = createToggle()
    toggle.setUnreadCounts(4, 2)
    toggle.setUnreadCounts(0, 0)
    assert(toggle.whispersBadge.shown == false, "expected whispers badge hidden when count is 0")
    assert(toggle.groupsBadge.shown == false, "expected groups badge hidden when count is 0")
  end

  -- test_badge_caps_at_99_plus
  do
    local toggle = createToggle()
    toggle.setUnreadCounts(100, 250)
    local whispersText = findChildFontString(toggle.whispersBadge, function(c)
      return c.text == "99+"
    end)
    assert(whispersText ~= nil, "expected whispers badge to cap at '99+' for counts > 99")
    local groupsText = findChildFontString(toggle.groupsBadge, function(c)
      return c.text == "99+"
    end)
    assert(groupsText ~= nil, "expected groups badge to cap at '99+' for counts > 99")
  end
end
