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
end
