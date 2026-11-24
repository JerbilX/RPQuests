-- ============================================================================
-- RPQuest Test Suite: DialogueInjector & 1-to-1 Model Suites
-- ============================================================================
return function(T)
    local RunTest = T.RunTest
    local AssertEqual = T.AssertEqual
    local AssertTrue = T.AssertTrue
    local mockState = T.mockState
    local mockPinManager = T.mockPinManager

    RunTest("NPC Dialogues, Clue, HideMapArea, RPQ3 codec, and DialogueInjector hook", function()
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:SetActiveQuest(nil)

        -- 1. Session capture via EVENT_CHATTER_BEGIN (OnChatterBegin)
        local currentInteractName = "Mercader Sospechoso^m"
        _G.GetUnitName = function(unitTag)
            if unitTag == "interact" then return currentInteractName end
            return "Jugador"
        end
        mockState.worldX = 12000
        mockState.worldZ = 22000
        mockState.zoneId = 381

        RPQuest.DialogueInjector:OnChatterBegin()
        local lastNpc = RPQuest.QuestRepository:GetLastInteractedNpc()
        AssertTrue(lastNpc ~= nil, "Last interacted NPC captured")
        AssertEqual(lastNpc.name, "Mercader Sospechoso", "NPC name normalized without gender suffix")
        AssertEqual(lastNpc.zoneId, 381, "NPC zoneId captured")

        -- 2. Draft dialogue management (0..3 max, duplicate prevention)
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:UpdateDraftFields({
            clue = "el sello roto",
            recommendHideMapAreas = true,
        })
        local ok1, idx1 = RPQuest.QuestRepository:AddDraftDialogueFromLastNpc("Vi a un encapuchado huir hacia los muelles.")
        AssertTrue(ok1 ~= nil and idx1 == 1, "Dialogue #1 added from last NPC")

        local dupOk, dupErr = RPQuest.QuestRepository:AddDraftDialogueFromLastNpc("Repetido")
        AssertEqual(dupOk, nil, "Duplicate NPC rejected")
        AssertTrue(type(dupErr) == "string" and dupErr ~= "", "Duplicate NPC returns error message")

        currentInteractName = "Guardia del Puerto^f"
        RPQuest.DialogueInjector:OnChatterBegin()
        RPQuest.QuestRepository:AddDraftDialogueFromLastNpc("Nadie entra sin pase; revisa el almacén sur.")

        currentInteractName = "Tabernero^m"
        RPQuest.DialogueInjector:OnChatterBegin()
        RPQuest.QuestRepository:AddDraftDialogueFromLastNpc("Dejó una nota bajo la mesa 4~5; busca allí.")

        currentInteractName = "Cuarto NPC"
        RPQuest.DialogueInjector:OnChatterBegin()
        local ok4, idx4 = RPQuest.QuestRepository:AddDraftDialogueFromLastNpc("Cuarta pista.")
        AssertTrue(ok4 ~= nil and idx4 == 4, "4th NPC dialogue accepted (max 4)")

        currentInteractName = "Quinto NPC"
        RPQuest.DialogueInjector:OnChatterBegin()
        local limitOk, limitErr = RPQuest.QuestRepository:AddDraftDialogueFromLastNpc("Excede")
        AssertEqual(limitOk, nil, "5th NPC dialogue rejected (max 4)")
        AssertTrue(type(limitErr) == "string" and limitErr ~= "", "Limit error returned")

        -- Capture target and save quest
        mockState.reticleExists = true
        mockState.reticleName = "Contrabandista"
        RPQuest.TargetCapture:CaptureFromReticle()
        local saved = RPQuest.QuestRepository:SaveDraft("El Sello Roto", "Investiga en el puerto.")
        AssertTrue(saved ~= nil, "Quest with dialogues and recommendHideMapAreas saved")
        AssertEqual(saved.clue, "el sello roto", "Clue persisted on quest")
        AssertEqual(saved.recommendHideMapAreas, true, "recommendHideMapAreas persisted on quest")
        AssertEqual(#saved.dialogues, 4, "4 dialogues persisted on quest")

        -- 3. WorldMapArea respects recommendHideMapAreas when showSearchAreas is false
        RPQuest.QuestRepository:SetActiveQuest(saved.id)
        mockPinManager._createdPins = {}
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 0, "WorldMapArea does not render pin when recommendHideMapAreas is true and showSearchAreas is false")

        -- 4. ShareCodec RPQ3 roundtrip
        local code = RPQuest.QuestRepository:ExportQuestToCode(saved.id)
        AssertTrue(type(code) == "string" and code:sub(1, 5) == "RPQ3:", "Exported code uses RPQ3 prefix")

        local imported = RPQuest.QuestRepository:ImportQuestFromCode(code)
        AssertTrue(imported ~= nil, "RPQ3 quest imported successfully")
        AssertEqual(imported.clue, "el sello roto", "Imported clue preserved")
        AssertEqual(imported.recommendHideMapAreas, true, "Imported recommendHideMapAreas preserved")
        AssertEqual(#imported.dialogues, 4, "Imported 4 dialogues preserved")
        AssertEqual(imported.dialogues[3].response, "Dejó una nota bajo la mesa 4~5; busca allí.", "Special chars in dialogue response preserved")

        -- Imported quest with hideMapArea also hides pin
        mockPinManager._createdPins = {}
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 0, "Imported quest with hideMapArea=true renders 0 map pins")

        -- 5. DialogueInjector hook on ZO_Interaction
        local bodyTextValue = "Saludos, viajero."
        local populatedOptions = {}
        local finalizedCount = nil
        local selectChatterCalled = false
        _G.SelectChatterOption = function() selectChatterCalled = true end
        _G.CHATTER_TALK_CHOICE = 1
        _G.CHATTER_GOODBYE = 2
        _G.MAX_CHATTER_OPTIONS = 10

        local mockBodyLabel = { SetText = function(_, txt) bodyTextValue = txt end }
        local mockControl = { GetNamedChild = function(_, name) if name == "TargetAreaBodyText" then return mockBodyLabel end end }

        local MockInteraction = { optionControls = {} }
        function MockInteraction:PopulateChatterOption(controlID, optionIndex, optionText, optionType, optionalArg, isImportant, chosenBefore)
            local ctrl = { chosenBefore = chosenBefore, SetColor = function(c, r, g, b, a) c._color = { r, g, b, a } end }
            self.optionControls[controlID] = ctrl
            table.insert(populatedOptions, {
                controlID = controlID,
                optionIndex = optionIndex,
                optionText = optionText,
                optionType = optionType,
                chosenBefore = chosenBefore,
            })
        end
        function MockInteraction:FinalizeChatterOptions(optionCount)
            finalizedCount = optionCount
        end
        function MockInteraction:PopulateChatterOptions(optionCount)
            for i = 1, optionCount do
                self:PopulateChatterOption(i, i, "Nativa " .. i, CHATTER_TALK_CHOICE)
            end
            local nextId = optionCount + 1
            self:PopulateChatterOption(nextId, function() end, "Adiós", CHATTER_GOODBYE)
            self:FinalizeChatterOptions(nextId)
            return nextId, {}
        end
        MockInteraction.control = mockControl
        _G.ZO_Interaction = MockInteraction
        RPQuest.DialogueInjector:InstallHooks()

        -- Matching NPC: injects RPQuest option before CHATTER_GOODBYE
        currentInteractName = "Tabernero^m"
        mockState.zoneId = 381
        populatedOptions = {}
        local finalCount = MockInteraction:PopulateChatterOptions(1)
        AssertEqual(finalCount, 3, "Injected 1 option before CHATTER_GOODBYE (total 3)")
        AssertEqual(finalizedCount, 3, "FinalizeChatterOptions received updated count 3")
        AssertEqual(populatedOptions[2].optionText, "el sello roto", "Injected option text uses exact player dialogue text")
        AssertEqual(type(populatedOptions[2].optionIndex), "function", "Injected optionIndex is a Lua callback function")
        AssertEqual(populatedOptions[3].optionType, CHATTER_GOODBYE, "CHATTER_GOODBYE remains last option")

        -- Clicking injected option updates NPC body text without calling SelectChatterOption and grays out option
        AssertEqual(populatedOptions[2].chosenBefore, false, "Option starts unseen (chosenBefore=false)")
        populatedOptions[2].optionIndex()
        AssertEqual(bodyTextValue, "Dejó una nota bajo la mesa 4~5; busca allí.", "NPC response shown in TargetAreaBodyText")
        AssertEqual(selectChatterCalled, false, "SelectChatterOption is never called for RPQuest dialogue")
        AssertEqual(MockInteraction.optionControls[2].chosenBefore, true, "Clicked option marked chosenBefore=true")
        AssertTrue(MockInteraction.optionControls[2]._color ~= nil, "Clicked option color updated to disabled/seen gray")

        -- Re-opening dialogue with same NPC keeps chosenBefore=true
        populatedOptions = {}
        MockInteraction:PopulateChatterOptions(1)
        AssertEqual(populatedOptions[2].chosenBefore, true, "Re-opened dialogue preserves chosenBefore=true")

        -- Non-matching NPC: native options untouched
        currentInteractName = "Mendigo Aleatorio"
        populatedOptions = {}
        local untouchedCount = MockInteraction:PopulateChatterOptions(1)
        AssertEqual(untouchedCount, 2, "Non-matching NPC has untouched option count")
        AssertEqual(populatedOptions[2].optionType, CHATTER_GOODBYE, "Non-matching NPC keeps native CHATTER_GOODBYE at 2")

        -- MAX_CHATTER_OPTIONS cap respected
        currentInteractName = "Tabernero^m"
        populatedOptions = {}
        local cappedCount = MockInteraction:PopulateChatterOptions(9)
        AssertEqual(cappedCount, 10, "At MAX_CHATTER_OPTIONS=10 (9 native + goodbye), does not overflow")
        AssertEqual(populatedOptions[10].optionType, CHATTER_GOODBYE, "CHATTER_GOODBYE preserved at cap")

        -- 6. Legacy RPQ1/RPQ2 rejected and RPQ3 rejected as completion code
        local decRpq1, errRpq1 = RPQuest.ShareCodec:DecodeQuest("RPQ1:1234:abcd")
        AssertEqual(decRpq1, nil, "DecodeQuest rejects legacy RPQ1 code")
        AssertEqual(errRpq1, "ERR_IMPORT_UNSUPPORTED_VERSION", "RPQ1 rejected with ERR_IMPORT_UNSUPPORTED_VERSION")
        local decRpq2, errRpq2 = RPQuest.ShareCodec:DecodeQuest("RPQ2:1234:abcd")
        AssertEqual(decRpq2, nil, "DecodeQuest rejects legacy RPQ2 code")
        AssertEqual(errRpq2, "ERR_IMPORT_UNSUPPORTED_VERSION", "RPQ2 rejected with ERR_IMPORT_UNSUPPORTED_VERSION")

        local okComp, errComp = RPQuest.ShareCodec:DecodeCompletion(code)
        AssertEqual(okComp, nil, "DecodeCompletion rejects RPQ3 code")
        AssertEqual(errComp, "VALIDATE_ERR_NOT_COMPLETION_CODE", "RPQ3 rejected with VALIDATE_ERR_NOT_COMPLETION_CODE")
    end)

    RunTest("30. Per-NPC player dialogue option, ShareCodec RPQ3 roundtrip, and JournalTab selected NPC indicator", function()
        RPQuest.JournalTab:Initialize()
        RPQuest.QuestRepository:ResetDraft()

        -- Add 2 NPCs with distinct player dialogue options and responses
        local _, idx1 = RPQuest.QuestRepository:AddDraftDialogue("Farseer Kuamta", 381, "Look near the northern shrine.", "Ask about the shrine")
        local _, idx2 = RPQuest.QuestRepository:AddDraftDialogue("Vasamannu", 381, "He lives to the south, I don't care.", "Daynill? Know him?")
        AssertEqual(idx1, 1, "First NPC added at index 1")
        AssertEqual(idx2, 2, "Second NPC added at index 2")

        -- Capture a target and save quest
        mockState.reticleExists = true
        mockState.reticleName = "Bandit"
        RPQuest.TargetCapture:CaptureFromReticle()
        local saved = RPQuest.QuestRepository:SaveDraft("Per-NPC Clues", "Test distinct options per NPC.")
        AssertTrue(saved ~= nil, "Quest saved with per-NPC clues")
        AssertEqual(saved.dialogues[1].clue, "Ask about the shrine", "NPC 1 clue persisted")
        AssertEqual(saved.dialogues[2].clue, "Daynill? Know him?", "NPC 2 clue persisted")

        -- Active quest dialogue lookup returns each NPC's own clue
        RPQuest.QuestRepository:SetActiveQuest(saved.id)
        local match1 = RPQuest.QuestRepository:FindDialogueForActiveQuest("Farseer Kuamta", 381)
        local match2 = RPQuest.QuestRepository:FindDialogueForActiveQuest("Vasamannu", 381)
        AssertTrue(match1 ~= nil and match1.clue == "Ask about the shrine", "FindDialogueForActiveQuest returns NPC 1's own option")
        AssertTrue(match2 ~= nil and match2.clue == "Daynill? Know him?", "FindDialogueForActiveQuest returns NPC 2's own option")

        -- ShareCodec RPQ3 roundtrip preserves distinct per-NPC clues
        local code = RPQuest.QuestRepository:ExportQuestToCode(saved.id)
        local imported = RPQuest.QuestRepository:ImportQuestFromCode(code)
        AssertTrue(imported ~= nil, "RPQ3 quest with per-NPC clues imported")
        AssertEqual(imported.dialogues[1].clue, "Ask about the shrine", "Imported NPC 1 clue preserved")
        AssertEqual(imported.dialogues[2].clue, "Daynill? Know him?", "Imported NPC 2 clue preserved")

        -- JournalTab editor shows selected NPC name and per-NPC option/response when cycling
        RPQuest.JournalTab:OpenEditEditor(saved.id)
        AssertEqual(RPQuest.JournalTab.selectedDialogueIndex, 1, "Editor selects first NPC on open")
        AssertTrue(RPQuest.JournalTab.lblSelectedNpc:GetText():find("Farseer Kuamta", 1, true) ~= nil, "lblSelectedNpc shows Farseer Kuamta")
        AssertTrue(RPQuest.JournalTab.lblInputClue:GetText():find("Farseer Kuamta", 1, true) ~= nil, "lblInputClue shows Farseer Kuamta")
        AssertTrue(RPQuest.JournalTab.lblDlgResponse:GetText():find("Farseer Kuamta", 1, true) ~= nil, "lblDlgResponse shows Farseer Kuamta")
        AssertEqual(RPQuest.JournalTab.clueEdit:GetText(), "Ask about the shrine", "clueEdit shows NPC 1 option")
        AssertEqual(RPQuest.JournalTab.dlgResponseEdit:GetText(), "Look near the northern shrine.", "dlgResponseEdit shows NPC 1 response")

        -- Cycle to NPC 2
        RPQuest.JournalTab.btnDlgNext:FireHandler("OnClicked")
        AssertEqual(RPQuest.JournalTab.selectedDialogueIndex, 2, "Editor cycles to second NPC")
        AssertTrue(RPQuest.JournalTab.lblSelectedNpc:GetText():find("Vasamannu", 1, true) ~= nil, "lblSelectedNpc updates to Vasamannu")
        AssertTrue(RPQuest.JournalTab.lblInputClue:GetText():find("Vasamannu", 1, true) ~= nil, "lblInputClue updates to Vasamannu")
        AssertTrue(RPQuest.JournalTab.lblDlgResponse:GetText():find("Vasamannu", 1, true) ~= nil, "lblDlgResponse updates to Vasamannu")
        AssertEqual(RPQuest.JournalTab.clueEdit:GetText(), "Daynill? Know him?", "clueEdit updates to NPC 2 option")
        AssertEqual(RPQuest.JournalTab.dlgResponseEdit:GetText(), "He lives to the south, I don't care.", "dlgResponseEdit updates to NPC 2 response")
    end)

    RunTest("1-to-1 model: group sharing disabled, group tracking ignored, and DialogueInjector works after mail accept without /reloadui (Issue #142)", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.MailTransport:Initialize()
        RPQuest.JournalTab:Initialize()
        RPQuest.DiscoveryTracker:Initialize()
        RPQuest.CombatTracker:Initialize()
        RPQuest.DialogueInjector:Initialize()

        -- Create quest with targetLocation, discovery point, and NPC dialogue
        local zId = mockState.zoneId
        local code = RPQuest.ShareCodec:EncodeQuest({
            title = "Misión 1-a-1",
            description = "Objetivo individual.",
            mapId = mockState.mapId,
            zoneId = zId,
            mapName = "Auridon",
            targets = {
                { name = "Bandido", requiredCount = 1, worldZoneId = zId, worldX = 5000, worldZ = 5000, radius = 1000, locationRequired = true },
            },
            discoveries = {
                { name = "Ruinas", zoneId = zId, worldX = 20000, worldZ = 20000, radius = 1000 },
            },
            dialogues = {
                { npcName = "Informante", zoneId = zId, clue = "¿Qué sabes del bandido?", response = "Está al sur." },
            },
        })

        -- Verify group sharing APIs/UI are removed
        AssertEqual(RPQuest.JournalTab.shareWithGroupDescriptor, nil, "Group share keybind descriptor removed")
        AssertEqual(RPQuest.MailTransport.ShareQuestWithGroup, nil, "MailTransport:ShareQuestWithGroup removed")
        AssertEqual(RPQuest.MailTransport.GetGroupMemberDisplayNames, nil, "MailTransport:GetGroupMemberDisplayNames removed")

        -- Simulate grouped player receiving and accepting quest via mail without /reloadui
        local isGrouped = true
        _G.IsUnitGrouped = function() return isGrouped end
        _G.GetGroupSize = function() return 2 end
        _G.GetGroupUnitTagByIndex = function(i)
            local tags = { "player", "group1" }
            return tags[i]
        end
        _G.AreUnitsEqual = function(a, b) return a == b end

        -- Group DiscoveryTracker & CombatTracker ignore group1
        local saved = RPQuest.QuestRepository:ImportQuestFromCode(code, "@Creator")
        RPQuest.QuestRepository:SetActiveQuest(saved.id)
        RPQuest.JournalTab:SelectQuest(saved.id)

        _G.GetUnitWorldPosition = function(tag)
            if tag == "player" then return zId, 0, 0, 0 end
            if tag == "group1" then return zId, 20000, 0, 20000 end
            return zId, 0, 0, 0
        end
        RPQuest.DiscoveryTracker:UpdatePollingState()
        RPQuest.DiscoveryTracker:OnUpdateTick()
        AssertEqual(saved.discoveries[1].discovered, false, "Discovery NOT triggered by group1 position")

        _G.GetUnitWorldPosition = function(tag)
            if tag == "player" then return zId, 0, 0, 0 end
            if tag == "group1" then return zId, 5000, 0, 5000 end
            return zId, 0, 0, 0
        end
        _G.GetMapPlayerPosition = function() return 0.5, 0.5 end
        RPQuest.CombatTracker:OnCombatEvent(nil, _G.ACTION_RESULT_DIED, false, "", 0, 0, "Ally1", _G.COMBAT_UNIT_TYPE_GROUP, "Bandido", 0, 0, 0, 0, false, 1, 777, 0)
        AssertEqual(saved.targets[1].currentCount, 0, "Group kill NOT recorded in 1-to-1 mode")

        -- DialogueInjector injects option immediately after mail quest import even while grouped
        local origUnitName = _G.GetUnitName
        _G.GetTimeStamp = function()
        return os.time()
    end

    GetUnitName = function(tag)
            if tag == "interact" then return "Informante" end
            return origUnitName(tag)
        end
        local injectedOptions = {}
        local fakeInteraction = {
            optionControls = {},
            PopulateChatterOption = function(selfObj, controlID, optionIndex, optionText, optionType)
                table.insert(injectedOptions, { controlID = controlID, text = optionText, optionType = optionType })
            end,
            PopulateChatterOptions = function(selfObj, optionCount)
                selfObj:PopulateChatterOption(1, function() end, "Adiós", _G.CHATTER_GOODBYE)
                selfObj:FinalizeChatterOptions(optionCount)
                return optionCount
            end,
            FinalizeChatterOptions = function(selfObj, optionCount)
                return optionCount
            end,
        }
        _G.ZO_Interaction = fakeInteraction
        RPQuest.DialogueInjector:InstallHooks()
        fakeInteraction:PopulateChatterOptions(0)
        AssertEqual(#injectedOptions, 2, "DialogueInjector injects clue + goodbye immediately without /reloadui")
        AssertEqual(injectedOptions[1].text, "¿Qué sabes del bandido?", "Injected option has expected clue text")
        _G.GetUnitName = origUnitName
    end)

end
