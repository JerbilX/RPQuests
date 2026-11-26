return function(h)
    local RunTest = h.RunTest
    local AssertEqual = h.AssertEqual
    local AssertTrue = h.AssertTrue
    local Addon = RPQuest

    local function ResetForTutorialTest(lang)
        h.mockState.skipTutorialSeed = false
        Addon.Locale:Initialize(lang or "en")
        local sv = Addon.QuestRepository:GetDefaults()
        Addon.QuestRepository:Initialize(sv)
        return sv
    end

    RunTest("Tutorial: first-time init seeds only Pill I in Pending", function()
        local sv = ResetForTutorialTest("en")
        AssertEqual(#sv.quests, 1, "Only 1 tutorial quest should be seeded initially")
        local q1 = sv.quests[1]
        AssertEqual(q1.isTutorial, true, "Pill I must be flagged isTutorial")
        AssertEqual(q1.tutorialStep, 1, "Pill I must have tutorialStep = 1")
        AssertEqual(q1.icon, "search", "Pill I icon must be search")
        AssertEqual(Addon.QuestRepository:IsOfferedQuest(q1), true, "Pill I must start in Pending (offered)")
        AssertEqual(#(q1.targets or {}), 0, "Pill I must have 0 targets")
        AssertEqual(#(q1.discoveries or {}), 0, "Pill I must have 0 discoveries")
        AssertEqual(#(q1.dialogues or {}), 2, "Pill I must have 2 NPC dialogues")
    end)

    RunTest("Tutorial: progressive seeding 1 -> 2 -> 3 on completion", function()
        local sv = ResetForTutorialTest("en")
        local q1 = sv.quests[1]
        AssertTrue(Addon.QuestRepository:AcceptOfferedQuest(q1.id), "Accept Pill I")
        Addon.QuestRepository:MarkDialogueTriggered(q1.id, 1)
        local ok1, _, comp1 = Addon.QuestRepository:MarkDialogueTriggered(q1.id, 2)
        AssertEqual(ok1, true, "Dialogue 2 triggered")
        AssertEqual(comp1, true, "Pill I completes after both dialogues")
        AssertEqual(#sv.quests, 2, "Completing Pill I should seed Pill II")

        local q2 = sv.quests[2]
        AssertEqual(q2.isTutorial, true, "Pill II isTutorial")
        AssertEqual(q2.tutorialStep, 2, "Pill II tutorialStep = 2")
        AssertEqual(q2.icon, "steal", "Pill II icon = steal")
        AssertEqual(q2.sequentialDiscoveries, true, "Pill II sequentialDiscoveries")
        AssertEqual(q2.stealthMode, Addon.Constants.STEALTH_MODE.OPTIONAL, "Pill II stealthMode = optional")
        AssertEqual(#(q2.discoveries or {}), 3, "Pill II has 3 discovery points")
        AssertEqual(Addon.QuestRepository:IsOfferedQuest(q2), true, "Pill II starts in Pending")

        AssertTrue(Addon.QuestRepository:AcceptOfferedQuest(q2.id), "Accept Pill II")
        Addon.QuestRepository:MarkDiscoveryTriggered(q2.id, 1)
        Addon.QuestRepository:MarkDiscoveryTriggered(q2.id, 2)
        local ok2, _, comp2 = Addon.QuestRepository:MarkDiscoveryTriggered(q2.id, 3)
        AssertEqual(ok2, true, "Discovery 3 triggered")
        AssertEqual(comp2, true, "Pill II completes after 3 discoveries")
        AssertEqual(#sv.quests, 3, "Completing Pill II should seed Pill III")

        local q3 = sv.quests[3]
        AssertEqual(q3.isTutorial, true, "Pill III isTutorial")
        AssertEqual(q3.tutorialStep, 3, "Pill III tutorialStep = 3")
        AssertEqual(q3.icon, "black_hand", "Pill III icon = black_hand")
        AssertEqual(#(q3.targets or {}), 2, "Pill III has 2 targets")
        AssertEqual(q3.targets[1].optional, false, "Pill III target 1 mandatory")
        AssertEqual(q3.targets[2].optional, true, "Pill III target 2 optional")
    end)

    RunTest("Tutorial: rejected or deleted pills are never re-seeded on reload", function()
        local sv = ResetForTutorialTest("en")
        local q1 = sv.quests[1]
        local rejected = Addon.QuestRepository:RejectOfferedQuest(q1.id)
        AssertEqual(rejected, true, "Reject Pill I")
        AssertEqual(#sv.quests, 0, "Quest list empty after rejecting Pill I")

        -- Simulate reload
        Addon.QuestRepository:Initialize(sv)
        AssertEqual(#sv.quests, 0, "Rejected Pill I must not be re-seeded on reload")

        -- Now test deleting Pill II after Pill I was completed
        local sv2 = ResetForTutorialTest("en")
        local p1 = sv2.quests[1]
        Addon.QuestRepository:AcceptOfferedQuest(p1.id)
        Addon.QuestRepository:MarkDialogueTriggered(p1.id, 1)
        Addon.QuestRepository:MarkDialogueTriggered(p1.id, 2)
        local p2 = sv2.quests[2]
        AssertTrue(p2 ~= nil, "Pill II seeded")
        AssertTrue(Addon.QuestRepository:DeleteQuest(p2.id), "Delete Pill II")
        Addon.QuestRepository:Initialize(sv2)
        AssertEqual(#sv2.quests, 1, "Deleted Pill II must not be re-seeded on reload")
    end)

    RunTest("Tutorial: resolving tutorial quests never triggers outbound mail", function()
        local origSendMail = _G.SendMail
        local mailCalls = 0
        _G.SendMail = function()
            mailCalls = mailCalls + 1
        end
        Addon.MailTransport:Initialize()

        local sv = ResetForTutorialTest("en")
        local q1 = sv.quests[1]
        q1.senderDisplayName = "@SomeMaster"
        Addon.QuestRepository:AcceptOfferedQuest(q1.id)
        Addon.QuestRepository:MarkDialogueTriggered(q1.id, 1)
        Addon.QuestRepository:MarkDialogueTriggered(q1.id, 2)
        local q2 = sv.quests[2]
        q2.senderDisplayName = "@SomeMaster"
        Addon.QuestRepository:RejectOfferedQuest(q2.id)

        _G.SendMail = origSendMail
        AssertEqual(mailCalls, 0, "Tutorial quests must never trigger SendMail")
    end)

    RunTest("Tutorial: canon contract test (schema, migration, clone, en/es keys)", function()
        local expectedSchema = Addon.Constants.QUEST_SCHEMA.CURRENT_VERSION
        local langs = { "en", "es" }
        local requiredKeys = {
            "TUTORIAL_SENDER_NAME", "TUTORIAL_MAP_DAGGERFALL",
            "TUTORIAL_1_TITLE", "TUTORIAL_1_DESC", "TUTORIAL_1_NPC_1_NAME", "TUTORIAL_1_NPC_1_CLUE",
            "TUTORIAL_1_NPC_1_RESPONSE", "TUTORIAL_1_NPC_2_NAME", "TUTORIAL_1_NPC_2_CLUE",
            "TUTORIAL_1_NPC_2_RESPONSE", "TUTORIAL_1_COMPLETION_MSG",
            "TUTORIAL_2_TITLE", "TUTORIAL_2_DESC", "TUTORIAL_2_DISC_1_MSG",
            "TUTORIAL_2_DISC_2_MSG", "TUTORIAL_2_DISC_3_MSG", "TUTORIAL_2_COMPLETION_MSG",
            "TUTORIAL_3_TITLE", "TUTORIAL_3_DESC", "TUTORIAL_3_TARGET_1_NAME",
            "TUTORIAL_3_TARGET_1_MSG", "TUTORIAL_3_TARGET_1_LOC_MSG",
            "TUTORIAL_3_TARGET_2_NAME", "TUTORIAL_3_TARGET_2_MSG", "TUTORIAL_3_COMPLETION_MSG",
        }

        for _, lang in ipairs(langs) do
            Addon.Locale:Initialize(lang)
            for _, key in ipairs(requiredKeys) do
                local val = Addon.Locale:Get(key)
                AssertTrue(type(val) == "string" and val ~= "" and val ~= key, "Missing/empty locale key " .. key .. " in " .. lang)
            end

            local sv = Addon.QuestRepository:GetDefaults()
            Addon.QuestRepository:Initialize(sv)
            for step = 1, 3 do
                local q = Addon.TutorialQuest:BuildQuestRecordForStep(Addon.QuestRepository, step, 100 + step)
                AssertEqual(q.schemaVersion, expectedSchema, "Step " .. step .. " must match CURRENT_VERSION")
                local _, didMigrate = Addon.QuestMigration:MigrateQuestRecord(q)
                AssertEqual(didMigrate, false, "Step " .. step .. " must not have pending migrations")
                AssertEqual(q.needsMigration, nil, "Step " .. step .. " must not need migration")
            end
        end
    end)

    RunTest("Tutorial: canonical resync preserves runtime progress on existing tutorial", function()
        local sv = ResetForTutorialTest("en")
        local q1 = sv.quests[1]
        Addon.QuestRepository:AcceptOfferedQuest(q1.id)
        Addon.QuestRepository:MarkDialogueTriggered(q1.id, 1)
        q1.title = "Old Outdated Tutorial Title"
        q1.schemaVersion = 3

        Addon.Locale:Initialize("es")
        Addon.QuestRepository:Initialize(sv)

        local refreshed = Addon.QuestRepository:GetQuestById(q1.id)
        AssertEqual(refreshed.schemaVersion, Addon.Constants.QUEST_SCHEMA.CURRENT_VERSION, "Refreshed schemaVersion")
        AssertEqual(refreshed.title, Addon.Locale:Get("TUTORIAL_1_TITLE"), "Title refreshed to active locale")
        AssertEqual(refreshed.dialogues[1].executed, true, "Dialogue 1 executed state preserved")
        AssertEqual(refreshed.dialogues[2].executed, false, "Dialogue 2 unexecuted state preserved")
        AssertEqual(refreshed.completed, false, "Completed state preserved")
    end)

    RunTest("Tutorial: Copy-to-Preparing allowed on tutorials, rejected on normal received quests", function()
        local sv = ResetForTutorialTest("en")
        local q1 = sv.quests[1]
        local copy, err = Addon.QuestRepository:DuplicateQuest(q1.id)
        AssertTrue(copy ~= nil, "Copy tutorial quest succeeds: " .. tostring(err))
        AssertEqual(copy.role, Addon.Constants.QUEST_ROLE.PREPARED, "Copy is PREPARED")
        AssertEqual(copy.lifecycle, Addon.Constants.QUEST_LIFECYCLE.DRAFT, "Copy is DRAFT in Preparing")
        AssertEqual(copy.isTutorial, nil, "Copy clears isTutorial flag")
        AssertEqual(copy.tutorialStep, nil, "Copy clears tutorialStep")

        local normalReceived = Addon.QuestRepository:BuildQuestRecord(999, "External", "Desc", {}, {
            senderDisplayName = "@ExternalGM",
            status = Addon.Constants.QUEST_STATUS.OFFERED,
        }, Addon.Constants.QUEST_ROLE.RECEIVED)
        table.insert(sv.quests, normalReceived)
        Addon.QuestRepository._questById[normalReceived.id] = normalReceived

        local denied, deniedErr = Addon.QuestRepository:DuplicateQuest(normalReceived.id)
        AssertEqual(denied, nil, "Normal received quest cannot be copied")
        AssertTrue(type(deniedErr) == "string" and deniedErr ~= "", "Error message returned for normal received quest")
    end)

    RunTest("Tutorial: EN/ES target names and Daggerfall dialogue matching", function()
        local sv = ResetForTutorialTest("es")
        local q1 = sv.quests[1]
        Addon.QuestRepository:AcceptOfferedQuest(q1.id)
        local match = Addon.QuestRepository:FindDialogueForActiveQuest("Lanobert^m", 3)
        AssertTrue(match ~= nil, "Pill I dialogue matches Lanobert in zone 3")

        local q3 = Addon.TutorialQuest:BuildQuestRecordForStep(Addon.QuestRepository, 3, 500)
        AssertEqual(q3.targets[1].name, "Rata", "ES target 1 is Rata")
        AssertEqual(q3.targets[2].name, "Oveja", "ES target 2 is Oveja")

        Addon.Locale:Initialize("en")
        local q3en = Addon.TutorialQuest:BuildQuestRecordForStep(Addon.QuestRepository, 3, 501)
        AssertEqual(q3en.targets[1].name, "Rat", "EN target 1 is Rat")
        AssertEqual(q3en.targets[2].name, "Sheep", "EN target 2 is Sheep")
    end)

    RunTest("Tutorial: JournalDetailPane shows Copy on tutorial pills and hides on regular received", function()
        local sv = ResetForTutorialTest("en")
        Addon.JournalTab:Initialize()
        local q1 = sv.quests[1]
        Addon.JournalTab:SelectQuest(q1.id)
        AssertEqual(Addon.JournalTab.btnCopy:IsHidden(), false, "Copy button visible on offered tutorial pill")

        local normalReceived = Addon.QuestRepository:BuildQuestRecord(998, "External", "Desc", {}, {
            senderDisplayName = "@ExternalGM",
            status = Addon.Constants.QUEST_STATUS.OFFERED,
        }, Addon.Constants.QUEST_ROLE.RECEIVED)
        table.insert(sv.quests, normalReceived)
        Addon.QuestRepository._questById[normalReceived.id] = normalReceived
        Addon.JournalTab:SelectQuest(normalReceived.id)
        AssertEqual(Addon.JournalTab.btnCopy:IsHidden(), true, "Copy button hidden on regular received quest")
    end)
end
