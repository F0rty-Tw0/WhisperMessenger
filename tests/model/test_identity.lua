local Identity = require("WhisperMessenger.Model.Identity")

return function()
  local contact = Identity.FromWhisper("Arthas-Area52", "Player-3676-0ABCDEF0", {
    className = "Priest",
    classTag = "PRIEST",
    raceName = "Human",
    raceTag = "Human",
    factionName = "Alliance",
  })
  assert(contact.channel == "WOW")
  assert(contact.contactKey == "WOW::arthas-area52")
  assert(contact.displayName == "Arthas-Area52")
  assert(contact.guid == "Player-3676-0ABCDEF0")
  assert(contact.className == "Priest")
  assert(contact.classTag == "PRIEST")
  assert(contact.raceName == "Human")
  assert(contact.raceTag == "Human")
  assert(contact.factionName == "Alliance")

  local bnetContact = Identity.FromBattleNet(99, {
    battleTag = "Jaina#1234",
    accountName = "Jaina",
    gameAccountInfo = {
      characterName = "Jaina",
      realmName = "Proudmoore",
      playerGuid = "Player-60-0ABCDE123",
      className = "Mage",
      raceName = "Human",
      factionName = "Alliance",
    },
  })

  assert(bnetContact.channel == "BN")
  assert(
    bnetContact.contactKey == "BN::jaina#1234",
    "expected battleTag-based key, got " .. tostring(bnetContact.contactKey)
  )
  assert(bnetContact.displayName == "Jaina#1234")
  assert(bnetContact.bnetAccountID == 99)
  assert(bnetContact.gameAccountName == "Jaina-Proudmoore")
  assert(bnetContact.guid == "Player-60-0ABCDE123")
  assert(bnetContact.className == "Mage")
  assert(bnetContact.raceName == "Human")
  assert(bnetContact.factionName == "Alliance")

  -- BuildConversationKey with battleTag-based contactKey produces stable bnet key
  local convKey = Identity.BuildConversationKey("me-area52", bnetContact.contactKey)
  assert(convKey == "bnet::BN::jaina#1234", "expected bnet conversation key, got " .. tostring(convKey))

  -- FromBattleNet without accountInfo falls back to numeric bnetAccountID
  local fallbackContact = Identity.FromBattleNet(11, nil)
  assert(
    fallbackContact.contactKey == "BN::11",
    "expected numeric fallback key, got " .. tostring(fallbackContact.contactKey)
  )
  assert(
    fallbackContact.canonicalName == "11",
    "expected numeric fallback canonicalName, got " .. tostring(fallbackContact.canonicalName)
  )

  -- FromBattleNet with accountInfo missing battleTag also falls back to numeric
  local noBattleTagContact = Identity.FromBattleNet(22, { accountName = "someone" })
  assert(
    noBattleTagContact.contactKey == "BN::22",
    "expected numeric fallback when no battleTag, got " .. tostring(noBattleTagContact.contactKey)
  )

  -- FromWhisper detaints secret strings via Ambiguate before string ops
  local ambiguateCalled = false
  rawset(_G, "Ambiguate", function(name, context)
    ambiguateCalled = true
    assert(context == "none", "expected context 'none', got " .. tostring(context))
    return name -- in tests, name is already a plain string
  end)

  local taintedContact = Identity.FromWhisper("Thrall-Nagrand", "Player-11-0ABC", {})
  assert(ambiguateCalled, "expected Ambiguate to be called for whisper names")
  assert(
    taintedContact.contactKey == "WOW::thrall-nagrand",
    "expected detainted contactKey, got " .. tostring(taintedContact.contactKey)
  )
  assert(taintedContact.displayName == "Thrall-Nagrand")

  rawset(_G, "Ambiguate", nil)

  -- During tainted execution (mythic lockdown), Ambiguate rejects secret
  -- strings.  normalizeName must not crash — it should degrade gracefully.
  rawset(_G, "Ambiguate", function()
    error("secret values are only allowed during untainted execution")
  end)

  local ok, taintedBnet = pcall(Identity.FromBattleNet, 55, { battleTag = "Locked#9999" })
  assert(ok, "FromBattleNet must not crash during tainted execution, got: " .. tostring(taintedBnet))
  -- contactKey should still be usable (empty normalization fallback)
  assert(taintedBnet.contactKey ~= nil, "expected non-nil contactKey during tainted execution")

  local ok2, taintedWhisper = pcall(Identity.FromWhisper, "Locked-Realm", "Player-99-0ABC", {})
  assert(ok2, "FromWhisper must not crash during tainted execution, got: " .. tostring(taintedWhisper))
  assert(taintedWhisper.contactKey ~= nil, "expected non-nil contactKey during tainted execution")

  rawset(_G, "Ambiguate", nil)
end
