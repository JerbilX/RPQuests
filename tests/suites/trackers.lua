-- ============================================================================
-- RPQuest Test Suite: Trackers, TargetCapture & WorldMapArea Suites
-- ============================================================================
return function(T)
    local RunTest = T.RunTest
    local AssertEqual = T.AssertEqual
    local AssertTrue = T.AssertTrue
    local mockState = T.mockState
    local mockPinManager = T.mockPinManager

    RunTest("TargetCapture validates reticle unit and captures map coordinates into draft", function()
        mockState.language = "es"
        RPQuest.Locale:Initialize("es")
        RPQuest.QuestRepository:Initialize({})

        -- Sin objetivo bajo retícula
        mockState.reticleExists = false
        local d1, _ = RPQuest.TargetCapture:CaptureFromReticle()
        AssertEqual(d1, nil, "Must reject empty reticle")

        -- Objetivo es otro jugador
        mockState.reticleExists = true
        mockState.reticleIsPlayer = true
        local d2, _ = RPQuest.TargetCapture:CaptureFromReticle()
        AssertEqual(d2, nil, "Must reject player unit")

        -- Objetivo ya muerto
        mockState.reticleIsPlayer = false
        mockState.reticleIsDead = true
        local d3, _ = RPQuest.TargetCapture:CaptureFromReticle()
        AssertEqual(d3, nil, "Must reject dead unit")

        -- Objetivo NPC válido
        mockState.reticleIsDead = false
        mockState.reticleName = "Jefe Bandido^m"
        mockState.mapId = 45
        mockState.zoneId = 104
        mockState.mapName = "Deshaan"
        mockState.playerX = 0.3300
        mockState.playerY = 0.7700

        local draft = RPQuest.TargetCapture:CaptureFromReticle()
        AssertTrue(draft ~= nil, "Valid NPC must be captured into draft")
        AssertEqual(draft.targets[1].name, "Jefe Bandido", "Captured target name normalized")
        AssertEqual(draft.mapId, 45, "Captured mapId matches")
        AssertEqual(draft.mapName, "Deshaan", "Captured mapName matches")
        AssertEqual(draft.targetX, 0.3300, "Captured targetX matches")
        AssertEqual(draft.targetY, 0.7700, "Captured targetY matches")
        AssertTrue(draft.areaCenterX ~= nil and draft.areaCenterY ~= nil, "Offset area center generated")
    end)

    RunTest("CombatTracker + WorldMapArea integration: area pin shown when active, hidden when completed", function()
        mockState.language = "es"
        RPQuest.Locale:Initialize("es")
        RPQuest.QuestRepository:Initialize({})
        RPQuest.CombatTracker:Initialize()
        RPQuest.WorldMapArea:Initialize()
        mockState.csaMessages = {}

        mockState.reticleExists = true
        mockState.reticleIsPlayer = false
        mockState.reticleIsDead = false
        mockState.reticleName = "Cultista de Gusano"
        mockState.mapId = 45
        mockState.zoneId = 104
        mockState.mapName = "Deshaan"
        mockState.playerX = 0.50
        mockState.playerY = 0.50

        RPQuest.TargetCapture:CaptureFromReticle()
        RPQuest.TargetCapture:CaptureFromReticle()
        local q = RPQuest.QuestRepository:SaveDraft("Amenaza del Culto", "Elimina a 2 cultistas.", 0.08)
        AssertTrue(q ~= nil, "Quest created")
        RPQuest.QuestRepository:SetActiveQuest(q.id)

        -- Verificar que una muerte de otro NPC no consulte el mapa innecesariamente
        local mapCalls = 0
        local origSetMap = SetMapToPlayerLocation
        SetMapToPlayerLocation = function()
            mapCalls = mapCalls + 1
            return origSetMap()
        end
        EVENT_MANAGER:FireEvent(
            EVENT_COMBAT_EVENT,
            ACTION_RESULT_DIED, false, "Ataque", 0, 0,
            "Jugador", 1, "Araña del Bosque", 2,
            500, 0, 0, false, 1, 2, 100
        )
        AssertEqual(mapCalls, 0, "Unrelated NPC death must not invoke SetMapToPlayerLocation")
        SetMapToPlayerLocation = origSetMap

        -- En el mismo mapa (mapId 45) debe dibujarse 1 pin de área grande cuando showSearchAreas = true
        RPQuest.QuestRepository:SetSetting("showSearchAreas", true)
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 1, "Search area pin must be rendered on quest mapId")
        AssertEqual(mockPinManager._createdPins[1].radius, 0.08, "Pin uses quest area radius")

        -- En otro mapa (mapId 99) no debe dibujarse ningún pin
        mockState.mapId = 99
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 0, "No pin rendered on unrelated mapId")

        -- Volver al mapa 45 y disparar EVENT_COMBAT_EVENT (1ra muerte)
        mockState.mapId = 45
        EVENT_MANAGER:FireEvent(
            EVENT_COMBAT_EVENT,
            ACTION_RESULT_DIED, false, "Ataque", 0, 0,
            "Jugador", COMBAT_UNIT_TYPE_PLAYER, "Cultista de Gusano^m", COMBAT_UNIT_TYPE_OTHER,
            1500, 0, 0, false, 1, 2001, 100
        )
        AssertEqual(q.targets[1].currentCount, 1, "Kill count incremented to 1")
        AssertEqual(q.completed, false, "Not yet completed")
        AssertEqual(#mockState.csaMessages, 1, "1 CSA progress message emitted")

        -- Mismo targetUnitId con ACTION_RESULT_DIED_XP no debe duplicar
        EVENT_MANAGER:FireEvent(
            EVENT_COMBAT_EVENT,
            ACTION_RESULT_DIED_XP, false, "Ataque", 0, 0,
            "Jugador", COMBAT_UNIT_TYPE_PLAYER, "Cultista de Gusano", COMBAT_UNIT_TYPE_OTHER,
            1500, 0, 0, false, 1, 2001, 100
        )
        AssertEqual(q.targets[1].currentCount, 1, "Duplicate death event for same targetUnitId is ignored")

        -- Muerte causada por otro jugador ajeno (sin grupo) no cuenta
        mockState.isGrouped = false
        EVENT_MANAGER:FireEvent(
            EVENT_COMBAT_EVENT,
            ACTION_RESULT_DIED, false, "Ataque", 0, 0,
            "Desconocido", COMBAT_UNIT_TYPE_OTHER, "Cultista de Gusano", COMBAT_UNIT_TYPE_OTHER,
            1500, 0, 0, false, 99, 2002, 100
        )
        AssertEqual(q.targets[1].currentCount, 1, "Unrelated player kill does not count")

        -- Muerte de miembro de grupo cuando NO se está en grupo no cuenta
        EVENT_MANAGER:FireEvent(
            EVENT_COMBAT_EVENT,
            ACTION_RESULT_DIED, false, "Ataque", 0, 0,
            "Compañero", COMBAT_UNIT_TYPE_GROUP, "Cultista de Gusano", COMBAT_UNIT_TYPE_OTHER,
            1500, 0, 0, false, 98, 2003, 100
        )
        AssertEqual(q.targets[1].currentCount, 1, "Group unit kill ignored when solo")

        -- En grupo, muerte de miembro del grupo sigue siendo ignorada (flujo 1-a-1)
        mockState.isGrouped = true
        EVENT_MANAGER:FireEvent(
            EVENT_COMBAT_EVENT,
            ACTION_RESULT_DIED_XP, false, "Ataque", 0, 0,
            "Compañero", COMBAT_UNIT_TYPE_GROUP, "Cultista de Gusano", COMBAT_UNIT_TYPE_OTHER,
            1500, 0, 0, false, 98, 2004, 100
        )
        mockState.isGrouped = false
        AssertEqual(q.targets[1].currentCount, 1, "Group unit kill ignored even when grouped")

        -- Muerte del jugador completa la misión
        EVENT_MANAGER:FireEvent(
            EVENT_COMBAT_EVENT,
            ACTION_RESULT_DIED_XP, false, "Ataque", 0, 0,
            "Jugador", COMBAT_UNIT_TYPE_PLAYER, "Cultista de Gusano", COMBAT_UNIT_TYPE_OTHER,
            1500, 0, 0, false, 1, 2005, 100
        )
        AssertTrue(q.completed, "Quest completed on second kill")
        AssertEqual(#mockState.csaMessages, 2, "CSA completion message emitted")
        AssertEqual(mockState.csaMessages[2].sound, SOUNDS.QUEST_COMPLETED, "Played QUEST_COMPLETED sound")
        AssertEqual(#mockPinManager._createdPins, 0, "Search area pin automatically removed when quest completes")
    end)

    RunTest("17. ShowQuestOnMap cambia de zona con WORLD_MAP_MANAGER y abrir con M muestra pin activo", function()
        local sv = {}
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.WorldMapArea:Initialize()

        local mockPinManager = ZO_WorldMap_GetPinManager()
        mockPinManager._createdPins = {}

        -- Crear misión en Stonefalls (mapId = 27) y activarla
        mockState.reticleExists = true
        mockState.reticleName = "Cultista"
        mockState.reticleIsPlayer = false
        mockState.reticleIsDead = false
        mockState.reticleAttackable = true
        mockState.mapId = 27
        mockState.zoneId = 41
        mockState.mapName = "Stonefalls"
        mockState.playerX = 0.62
        mockState.playerY = 0.38

        RPQuest.TargetCapture:CaptureFromReticle()
        local stonefallsQuest = RPQuest.QuestRepository:SaveDraft("Misión en Stonefalls", "Desc", RPQuest.Constants.AREA_RADIUS.MEDIUM)
        RPQuest.QuestRepository:SetActiveQuest(stonefallsQuest.id)

        -- Jugador viaja a Deshaan (mapId = 45) y el mapa está cerrado
        SCENE_MANAGER:Hide("worldMap")
        mockState.mapId = 45
        mockState.zoneId = 104
        mockState.mapName = "Deshaan"
        mockPinManager._createdPins = {}
        mockState.lastPannedX = nil
        mockState.lastPannedY = nil

        local callOrder = {}
        local origSceneShow = SCENE_MANAGER.Show
        SCENE_MANAGER.Show = function(self, sceneName)
            table.insert(callOrder, "ShowScene:" .. tostring(sceneName))
            return origSceneShow(self, sceneName)
        end

        local origWorldMapManager = WORLD_MAP_MANAGER
        local setMapByIdCalledWith = nil
        WORLD_MAP_MANAGER = {
            SetMapById = function(self, mapId)
                table.insert(callOrder, "SetMapById")
                setMapByIdCalledWith = mapId
                SetMapToMapId(mapId)
            end,
        }

        -- 1. Show on Map desde Deshaan debe cambiar el mapa a Stonefalls ANTES de abrir la escena
        RPQuest.QuestRepository:SetSetting("showSearchAreas", true)
        local shown = RPQuest.WorldMapArea:ShowQuestOnMap(stonefallsQuest)
        AssertEqual(shown, true, "ShowQuestOnMap returns true")
        AssertEqual(setMapByIdCalledWith, 27, "WORLD_MAP_MANAGER:SetMapById called with Stonefalls mapId")
        AssertEqual(callOrder[1], "SetMapById", "SetMapById called before opening world map")
        AssertEqual(callOrder[2], "ShowScene:worldMap", "World map opened after SetMapById")
        AssertEqual(mockState.mapId, 27, "Current mapId switched to Stonefalls")
        AssertEqual(#mockPinManager._createdPins, 1, "Stonefalls quest pin rendered when viewing from Deshaan")
        AssertEqual(mockState.lastPannedX, stonefallsQuest.targets[1].areaCenterX, "Map panned to quest areaCenterX")
        AssertEqual(mockState.lastPannedY, stonefallsQuest.targets[1].areaCenterY, "Map panned to quest areaCenterY")

        -- Restaurar mocks globales
        SCENE_MANAGER.Show = origSceneShow
        WORLD_MAP_MANAGER = origWorldMapManager

        -- 2. Cerrar el mapa y abrirlo por fuera con M en Stonefalls debe mostrar la marca activa
        SCENE_MANAGER:Hide("worldMap")
        mockPinManager._createdPins = {}
        mockState.mapId = 27
        SCENE_MANAGER:Show("worldMap")
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 1, "Opening map with M renders active quest pin")
    end)

    RunTest("Undetected (stealth) quest option, Justice events, area check, and completion code", function()
        RPQuest.QuestRepository:ResetDraft()
        mockState.mapId = 32
        mockState.zoneId = 381
        mockState.mapName = "Auridon"
        mockState.playerX = 0.42
        mockState.playerY = 0.61

        -- 1. Toggle in editor + SaveDraft
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Guardia de Sombra",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.42,
            targetY = 0.61,
        })
        RPQuest.QuestRepository:UpdateDraftFields({ stealthMode = "optional" })
        RPQuest.JournalTab:RefreshEditorPane()
        local selectedItem = RPQuest.JournalTab.stealthComboBox:GetSelectedItemData()
        AssertEqual(selectedItem and selectedItem.stealthMode, "optional", "Editor dropdown selects optional when stealthMode is optional")

        local prepared = RPQuest.QuestRepository:SaveDraft("Contrato de Sigilo", "Sin testigos.", nil, "Trabajo limpio.")
        AssertTrue(prepared ~= nil, "Saved stealth quest")
        AssertEqual(prepared.stealthMode, "optional", "Prepared quest has stealthMode = optional")
        AssertEqual(prepared.wasDetected, false, "Prepared quest starts with wasDetected = false")

        -- 2. ShareCodec preserves stealthMode = optional
        local shareCode = RPQuest.QuestRepository:ExportQuestToCode(prepared.id)
        local imported = RPQuest.QuestRepository:ImportQuestFromCode(shareCode)
        AssertTrue(imported ~= nil, "Imported stealth quest")
        AssertEqual(imported.stealthMode, "optional", "Imported quest preserves stealthMode = optional")
        AssertEqual(imported.wasDetected, false, "Imported quest starts with wasDetected = false")
        AssertEqual(RPQuest.CombatTracker._isJusticeRegistered, true, "Justice events registered for active undetected quest")

        -- 3. Justice events outside quest area do NOT trigger detection
        mockState.mapId = 999
        mockState.zoneId = 999
        RPQuest.CombatTracker:OnJusticeBountyUpdated(EVENT_JUSTICE_BOUNTY_PAYOFF_AMOUNT_UPDATED, 0, 150, false)
        AssertEqual(imported.wasDetected, false, "Bounty outside quest area does not mark detected")

        -- 4. Initialization / non-increasing bounty inside area do NOT trigger detection
        mockState.mapId = 32
        mockState.zoneId = 381
        mockState.playerX = imported.targets[1].areaCenterX
        mockState.playerY = imported.targets[1].areaCenterY
        RPQuest.CombatTracker:OnJusticeBountyUpdated(EVENT_JUSTICE_BOUNTY_PAYOFF_AMOUNT_UPDATED, 0, 150, true)
        AssertEqual(imported.wasDetected, false, "isInitialize bounty event does not mark detected")
        RPQuest.CombatTracker:OnJusticeInfamyUpdated(EVENT_JUSTICE_INFAMY_UPDATED, 100, 100, 1, 1)
        AssertEqual(imported.wasDetected, false, "Non-increasing infamy does not mark detected")

        -- 5. Justice bounty increase inside quest area marks wasDetected = true without blocking quest
        mockState.alerts = {}
        RPQuest.CombatTracker:OnJusticeBountyUpdated(EVENT_JUSTICE_BOUNTY_PAYOFF_AMOUNT_UPDATED, 0, 200, false)
        AssertEqual(imported.wasDetected, true, "Bounty increase inside quest area marks wasDetected = true")
        AssertEqual(imported.completed, false, "Detection does not fail or complete the quest")
        AssertEqual(#mockState.alerts, 1, "Player receives informative alert on detection")
        AssertEqual(RPQuest.CombatTracker._isJusticeRegistered, false, "Justice events unregistered once detected")

        -- 6. Quest can still be completed and completion code includes wasDetected = true
        local recorded, _, justCompleted = RPQuest.QuestRepository:RecordTargetEliminated("Guardia de Sombra", {
            mapId = 32,
            zoneId = 381,
            x = imported.areaCenterX,
            y = imported.areaCenterY,
        })
        AssertEqual(recorded, true, "Target elimination still succeeds after detection")
        AssertEqual(justCompleted, true, "Quest still completes normally after detection")

        local compCodeDetected = RPQuest.QuestRepository:ExportCompletionCode(imported.id)
        local okDet, decodedDet = RPQuest.QuestRepository:ValidateResultCode(prepared.id, compCodeDetected)
        AssertEqual(okDet, true, "Completion code with detection is still valid")
        AssertEqual(decodedDet.wasDetected, true, "Completion code records wasDetected = true")

        -- 7. ResetQuest clears wasDetected and completing cleanly records wasDetected = false
        RPQuest.QuestRepository:ResetQuest(imported.id)
        AssertEqual(imported.wasDetected, false, "ResetQuest clears wasDetected")
        AssertEqual(RPQuest.CombatTracker._isJusticeRegistered, true, "Justice events re-registered after ResetQuest")

        RPQuest.QuestRepository:RecordTargetEliminated("Guardia de Sombra", {
            mapId = 32,
            zoneId = 381,
            x = imported.areaCenterX,
            y = imported.areaCenterY,
        })
        local compCodeClean = RPQuest.QuestRepository:ExportCompletionCode(imported.id)
        local okClean, decodedClean = RPQuest.QuestRepository:ValidateResultCode(prepared.id, compCodeClean)
        AssertEqual(okClean, true, "Completion code without detection is valid")
        AssertEqual(decodedClean.wasDetected, false, "Completion code records wasDetected = false")

        -- 8. Pickpocket failed & Infamy increase also trigger detection
        RPQuest.QuestRepository:ResetQuest(imported.id)
        RPQuest.CombatTracker:OnJusticePickpocketFailed(EVENT_JUSTICE_PICKPOCKET_FAILED)
        AssertEqual(imported.wasDetected, true, "Pickpocket failed inside quest area marks wasDetected = true")

        RPQuest.QuestRepository:ResetQuest(imported.id)
        RPQuest.CombatTracker:OnJusticeInfamyUpdated(EVENT_JUSTICE_INFAMY_UPDATED, 0, 50, 0, 1)
        AssertEqual(imported.wasDetected, true, "Infamy increase inside quest area marks wasDetected = true")
    end)

    RunTest("23b. Stealth mode 'required': detection immediately fails active quest and announces failure", function()
        RPQuest.QuestRepository:Initialize(nil)
        RPQuest.CombatTracker:Initialize()
        RPQuest.JournalTab:Initialize()
        mockState.mapId = 32
        mockState.zoneId = 381
        mockState.playerX = 0.42
        mockState.playerY = 0.61
        mockState.csaMessages = {}
        mockState.chatMessages = {}

        local failedEvents = 0
        RPQuest.QuestRepository:RegisterListener(function(ev)
            if ev == "QUEST_FAILED" then failedEvents = failedEvents + 1 end
        end)

        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Centinela Real",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.42,
            targetY = 0.61,
        })
        RPQuest.QuestRepository:UpdateDraftFields({ stealthMode = "required" })
        local prepared = RPQuest.QuestRepository:SaveDraft("Infiltración Estricta", "Prohibido ser visto.")
        local shareCode = RPQuest.QuestRepository:ExportQuestToCode(prepared.id)
        local imported = RPQuest.QuestRepository:ImportQuestFromCode(shareCode)
        AssertEqual(imported.stealthMode, "required", "Imported quest preserves stealthMode = required")
        AssertEqual(RPQuest.CombatTracker._isJusticeRegistered, true, "Justice events registered for required stealth quest")

        mockState.playerX = imported.targets[1].areaCenterX
        mockState.playerY = imported.targets[1].areaCenterY
        RPQuest.CombatTracker:OnJusticePickpocketFailed(EVENT_JUSTICE_PICKPOCKET_FAILED)

        AssertEqual(imported.wasDetected, true, "Detection marks wasDetected = true")
        AssertEqual(imported.failed, true, "Required stealth marks quest failed = true on detection")
        AssertEqual(RPQuest.QuestRepository:GetActiveQuest(), nil, "Active quest cleared on stealth failure")
        AssertEqual(failedEvents, 1, "QUEST_FAILED event emitted")
        AssertEqual(RPQuest.CombatTracker._isJusticeRegistered, false, "Justice events unregistered after failure")
        AssertTrue(#mockState.csaMessages >= 1, "Failure announcement emitted via CSA")
    end)

    RunTest("Hidden discovery points: capture, ShareCodec, proximity trigger, no map pins, mixed quest", function()
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:SetActiveQuest(nil)
        RPQuest.DiscoveryTracker:UpdatePollingState()
        mockState.zoneId = 381
        mockState.mapId = 32
        mockState.worldX = 10000
        mockState.worldY = 500
        mockState.worldZ = 20000

        -- 1. Capture 2 discovery points in-situ without combat targets
        local draft1, cnt1 = RPQuest.TargetCapture:CaptureDiscoveryPoint("Notas un olor particular que viene del norte", 1000)
        AssertTrue(draft1 ~= nil, "First discovery point captured")
        AssertEqual(cnt1, 1, "Draft has 1 discovery point")

        mockState.worldX = 15000
        mockState.worldZ = 25000
        local draft2, cnt2 = RPQuest.TargetCapture:CaptureDiscoveryPoint("Escuchas un ruido de ovejas que viene del noreste", 1500)
        AssertTrue(draft2 ~= nil, "Second discovery point captured")
        AssertEqual(cnt2, 2, "Draft has 2 discovery points")

        -- 1b. Edit and remove individual discovery points in draft
        local editedPt = RPQuest.QuestRepository:UpdateDraftDiscoveryPoint(1, {
            message = "Notas un olor particular que viene del norte",
            radius = 800,
        })
        AssertTrue(editedPt ~= nil, "Discovery point #1 updated in draft")
        AssertEqual(draft2.discoveries[1].radius, 800, "Discovery point #1 radius updated")
        RPQuest.TargetCapture:CaptureDiscoveryPoint("Punto temporal", 800)
        AssertEqual(#draft2.discoveries, 3, "Temporary discovery point #3 added")
        RPQuest.QuestRepository:RemoveDraftDiscoveryPoint(3)
        AssertEqual(#draft2.discoveries, 2, "Temporary discovery point #3 removed individually")
        RPQuest.QuestRepository:UpdateDraftDiscoveryPoint(1, { radius = 1000 })

        -- 2. Save discovery-only quest (0 combat targets)
        local saved = RPQuest.QuestRepository:SaveDraft("Rastreo en Auridon", "Sigue las pistas")
        AssertTrue(saved ~= nil, "Discovery-only quest saved successfully")
        AssertEqual(#saved.targets, 0, "Discovery-only quest has 0 combat targets")
        AssertEqual(#saved.discoveries, 2, "Discovery-only quest has 2 discovery points")
        AssertEqual(RPQuest.DiscoveryTracker._isPolling, false, "Polling inactive when prepared quest is not active")

        -- 3. ShareCodec roundtrip preserves discoveries and resets discovered=false
        local code = RPQuest.QuestRepository:ExportQuestToCode(saved.id)
        AssertTrue(type(code) == "string" and code:sub(1, 5) == "RPQ3:", "ShareCodec encodes discovery-only quest")

        local imported = RPQuest.QuestRepository:ImportQuestFromCode(code)
        AssertTrue(imported ~= nil, "ShareCodec decodes and imports discovery-only quest")
        AssertEqual(#imported.discoveries, 2, "Imported quest preserves 2 discovery points")
        AssertEqual(imported.discoveries[1].message, "Notas un olor particular que viene del norte", "Discovery #1 message preserved")
        AssertEqual(imported.discoveries[2].radius, 1500, "Discovery #2 radius preserved")
        AssertEqual(imported.discoveries[1].discovered, false, "Imported discovery #1 starts undiscovered")

        -- 4. No map pins are rendered for discovery-only quests
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 0, "No map pins created for hidden discovery points")

        -- 5. Polling activates when imported quest is active
        AssertEqual(RPQuest.DiscoveryTracker._isPolling, true, "Polling active when active quest has pending discoveries")

        -- 6. Wrong zone or outside radius does NOT trigger
        local triggeredWrongZone = RPQuest.DiscoveryTracker:EvaluatePlayerPosition(999, 10000, 500, 20000)
        AssertEqual(triggeredWrongZone, false, "Wrong zoneId does not trigger discovery")

        local triggeredFar = RPQuest.DiscoveryTracker:EvaluatePlayerPosition(381, 12000, 500, 20000)
        AssertEqual(triggeredFar, false, "Outside radius (2000 > 1000) does not trigger discovery")

        -- 7. Entering radius of point #1 triggers it once (CSA + Chat)
        mockState.csaMessages = {}
        mockState.chatMessages = {}
        local triggered1 = RPQuest.DiscoveryTracker:EvaluatePlayerPosition(381, 10500, 500, 20500)
        AssertEqual(triggered1, true, "Inside radius triggers discovery #1")
        AssertEqual(imported.discoveries[1].discovered, true, "Discovery #1 marked discovered = true")
        AssertEqual(imported.completed, false, "Quest not completed until discovery #2 is also found")
        AssertEqual(#mockState.csaMessages, 1, "CSA shown for discovery #1")
        AssertEqual(#mockState.chatMessages, 1, "Chat message shown for discovery #1")

        -- Re-evaluating at same position does NOT re-trigger
        local triggeredRepeat = RPQuest.DiscoveryTracker:EvaluatePlayerPosition(381, 10500, 500, 20500)
        AssertEqual(triggeredRepeat, false, "Already discovered point does not re-trigger")
        AssertEqual(#mockState.csaMessages, 1, "No duplicate CSA on repeat tick")

        -- 8. Entering radius of point #2 completes the quest and stops polling
        local triggered2 = RPQuest.DiscoveryTracker:EvaluatePlayerPosition(381, 15000, 500, 25000)
        AssertEqual(triggered2, true, "Inside radius triggers discovery #2")
        AssertEqual(imported.completed, true, "Quest completed after all discoveries found")
        AssertEqual(RPQuest.DiscoveryTracker._isPolling, false, "Polling stops automatically once quest is completed")

        -- 9. ResetQuest resets discoveries and re-enables polling
        RPQuest.QuestRepository:ResetQuest(imported.id)
        AssertEqual(imported.discoveries[1].discovered, false, "ResetQuest resets discovery #1")
        AssertEqual(imported.discoveries[2].discovered, false, "ResetQuest resets discovery #2")
        AssertEqual(RPQuest.DiscoveryTracker._isPolling, true, "Polling re-enabled after ResetQuest")

        -- 10. Mixed quest (combat target + discovery point) requires BOTH
        RPQuest.QuestRepository:ResetDraft()
        mockState.reticleExists = true
        mockState.reticleName = "Bandido"
        mockState.worldX = 20000
        mockState.worldZ = 30000
        RPQuest.TargetCapture:CaptureFromReticle()
        RPQuest.TargetCapture:CaptureDiscoveryPoint("Encuentras el campamento oculto", 1200)
        local mixedPrepared = RPQuest.QuestRepository:SaveDraft("Misión Mixta", "Investiga y elimina")
        local mixedCode = RPQuest.QuestRepository:ExportQuestToCode(mixedPrepared.id)
        local mixed = RPQuest.QuestRepository:ImportQuestFromCode(mixedCode)
        AssertTrue(mixed ~= nil, "Mixed quest imported")

        local killOk, _, killCompleted = RPQuest.QuestRepository:RecordTargetEliminated("Bandido", {
            mapId = 32,
            zoneId = 381,
            x = mixed.areaCenterX,
            y = mixed.areaCenterY,
        })
        AssertEqual(killOk, true, "Mixed quest target eliminated")
        AssertEqual(killCompleted, false, "Mixed quest not completed until discovery point is also reached")

        local discOk = RPQuest.DiscoveryTracker:EvaluatePlayerPosition(381, 20000, 500, 30000)
        AssertEqual(discOk, true, "Mixed quest discovery triggered")
        AssertEqual(mixed.completed, true, "Mixed quest completed once both target and discovery are done")
    end)

    RunTest("Target location conditions and custom messages (Issue #99)", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.CombatTracker:Initialize()

        -- Helper to spy on Announcements
        local customMsgCalls = {}
        local failedCalls = {}
        local origCustom = RPQuest.Announcements.AnnounceTargetCustomMessage
        local origFailed = RPQuest.Announcements.AnnounceQuestFailed
        RPQuest.Announcements.AnnounceTargetCustomMessage = function(self, quest, target, overrideText)
            table.insert(customMsgCalls, overrideText or target.customMessage)
            origCustom(self, quest, target, overrideText)
        end
        RPQuest.Announcements.AnnounceQuestFailed = function(self, quest, target, reasonText)
            table.insert(failedCalls, { id = quest.id, reasonText = reasonText })
            origFailed(self, quest, target, reasonText)
        end

        local origGetMapId = _G.GetCurrentMapId
        local origGetMapPos = _G.GetMapPlayerPosition
        local origGetWorldPos = _G.GetUnitWorldPosition
        _G.GetCurrentMapId = function() return 32 end
        _G.GetMapPlayerPosition = function() return 0.5, 0.5 end

        -- Case 1 & 2: Required location
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Guard",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.5,
            targetY = 0.5,
        })
        RPQuest.QuestRepository:CaptureDraftTargetLocation(1, 381, 10000, 20000, 1000)
        RPQuest.QuestRepository:UpdateDraftTarget(1, {
            locationRequired = true,
            customMessage = "Should NOT fire when locationRequired is true.",
            customMessageInLocation = "Silent takedown in the alley.",
            customMessageOutsideLocation = "You alerted the district!",
        })
        local qReq = RPQuest.QuestRepository:SaveDraft("Required Loc Quest", "Desc")
        RPQuest.QuestRepository:SetActiveQuest(qReq.id)

        -- Kill outside required location -> fails quest, kill does NOT count, shows customMessageOutsideLocation
        _G.GetUnitWorldPosition = function() return 381, 50000, 0, 50000 end
        RPQuest.CombatTracker:OnCombatEvent(0, ACTION_RESULT_DIED, false, "", 0, 0, "Player", COMBAT_UNIT_TYPE_PLAYER, "Guard", 0, 1, 0, 0, false, 1, 901, 0)
        AssertEqual(qReq.failed, true, "Quest fails when required location target is killed outside radius")
        AssertEqual(qReq.targets[1].currentCount, 0, "Kill outside required location does not count")
        AssertEqual(#failedCalls, 1, "AnnounceQuestFailed called once")
        AssertEqual(failedCalls[1].reasonText, "You alerted the district!", "Failure uses customMessageOutsideLocation")
        AssertEqual(RPQuest.QuestRepository:GetActiveQuest(), nil, "Failed quest is deactivated")

        -- Reset quest and kill inside required location -> counts kill + shows customMessageInLocation (NOT customMessage)
        RPQuest.QuestRepository:ResetQuest(qReq.id)
        AssertEqual(qReq.failed, false, "ResetQuest clears failed flag")
        _G.GetUnitWorldPosition = function() return 381, 10200, 0, 20200 end
        RPQuest.CombatTracker:OnCombatEvent(0, ACTION_RESULT_DIED, false, "", 0, 0, "Player", COMBAT_UNIT_TYPE_PLAYER, "Guard", 0, 1, 0, 0, false, 1, 902, 0)
        AssertEqual(qReq.targets[1].currentCount, 1, "Kill inside required location counts")
        AssertEqual(qReq.completed, true, "Quest completes on kill inside required location")
        AssertEqual(#customMsgCalls, 1, "Custom message shown inside required location")
        AssertEqual(customMsgCalls[1], "Silent takedown in the alley.", "Exact customMessageInLocation emitted")

        -- Case 3: Optional location + defined point -> kills count anywhere in Tamriel and fire customMessage
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Scout",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.5,
            targetY = 0.5,
        })
        RPQuest.QuestRepository:CaptureDraftTargetLocation(1, 381, 10000, 20000, 1000)
        RPQuest.QuestRepository:UpdateDraftTarget(1, {
            locationRequired = false,
            customMessage = "Scout ambushed!",
            customMessageInLocation = "Should NOT fire when locationRequired is false.",
            customMessageOutsideLocation = "Should NOT fire when locationRequired is false.",
        })
        RPQuest.QuestRepository:GetDraft().targets[1].requiredCount = 2
        local qOpt = RPQuest.QuestRepository:SaveDraft("Optional Loc Quest", "Desc")
        RPQuest.QuestRepository:SetActiveQuest(qOpt.id)

        -- Kill outside defined point -> counts kill anywhere in Tamriel and shows customMessage
        _G.GetUnitWorldPosition = function() return 999, 50000, 0, 50000 end
        RPQuest.CombatTracker:OnCombatEvent(0, ACTION_RESULT_DIED, false, "", 0, 0, "Player", COMBAT_UNIT_TYPE_PLAYER, "Scout", 0, 1, 0, 0, false, 1, 903, 0)
        AssertEqual(qOpt.failed, false, "Optional location does not fail quest outside radius")
        AssertEqual(qOpt.targets[1].currentCount, 1, "Kill outside optional location still counts")
        AssertEqual(#customMsgCalls, 2, "customMessage shown on kill when locationRequired is false")
        AssertEqual(customMsgCalls[2], "Scout ambushed!", "Uses customMessage (not location messages)")

        -- Kill inside defined point -> counts kill + shows customMessage
        _G.GetUnitWorldPosition = function() return 381, 10100, 0, 20100 end
        RPQuest.CombatTracker:OnCombatEvent(0, ACTION_RESULT_DIED, false, "", 0, 0, "Player", COMBAT_UNIT_TYPE_PLAYER, "Scout", 0, 1, 0, 0, false, 1, 904, 0)
        AssertEqual(qOpt.targets[1].currentCount, 2, "Second kill inside optional location counts")
        AssertEqual(#customMsgCalls, 3, "customMessage shown inside optional location")

        -- Case 4: Optional location + NO defined point
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Bandit",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.5,
            targetY = 0.5,
        })
        RPQuest.QuestRepository:UpdateDraftTarget(1, {
            locationRequired = false,
            customMessage = "Bandit eliminated anywhere.",
        })
        local qNoLoc = RPQuest.QuestRepository:SaveDraft("No Loc Custom Msg", "Desc")
        RPQuest.QuestRepository:SetActiveQuest(qNoLoc.id)
        RPQuest.CombatTracker:OnCombatEvent(0, ACTION_RESULT_DIED, false, "", 0, 0, "Player", COMBAT_UNIT_TYPE_PLAYER, "Bandit", 0, 1, 0, 0, false, 1, 905, 0)
        AssertEqual(qNoLoc.targets[1].currentCount, 1, "Target without location counts anywhere")
        AssertEqual(#customMsgCalls, 4, "Custom message shown anywhere when no location defined")

        -- ShareCodec roundtrip for target conditions & 3-state custom messages
        local exported = RPQuest.QuestRepository:ExportQuestToCode(qReq.id)
        local decoded = RPQuest.ShareCodec:DecodeQuest(exported)
        AssertTrue(decoded ~= nil and decoded.targets ~= nil and #decoded.targets == 1, "Encoded quest with target condition decoded")
        AssertEqual(decoded.targets[1].zoneId, 381, "Target zoneId preserved in ShareCodec")
        AssertEqual(decoded.targets[1].worldX, 10000, "Target worldX preserved in ShareCodec")
        AssertEqual(decoded.targets[1].worldZ, 20000, "Target worldZ preserved in ShareCodec")
        AssertEqual(decoded.targets[1].radius, 1000, "Target radius preserved in ShareCodec")
        AssertEqual(decoded.targets[1].locationRequired, true, "Target locationRequired preserved in ShareCodec")
        AssertEqual(decoded.targets[1].customMessage, "", "Inactive customMessage pruned when locationRequired is true")
        AssertEqual(decoded.targets[1].customMessageInLocation, "Silent takedown in the alley.", "Target customMessageInLocation preserved in ShareCodec")
        AssertEqual(decoded.targets[1].customMessageOutsideLocation, "You alerted the district!", "Target customMessageOutsideLocation preserved in ShareCodec")

        RPQuest.Announcements.AnnounceTargetCustomMessage = origCustom
        RPQuest.Announcements.AnnounceQuestFailed = origFailed
        _G.GetCurrentMapId = origGetMapId
        _G.GetMapPlayerPosition = origGetMapPos
        _G.GetUnitWorldPosition = origGetWorldPos
    end)

    RunTest("WorldMapArea: zoom-out reference marker on parent/world maps, hidden on target map and when untracked", function()
        RPQuest.QuestRepository:Initialize({})
        RPQuest.WorldMapArea:Initialize()

        mockState.reticleExists = true
        mockState.reticleIsPlayer = false
        mockState.reticleIsDead = false
        mockState.reticleName = "Mercenario"
        mockState.mapId = 45
        mockState.mapType = MAPTYPE_SUBZONE
        mockState.zoneId = 104
        mockState.mapName = "Mournhold"
        mockState.playerX = 0.42
        mockState.playerY = 0.61
        mockState.worldX = 25000
        mockState.worldY = 100
        mockState.worldZ = 35000
        mockState.projectedPositions = {
            [44] = { x = 0.55, y = 0.48 },   -- Parent zone (Deshaan)
            [27] = { x = 0.78, y = 0.36 },   -- World map (Tamriel)
            [99] = { x = 1.25, y = -0.10 },  -- Out of bounds unrelated map
        }

        local draft = RPQuest.TargetCapture:CaptureFromReticle()
        AssertTrue(draft ~= nil, "Draft captured")
        AssertEqual(draft.worldX, 25000, "Draft captures worldX")
        AssertEqual(draft.worldZ, 35000, "Draft captures worldZ")

        local quest = RPQuest.QuestRepository:SaveDraft("Rastreo en Mournhold", "Busca al mercenario.", 0.10)
        AssertTrue(quest ~= nil, "Quest saved")
        AssertEqual(quest.worldX, 25000, "Saved quest persists worldX")
        AssertEqual(quest.worldZ, 35000, "Saved quest persists worldZ")

        RPQuest.QuestRepository:SetSetting("showSearchAreas", true)
        RPQuest.QuestRepository:SetActiveQuest(quest.id)

        -- 1. On target map (mapId 45): only search area pin, NO zoom-out pin
        mockState.mapId = 45
        mockState.mapType = MAPTYPE_SUBZONE
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 1, "Only 1 pin rendered on target mapId")
        AssertEqual(mockPinManager._createdPins[1].pinTypeId, RPQuest.WorldMapArea.pinTypeId, "Target map renders search area pin only")

        -- 2. Zoom out to parent zone (mapId 44, MAPTYPE_ZONE): zoom-out pin with projected coords + pulse animation
        mockState.mapId = 44
        mockState.mapType = MAPTYPE_ZONE
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 1, "Zoom-out reference pin rendered on parent zone map")
        local zonePin = mockPinManager._createdPins[1]
        AssertEqual(zonePin.pinTypeId, RPQuest.WorldMapArea.zoomOutPinTypeId, "Parent zone renders zoom-out pin type")
        local zDx = zonePin.x - 0.55
        local zDy = zonePin.y - 0.48
        local zDist = math.sqrt((zDx * zDx) + (zDy * zDy))
        AssertTrue(zDist > 0.001, "Parent zone zoom-out center is offset from exact projection")
        AssertTrue(zDist <= zonePin.radius, "Parent zone projected point remains inside zoom-out radius")
        AssertEqual(zonePin.radius, RPQuest.Constants.AREA_RADIUS.MEDIUM, "Zoom-out pin uses medium area radius")
        AssertTrue(#(RPQuest.WorldMapArea._activePulseAnimations or {}) == 1, "Zoom-out pin triggers pulse animation")

        -- 3. Zoom out to world map (mapId 27, MAPTYPE_WORLD): zoom-out pin still renders
        mockState.mapId = 27
        mockState.mapType = MAPTYPE_WORLD
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 1, "Zoom-out reference pin rendered on world map")
        local worldPin = mockPinManager._createdPins[1]
        AssertEqual(worldPin.pinTypeId, RPQuest.WorldMapArea.zoomOutPinTypeId, "World map renders zoom-out pin")
        local wDx = worldPin.x - 0.78
        local wDy = worldPin.y - 0.36
        local wDist = math.sqrt((wDx * wDx) + (wDy * wDy))
        AssertTrue(wDist > 0.001, "World map zoom-out center is offset from exact projection")
        AssertTrue(wDist <= worldPin.radius, "World map projected point remains inside zoom-out radius")

        -- 4. Cosmic map (MAPTYPE_COSMIC): no zoom-out pin
        mockState.mapType = MAPTYPE_COSMIC
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 0, "No zoom-out pin on cosmic map")

        -- 5. Unrelated map with out-of-bounds projection: no zoom-out pin
        mockState.mapId = 99
        mockState.mapType = MAPTYPE_ZONE
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 0, "No zoom-out pin when projected coordinates are out of bounds")

        -- 6. Zoom back in to target map (mapId 45): zoom-out pin disappears, search area pin returns
        mockState.mapId = 45
        mockState.mapType = MAPTYPE_SUBZONE
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 1, "Only 1 pin rendered after zooming back in")
        AssertEqual(mockPinManager._createdPins[1].pinTypeId, RPQuest.WorldMapArea.pinTypeId, "Zoom-in restores search area pin only")

        -- 7. Clear active quest while zoomed out: zoom-out pin disappears
        mockState.mapId = 27
        mockState.mapType = MAPTYPE_WORLD
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 1, "Zoom-out pin shown before untracking")
        RPQuest.QuestRepository:SetActiveQuest(nil)
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 0, "Zoom-out pin hidden when quest is untracked")

        -- 8. Fallback: quest without quest.worldX uses target/discovery worldX for zoom-out projection
        local legacyQuest = RPQuest.QuestRepository:BuildQuestRecord(999, "Legacy", "Desc", {
            { name = "Bandit", requiredCount = 1, zoneId = 104, worldX = 25000, worldZ = 35000 },
        }, { mapId = 45, zoneId = 104, areaCenterX = 0.4, areaCenterY = 0.6, areaRadius = 0.1 })
        table.insert(RPQuest.QuestRepository.savedVars.quests, legacyQuest)
        RPQuest.QuestRepository._questById[legacyQuest.id] = legacyQuest
        RPQuest.QuestRepository:SetActiveQuest(legacyQuest.id)
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 1, "Fallback target world coordinates project zoom-out pin")
        AssertEqual(mockPinManager._createdPins[1].pinTypeId, RPQuest.WorldMapArea.zoomOutPinTypeId, "Fallback renders zoom-out pin")

        mockState.projectedPositions = nil
    end)

    RunTest("Issue #277: Tamriel-wide kills when locationRequired=false and fallback ALERT_QUEST_FAILED_LOCATION", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.CombatTracker:Initialize()

        local customMsgCalls = {}
        local failedReasonCalls = {}
        local origCustom = RPQuest.Announcements.AnnounceTargetCustomMessage
        local origFailed = RPQuest.Announcements.AnnounceQuestFailed
        RPQuest.Announcements.AnnounceTargetCustomMessage = function(_, _, _, overrideText)
            table.insert(customMsgCalls, overrideText or "")
        end
        RPQuest.Announcements.AnnounceQuestFailed = function(_, _, target, reasonText)
            table.insert(failedReasonCalls, { target = target, reasonText = reasonText })
        end

        local origGetMapId = _G.GetCurrentMapId
        local origGetMapPos = _G.GetMapPlayerPosition
        local origGetWorldPos = _G.GetUnitWorldPosition

        -- 1. locationRequired == false -> kills count anywhere in Tamriel (different map/zone)
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Roamer",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.5,
            targetY = 0.5,
        })
        RPQuest.QuestRepository:UpdateDraftTarget(1, {
            locationRequired = false,
            customMessage = "Roamer down anywhere!",
            customMessageInLocation = "Must NOT fire",
            customMessageOutsideLocation = "Must NOT fire",
        })
        local qTamriel = RPQuest.QuestRepository:SaveDraft("Tamriel Hunt", "Desc")
        RPQuest.QuestRepository:SetActiveQuest(qTamriel.id)

        _G.GetCurrentMapId = function() return 999 end
        _G.GetMapPlayerPosition = function() return 0.99, 0.99 end
        _G.GetUnitWorldPosition = function() return 999, 99999, 0, 99999 end

        RPQuest.CombatTracker:OnCombatEvent(0, ACTION_RESULT_DIED, false, "", 0, 0, "Player", COMBAT_UNIT_TYPE_PLAYER, "Roamer", 0, 1, 0, 0, false, 1, 9501, 0)
        AssertEqual(qTamriel.completed, true, "Kill in completely different map/zone completes quest when locationRequired=false")
        AssertEqual(#customMsgCalls, 1, "Only customMessage fires")
        AssertEqual(customMsgCalls[1], "Roamer down anywhere!", "Exact general customMessage fired")

        -- 2. locationRequired == true with empty customMessageOutsideLocation -> fallback (reasonText == nil)
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Sentinel",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.5,
            targetY = 0.5,
        })
        RPQuest.QuestRepository:CaptureDraftTargetLocation(1, 381, 10000, 20000, 1000)
        RPQuest.QuestRepository:UpdateDraftTarget(1, {
            locationRequired = true,
            customMessage = "Must NOT fire",
            customMessageInLocation = "",
            customMessageOutsideLocation = "",
        })
        local qFallback = RPQuest.QuestRepository:SaveDraft("Fallback Fail", "Desc")
        RPQuest.QuestRepository:SetActiveQuest(qFallback.id)

        _G.GetUnitWorldPosition = function() return 381, 50000, 0, 50000 end
        RPQuest.CombatTracker:OnCombatEvent(0, ACTION_RESULT_DIED, false, "", 0, 0, "Player", COMBAT_UNIT_TYPE_PLAYER, "Sentinel", 0, 1, 0, 0, false, 1, 9502, 0)
        AssertEqual(qFallback.failed, true, "Quest fails outside required location")
        AssertEqual(#failedReasonCalls, 1, "AnnounceQuestFailed called")
        AssertEqual(failedReasonCalls[1].reasonText, nil, "Empty customMessageOutsideLocation falls back to nil (ALERT_QUEST_FAILED_LOCATION)")

        RPQuest.Announcements.AnnounceTargetCustomMessage = origCustom
        RPQuest.Announcements.AnnounceQuestFailed = origFailed
        _G.GetCurrentMapId = origGetMapId
        _G.GetMapPlayerPosition = origGetMapPos
        _G.GetUnitWorldPosition = origGetWorldPos
    end)

    RunTest("Issue #278: per-target search areas, soft-orange location pins, edit vs play visibility, and ShowQuestOnMap", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.WorldMapArea:Initialize()

        local origGetMapId = _G.GetCurrentMapId
        local origGetMapType = _G.GetMapType
        local origGetNormWorld = _G.GetNormalizedWorldPosition

        mockState.mapId = 45
        mockState.mapType = MAPTYPE_ZONE
        mockState.zoneId = 104
        _G.GetCurrentMapId = function() return mockState.mapId end
        _G.GetMapType = function() return mockState.mapType end
        _G.GetNormalizedWorldPosition = function(zoneId, wx, wy, wz)
            return wx / 100000, wz / 100000
        end

        -- 1. Edit mode (draft): ALWAYS renders both search areas and soft-orange Location areas even when toggles are false
        RPQuest.QuestRepository:SetSetting("showSearchAreas", false)
        RPQuest.QuestRepository:SetSetting("showLocationAreas", false)
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:UpdateDraftFields({ mapId = 45, zoneId = 104, recommendHideMapAreas = true })
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Bandit A",
            mapId = 45,
            zoneId = 104,
            targetX = 0.25,
            targetY = 0.25,
            areaRadius = 0.07,
        })
        RPQuest.QuestRepository:UpdateDraftTarget(1, {
            areaCenterX = 0.26,
            areaCenterY = 0.24,
            areaRadius = 0.07,
        })
        RPQuest.QuestRepository:CaptureDraftTargetLocation(1, 104, 25000, 25000, 800)
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Bandit B",
            mapId = 45,
            zoneId = 104,
            targetX = 0.75,
            targetY = 0.75,
            areaRadius = 0.125,
        })
        RPQuest.QuestRepository:UpdateDraftTarget(2, {
            areaCenterX = 0.74,
            areaCenterY = 0.76,
            areaRadius = 0.125,
        })
        RPQuest.QuestRepository:CaptureDraftTargetLocation(2, 104, 75000, 75000, 3000)

        RPQuest.WorldMapArea:RefreshPins()
        local draftSearchPins = {}
        local draftLocPins = {}
        for _, p in ipairs(mockPinManager._createdPins) do
            if p.pinTypeId == RPQuest.WorldMapArea.pinTypeId then
                table.insert(draftSearchPins, p)
            elseif p.pinTypeId == RPQuest.WorldMapArea.locationPinTypeId then
                table.insert(draftLocPins, p)
            end
        end
        AssertEqual(#draftSearchPins, 2, "Edit mode always renders 1 search area pin per pending target")
        AssertEqual(#draftLocPins, 2, "Edit mode always renders 1 location pin per pending target")
        local orange = RPQuest.Constants.UI.LOCATION_AREA_COLOR
        AssertEqual(draftLocPins[1].pinBlob.color.r, orange.r, "Location pin blob uses soft-orange red channel")
        AssertEqual(draftLocPins[1].pinBlob.color.g, orange.g, "Location pin blob uses soft-orange green channel")
        AssertEqual(draftLocPins[1].pinBlob.color.b, orange.b, "Location pin blob uses soft-orange blue channel")
        AssertTrue(draftLocPins[2].radius > draftLocPins[1].radius, "Projected location radius scales with world radius (30m > 8m)")

        -- 2. Play mode: both hidden by default (even if recommendHideMapAreas == false)
        RPQuest.QuestRepository:UpdateDraftFields({ recommendHideMapAreas = false })
        local quest = RPQuest.QuestRepository:SaveDraft("Multi Target Hunt", "Hunt both targets.")
        RPQuest.QuestRepository:SetActiveQuest(quest.id)

        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 0, "Play mode hides both search and location areas by default")

        -- 3. ShowQuestOnMap opens and centers map even when both visibility toggles are false
        mockState.mapId = 99
        mockState.lastPannedX = nil
        mockState.lastPannedY = nil
        local shown = RPQuest.WorldMapArea:ShowQuestOnMap(quest)
        AssertEqual(shown, true, "ShowQuestOnMap succeeds when area visibility toggles are false")
        AssertEqual(mockState.mapId, 45, "ShowQuestOnMap switches map to quest.mapId")
        AssertEqual(mockState.lastPannedX, 0.26, "ShowQuestOnMap pans to quest area X")
        AssertEqual(mockState.lastPannedY, 0.24, "ShowQuestOnMap pans to quest area Y")
        AssertEqual(#mockPinManager._createdPins, 0, "ShowQuestOnMap does not force-render hidden area pins")

        -- 4. Play mode: independent visibility toggles (showSearchAreas only)
        RPQuest.QuestRepository:SetSetting("showSearchAreas", true)
        RPQuest.QuestRepository:SetSetting("showLocationAreas", false)
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 2, "showSearchAreas=true renders 2 search area pins")
        for _, p in ipairs(mockPinManager._createdPins) do
            AssertEqual(p.pinTypeId, RPQuest.WorldMapArea.pinTypeId, "Only search area pins rendered when showLocationAreas=false")
        end

        -- 5. Play mode: independent visibility toggles (showLocationAreas only)
        RPQuest.QuestRepository:SetSetting("showSearchAreas", false)
        RPQuest.QuestRepository:SetSetting("showLocationAreas", true)
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 2, "showLocationAreas=true renders 2 location pins")
        for _, p in ipairs(mockPinManager._createdPins) do
            AssertEqual(p.pinTypeId, RPQuest.WorldMapArea.locationPinTypeId, "Only location pins rendered when showSearchAreas=false")
        end

        -- 6. Play mode: both enabled + completed target excluded
        quest.targets[1].currentCount = 1
        RPQuest.QuestRepository:SetSetting("showSearchAreas", true)
        RPQuest.QuestRepository:SetSetting("showLocationAreas", true)
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 2, "Completed target is excluded: 1 search pin + 1 location pin for target 2")

        -- 7. IsPlayerInsideQuestArea checks all pending targets' search areas
        quest.targets[1].currentCount = 0
        AssertEqual(RPQuest.WorldMapArea:IsPlayerInsideQuestArea(quest, 45, 104, 0.26, 0.24), true, "Player inside target 1 search area")
        AssertEqual(RPQuest.WorldMapArea:IsPlayerInsideQuestArea(quest, 45, 104, 0.74, 0.76), true, "Player inside target 2 search area")
        AssertEqual(RPQuest.WorldMapArea:IsPlayerInsideQuestArea(quest, 45, 104, 0.50, 0.50), false, "Player outside all pending search areas")

        -- Completed target 1 search area no longer counts
        quest.targets[1].currentCount = 1
        AssertEqual(RPQuest.WorldMapArea:IsPlayerInsideQuestArea(quest, 45, 104, 0.26, 0.24), false, "Completed target 1 search area ignored")
        AssertEqual(RPQuest.WorldMapArea:IsPlayerInsideQuestArea(quest, 45, 104, 0.74, 0.76), true, "Pending target 2 search area still valid")

        _G.GetCurrentMapId = origGetMapId
        _G.GetMapType = origGetMapType
        _G.GetNormalizedWorldPosition = origGetNormWorld
    end)

    RunTest("Issue #297: location area color persists on resize, unique pinTags, and differentiated tooltips", function()
        mockState.language = "en"
        RPQuest.Locale:Initialize("en")
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.WorldMapArea:Initialize()

        local origGetMapId = _G.GetCurrentMapId
        local origGetMapType = _G.GetMapType
        local origGetNormWorld = _G.GetNormalizedWorldPosition
        local origTooltip = _G.InformationTooltip

        mockState.mapId = 45
        mockState.mapType = MAPTYPE_ZONE
        mockState.zoneId = 104
        _G.GetCurrentMapId = function() return mockState.mapId end
        _G.GetMapType = function() return mockState.mapType end
        _G.GetNormalizedWorldPosition = function(zoneId, wx, wy, wz)
            return wx / 100000, wz / 100000
        end

        local tooltipLines = {}
        _G.InformationTooltip = {
            AddLine = function(_, text)
                table.insert(tooltipLines, text)
            end,
        }

        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:UpdateDraftFields({ mapId = 45, zoneId = 104 })
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Bandit A",
            mapId = 45,
            zoneId = 104,
            targetX = 0.25,
            targetY = 0.25,
            areaRadius = 0.07,
        })
        RPQuest.QuestRepository:UpdateDraftTarget(1, {
            areaCenterX = 0.26,
            areaCenterY = 0.24,
            areaRadius = 0.07,
            locationRequired = true,
        })
        RPQuest.QuestRepository:CaptureDraftTargetLocation(1, 104, 25000, 25000, 800)

        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Bandit B",
            mapId = 45,
            zoneId = 104,
            targetX = 0.75,
            targetY = 0.75,
            areaRadius = 0.125,
        })
        RPQuest.QuestRepository:UpdateDraftTarget(2, {
            areaCenterX = 0.74,
            areaCenterY = 0.76,
            areaRadius = 0.125,
            locationRequired = false,
        })
        RPQuest.QuestRepository:CaptureDraftTargetLocation(2, 104, 75000, 75000, 3000)

        local quest = RPQuest.QuestRepository:SaveDraft("Twin Targets", "Hunt both targets.")
        RPQuest.QuestRepository:SetActiveQuest(quest.id)
        RPQuest.QuestRepository:SetSetting("showSearchAreas", true)
        RPQuest.QuestRepository:SetSetting("showLocationAreas", true)
        RPQuest.WorldMapArea:RefreshPins()

        local searchPins = {}
        local locPins = {}
        for _, p in ipairs(mockPinManager._createdPins) do
            if p.pinTypeId == RPQuest.WorldMapArea.pinTypeId then
                table.insert(searchPins, p)
            elseif p.pinTypeId == RPQuest.WorldMapArea.locationPinTypeId then
                table.insert(locPins, p)
            end
        end
        AssertEqual(#searchPins, 2, "2 search area pins created")
        AssertEqual(#locPins, 2, "2 location area pins created")

        -- 1. Unique pinTags per pin/objective
        AssertEqual(searchPins[1].pinTag.questId, quest.id, "Search pin 1 tag has questId")
        AssertEqual(searchPins[1].pinTag.targetIndex, 1, "Search pin 1 tag has targetIndex 1")
        AssertEqual(searchPins[1].pinTag.kind, "search", "Search pin 1 tag has kind search")
        AssertEqual(searchPins[2].pinTag.targetIndex, 2, "Search pin 2 tag has targetIndex 2")
        AssertEqual(locPins[1].pinTag.questId, quest.id, "Location pin 1 tag has questId")
        AssertEqual(locPins[1].pinTag.targetIndex, 1, "Location pin 1 tag has targetIndex 1")
        AssertEqual(locPins[1].pinTag.kind, "location", "Location pin 1 tag has kind location")
        AssertEqual(locPins[2].pinTag.targetIndex, 2, "Location pin 2 tag has targetIndex 2")

        -- 2. Orange color persists across map resize/zoom
        local locCustomData = mockPinManager._customPins[RPQuest.WorldMapArea.locationPinTypeId]
        AssertTrue(locCustomData and locCustomData.resizeCallback ~= nil, "Location pin registers pinTypeOnResizeCallback")
        mockPinManager:SimulateResize()
        local orange = RPQuest.Constants.UI.LOCATION_AREA_COLOR
        for i, lp in ipairs(locPins) do
            AssertEqual(lp.pinBlob.color.r, orange.r, "Location pin " .. i .. " keeps orange red channel after resize")
            AssertEqual(lp.pinBlob.color.g, orange.g, "Location pin " .. i .. " keeps orange green channel after resize")
            AssertEqual(lp.pinBlob.color.b, orange.b, "Location pin " .. i .. " keeps orange blue channel after resize")
            AssertEqual(lp.pinBlob.color.a, orange.a, "Location pin " .. i .. " keeps orange alpha channel after resize")
        end

        -- 3. Differentiated tooltips: search area shows only that pin's target; location area uses its own creator
        local searchCreator = mockPinManager._customPins[RPQuest.WorldMapArea.pinTypeId].pinTooltipCreator
        local locCreator = mockPinManager._customPins[RPQuest.WorldMapArea.locationPinTypeId].pinTooltipCreator
        AssertTrue(searchCreator ~= locCreator, "Search and location pins use distinct tooltipCreator tables")

        tooltipLines = {}
        searchCreator.creator(searchPins[1])
        AssertEqual(#tooltipLines, 2, "Search pin 1 tooltip has header + 1 target line")
        AssertEqual(tooltipLines[1], "RPQuest: Twin Targets", "Search pin 1 tooltip header")
        AssertEqual(tooltipLines[2], "Search Area: Eliminate Bandit A (0/1)", "Search pin 1 tooltip shows only target 1")

        tooltipLines = {}
        searchCreator.creator(searchPins[2])
        AssertEqual(#tooltipLines, 2, "Search pin 2 tooltip has header + 1 target line")
        AssertEqual(tooltipLines[2], "Search Area: Eliminate Bandit B (0/1)", "Search pin 2 tooltip shows only target 2")

        tooltipLines = {}
        locCreator.creator(locPins[1])
        AssertEqual(#tooltipLines, 2, "Location pin 1 tooltip has header + 1 location line")
        AssertEqual(tooltipLines[2], "Target Location: Bandit A (Required, 8m)", "Location pin 1 tooltip shows Required and 8m")

        tooltipLines = {}
        locCreator.creator(locPins[2])
        AssertEqual(#tooltipLines, 2, "Location pin 2 tooltip has header + 1 location line")
        AssertEqual(tooltipLines[2], "Target Location: Bandit B (Optional, 30m)", "Location pin 2 tooltip shows Optional and 30m")

        _G.InformationTooltip = origTooltip
        _G.GetCurrentMapId = origGetMapId
        _G.GetMapType = origGetMapType
        _G.GetNormalizedWorldPosition = origGetNormWorld
    end)

    RunTest("Issue #298: purple discovery area pins, role-based visibility, resize persistence, auto-refresh, and spoiler-free tooltips", function()
        mockState.language = "en"
        RPQuest.Locale:Initialize("en")
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.WorldMapArea:Initialize()

        local origGetMapId = _G.GetCurrentMapId
        local origGetMapType = _G.GetMapType
        local origGetNormWorld = _G.GetNormalizedWorldPosition
        local origTooltip = _G.InformationTooltip

        mockState.mapId = 45
        mockState.mapType = MAPTYPE_ZONE
        mockState.zoneId = 104
        _G.GetCurrentMapId = function() return mockState.mapId end
        _G.GetMapType = function() return mockState.mapType end
        _G.GetNormalizedWorldPosition = function(zoneId, wx, wy, wz)
            return wx / 100000, wz / 100000
        end

        local tooltipLines = {}
        _G.InformationTooltip = {
            AddLine = function(_, text)
                table.insert(tooltipLines, text)
            end,
        }

        -- 1. Discovery-only draft (Edit mode): renders purple pins automatically even when showDiscoveryAreas = false
        RPQuest.QuestRepository:SetSetting("showDiscoveryAreas", false)
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:UpdateDraftFields({ mapId = 45, zoneId = 104 })
        RPQuest.QuestRepository:AddDraftDiscoveryPoint({
            zoneId = 104,
            worldX = 25000,
            worldY = 0,
            worldZ = 25000,
            mapId = 45,
            x = 0.25,
            y = 0.25,
            radius = 1500,
            message = "Secret shrine behind the waterfall.",
        })
        RPQuest.QuestRepository:AddDraftDiscoveryPoint({
            zoneId = 104,
            worldX = 75000,
            worldY = 0,
            worldZ = 75000,
            mapId = 45,
            x = 0.75,
            y = 0.75,
            radius = 3000,
            message = "Hidden ledger under the bridge.",
        })

        RPQuest.WorldMapArea:RefreshPins()
        local draftDiscPins = {}
        for _, p in ipairs(mockPinManager._createdPins) do
            if p.pinTypeId == RPQuest.WorldMapArea.discoveryPinTypeId then
                table.insert(draftDiscPins, p)
            end
        end
        AssertEqual(#draftDiscPins, 2, "Edit mode renders 2 purple discovery pins for discovery-only draft")
        local purple = RPQuest.Constants.UI.DISCOVERY_AREA_COLOR
        AssertEqual(draftDiscPins[1].pinBlob.color.r, purple.r, "Discovery pin uses purple red channel")
        AssertEqual(draftDiscPins[1].pinBlob.color.g, purple.g, "Discovery pin uses purple green channel")
        AssertEqual(draftDiscPins[1].pinBlob.color.b, purple.b, "Discovery pin uses purple blue channel")
        AssertEqual(draftDiscPins[1].pinBlob.color.a, purple.a, "Discovery pin uses purple alpha channel")
        AssertEqual(draftDiscPins[1].pinTag.discoveryIndex, 1, "Discovery pin 1 tag has discoveryIndex 1")
        AssertEqual(draftDiscPins[2].pinTag.discoveryIndex, 2, "Discovery pin 2 tag has discoveryIndex 2")

        -- Color persists across map resize/zoom
        local discCustomData = mockPinManager._customPins[RPQuest.WorldMapArea.discoveryPinTypeId]
        AssertTrue(discCustomData and discCustomData.resizeCallback ~= nil, "Discovery pin registers pinTypeOnResizeCallback")
        mockPinManager:SimulateResize()
        AssertEqual(draftDiscPins[1].pinBlob.color.r, purple.r, "Discovery pin keeps purple red channel after resize")
        AssertEqual(draftDiscPins[1].pinBlob.color.b, purple.b, "Discovery pin keeps purple blue channel after resize")

        -- Creator tooltip (Edit mode): shows index, radius in meters, and message summary
        local discCreator = discCustomData.pinTooltipCreator
        tooltipLines = {}
        discCreator.creator(draftDiscPins[1])
        AssertEqual(#tooltipLines, 2, "Creator discovery tooltip has header + 1 line")
        AssertEqual(tooltipLines[2], "Discovery #1: Secret shrine behind the waterfall.", "Creator tooltip shows index and message")

        -- 2. Prepared quest preview (Creator): renders all discovery points automatically + creator tooltip
        local prepared = RPQuest.QuestRepository:SaveDraft("Discovery Hunt", "Find the clues.")
        AssertEqual(RPQuest.WorldMapArea:ShouldRenderDiscoveryAreasOnCurrentMap(prepared), true, "Prepared quest renders discovery areas automatically")
        mockState.mapId = 99
        AssertEqual(RPQuest.WorldMapArea:ShouldRenderZoomOutOnCurrentMap(prepared), true, "ZoomOut pin enabled for discovery-only prepared quest")
        mockState.mapId = 45

        -- 3. Received quest (Play mode): hidden by default, spoiler-free tooltip, and auto-refresh on DISCOVERY_TRIGGERED
        local code = RPQuest.ShareCodec:EncodeQuest(prepared)
        local received = RPQuest.QuestRepository:ImportQuestFromCode(code)
        RPQuest.QuestRepository:SetActiveQuest(received.id)
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 0, "Play mode hides discovery areas by default")

        mockState.mapId = 99
        AssertEqual(RPQuest.WorldMapArea:ShouldRenderZoomOutOnCurrentMap(received), false, "ZoomOut pin hidden in play mode when all map toggles are false")
        RPQuest.QuestRepository:SetQuestMapVisibility(received.id, "showDiscoveryAreas", true)
        AssertEqual(RPQuest.WorldMapArea:ShouldRenderZoomOutOnCurrentMap(received), true, "ZoomOut pin shown for discovery-only quest when showDiscoveryAreas=true")
        mockState.mapId = 45

        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 2, "Play mode renders 2 pending discovery pins when showDiscoveryAreas=true")

        -- Player tooltip: spoiler-free (no radius, no hidden message)
        tooltipLines = {}
        discCreator.creator(mockPinManager._createdPins[1])
        AssertEqual(#tooltipLines, 2, "Player discovery tooltip has header + 1 line")
        AssertEqual(tooltipLines[2], "Discovery #1", "Player tooltip hides radius and secret message")

        -- Trigger discovery #1 while worldMap scene is showing -> auto-refreshes and hides discovered point
        local origIsShowing = SCENE_MANAGER.IsShowing
        SCENE_MANAGER.IsShowing = function(_, name)
            return name == "worldMap"
        end
        RPQuest.QuestRepository:MarkDiscoveryTriggered(received.id, 1)
        SCENE_MANAGER.IsShowing = origIsShowing

        AssertEqual(#mockPinManager._createdPins, 1, "DISCOVERY_TRIGGERED auto-refreshes map and removes discovered point")
        AssertEqual(mockPinManager._createdPins[1].pinTag.discoveryIndex, 2, "Only pending discovery point #2 remains on map")

        _G.InformationTooltip = origTooltip
        _G.GetCurrentMapId = origGetMapId
        _G.GetMapType = origGetMapType
        _G.GetNormalizedWorldPosition = origGetNormWorld
    end)

    RunTest("Issue #308: prepared quest in Test Quest uses player-mode discovery visibility, pending-only pins, and player tooltip", function()
        mockState.language = "en"
        RPQuest.Locale:Initialize("en")
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.WorldMapArea:Initialize()

        local origGetMapId = _G.GetCurrentMapId
        local origGetMapType = _G.GetMapType
        local origGetNormWorld = _G.GetNormalizedWorldPosition
        local origTooltip = _G.InformationTooltip

        mockState.mapId = 45
        mockState.mapType = MAPTYPE_ZONE
        mockState.zoneId = 104
        _G.GetCurrentMapId = function() return mockState.mapId end
        _G.GetMapType = function() return mockState.mapType end
        _G.GetNormalizedWorldPosition = function(zoneId, wx, wy, wz)
            return wx / 100000, wz / 100000
        end

        local tooltipLines = {}
        _G.InformationTooltip = {
            AddLine = function(_, text)
                table.insert(tooltipLines, text)
            end,
        }

        RPQuest.QuestRepository:SetSetting("showDiscoveryAreas", false)
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:UpdateDraftFields({ mapId = 45, zoneId = 104 })
        RPQuest.QuestRepository:AddDraftDiscoveryPoint({
            zoneId = 104,
            worldX = 25000,
            worldY = 0,
            worldZ = 25000,
            mapId = 45,
            x = 0.25,
            y = 0.25,
            radius = 1500,
            message = "Secret shrine behind the waterfall.",
        })
        RPQuest.QuestRepository:AddDraftDiscoveryPoint({
            zoneId = 104,
            worldX = 75000,
            worldY = 0,
            worldZ = 75000,
            mapId = 45,
            x = 0.75,
            y = 0.75,
            radius = 3000,
            message = "Hidden ledger under the bridge.",
        })

        local discCustomData = mockPinManager._customPins[RPQuest.WorldMapArea.discoveryPinTypeId]
        local discCreator = discCustomData.pinTooltipCreator

        -- 1. Draft in Edit mode: full creator view even when showDiscoveryAreas = false
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 2, "Draft in editor renders both discovery pins")
        tooltipLines = {}
        discCreator.creator(mockPinManager._createdPins[1])
        AssertEqual(tooltipLines[2], "Discovery #1: Secret shrine behind the waterfall.", "Draft in editor uses creator tooltip")

        -- 2. Prepared quest NOT in Test Quest: full creator view (all points + creator tooltip)
        local prepared = RPQuest.QuestRepository:SaveDraft("Discovery Hunt", "Find the clues.")
        prepared.discoveries[1].discovered = true
        RPQuest.WorldMapArea:ShowQuestOnMap(prepared)
        AssertEqual(#mockPinManager._createdPins, 2, "Prepared preview (not testing) renders all points including discovered")
        tooltipLines = {}
        discCreator.creator(mockPinManager._createdPins[1])
        AssertEqual(tooltipLines[2], "Discovery #1: Secret shrine behind the waterfall.", "Prepared preview (not testing) uses creator tooltip")

        -- 3. Prepared quest active in Test Quest: behaves 100% like player mode
        prepared.discoveries[1].discovered = false
        RPQuest.WorldMapArea.previewQuestId = nil
        local actOk = RPQuest.QuestRepository:SetActiveQuest(prepared.id)
        AssertEqual(actOk, true, "Prepared quest activated for Test Quest")

        -- 3a. showDiscoveryAreas = false -> hidden on map
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 0, "Test Quest hides discovery pins when showDiscoveryAreas=false")

        -- 3b. showDiscoveryAreas = true -> only pending points + player tooltip
        RPQuest.QuestRepository:SetQuestMapVisibility(prepared.id, "showDiscoveryAreas", true)
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(#mockPinManager._createdPins, 2, "Test Quest renders 2 pending discovery pins when showDiscoveryAreas=true")
        tooltipLines = {}
        discCreator.creator(mockPinManager._createdPins[1])
        AssertEqual(tooltipLines[2], "Discovery #1", "Test Quest uses spoiler-free player tooltip")

        -- 3c. Discovered point disappears from map during Test Quest
        local origIsShowing = SCENE_MANAGER.IsShowing
        SCENE_MANAGER.IsShowing = function(_, name)
            return name == "worldMap"
        end
        RPQuest.QuestRepository:MarkDiscoveryTriggered(prepared.id, 1)
        SCENE_MANAGER.IsShowing = origIsShowing

        AssertEqual(#mockPinManager._createdPins, 1, "Test Quest removes discovered point from map")
        AssertEqual(mockPinManager._createdPins[1].pinTag.discoveryIndex, 2, "Only pending discovery point #2 remains in Test Quest")

        _G.InformationTooltip = origTooltip
        _G.GetCurrentMapId = origGetMapId
        _G.GetMapType = origGetMapType
        _G.GetNormalizedWorldPosition = origGetNormWorld
    end)

    RunTest("Issue #309: repeated ShowQuestOnMap preserves quest mapId and pan when SetMapToMapId is unchanged", function()
        local sv = {}
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.WorldMapArea:Initialize()

        -- Create quest in Stonefalls (mapId = 27)
        mockState.reticleExists = true
        mockState.reticleName = "Cultista"
        mockState.reticleIsPlayer = false
        mockState.reticleIsDead = false
        mockState.reticleAttackable = true
        mockState.mapId = 27
        mockState.zoneId = 41
        mockState.mapName = "Stonefalls"
        mockState.playerX = 0.62
        mockState.playerY = 0.38

        RPQuest.TargetCapture:CaptureFromReticle()
        local quest = RPQuest.QuestRepository:SaveDraft("Repeated Map", "Desc", RPQuest.Constants.AREA_RADIUS.MEDIUM)
        local targetX = quest.targets[1].areaCenterX
        local targetY = quest.targets[1].areaCenterY

        -- Player is currently in Deshaan (mapId = 45), but internal mapId stayed on 27 after closing map
        local playerMapId = 45
        local playerChoseCurrentMap = false
        local origSetMapById = WORLD_MAP_MANAGER.SetMapById
        local origSetMapToMapId = SetMapToMapId
        local origMainMenuShow = MAIN_MENU_KEYBOARD.ShowCategory
        local origSceneShow = SCENE_MANAGER.Show
        local origSceneHide = SCENE_MANAGER.Hide

        SetMapToMapId = function(mapId)
            if mockState.mapId == mapId then
                return SET_MAP_RESULT_CURRENT_MAP_UNCHANGED
            end
            mockState.mapId = mapId
            return SET_MAP_RESULT_MAP_CHANGED
        end

        WORLD_MAP_MANAGER.SetMapById = function(self, mapId)
            if SetMapToMapId(mapId) == SET_MAP_RESULT_MAP_CHANGED then
                playerChoseCurrentMap = true
            end
        end

        local function SimulateWorldMapShowing()
            -- Simulate ZO_MapPanAndZoom:OnWorldMapShowing resetting to player location when g_playerChoseCurrentMap is false.
            WORLD_MAP_SCENE:FireCallbacks("StateChange", SCENE_HIDDEN, SCENE_SHOWING)
            if not playerChoseCurrentMap then
                mockState.mapId = playerMapId
                mockState.lastPannedX = 0.11
                mockState.lastPannedY = 0.12
            end
        end

        SCENE_MANAGER.Show = function(self, sceneName)
            if sceneName == "worldMap" then
                SimulateWorldMapShowing()
            end
            return origSceneShow(self, sceneName)
        end
        SCENE_MANAGER.Hide = function(self, sceneName)
            if sceneName == "worldMap" then
                playerChoseCurrentMap = false
                WORLD_MAP_SCENE:FireCallbacks("StateChange", SCENE_SHOWN, SCENE_HIDDEN)
            end
            return origSceneHide(self, sceneName)
        end
        MAIN_MENU_KEYBOARD.ShowCategory = function(self, category)
            if category == MENU_CATEGORY_MAP then
                SCENE_MANAGER:Show("worldMap")
            end
        end

        -- 1. First [M] from Deshaan: mapId changes 45 -> 27, playerChoseCurrentMap = true
        SCENE_MANAGER:Hide("worldMap")
        mockState.mapId = playerMapId
        local ok1 = RPQuest.WorldMapArea:ShowQuestOnMap(quest)
        AssertEqual(ok1, true, "First ShowQuestOnMap succeeds")
        AssertEqual(mockState.mapId, 27, "First [M] opens quest mapId 27")
        AssertEqual(mockState.lastPannedX, targetX, "First [M] pans to quest targetX")
        AssertEqual(mockState.lastPannedY, targetY, "First [M] pans to quest targetY")

        -- Close map (resets g_playerChoseCurrentMap = false, keeps internal mapId = 27)
        SCENE_MANAGER:Hide("worldMap")
        AssertEqual(mockState.mapId, 27, "Internal mapId stays 27 after closing map")
        AssertEqual(playerChoseCurrentMap, false, "g_playerChoseCurrentMap reset on map hide")

        -- 2. Second [M] on same quest: SetMapToMapId(27) returns UNCHANGED, OnWorldMapShowing resets to 45,
        --    and SCENE_SHOWN callback restores quest mapId 27 and pans to quest area.
        local ok2 = RPQuest.WorldMapArea:ShowQuestOnMap(quest)
        AssertEqual(ok2, true, "Second ShowQuestOnMap succeeds")
        AssertEqual(mockState.mapId, 27, "Second [M] preserves quest mapId 27 instead of reverting to player map 45")
        AssertEqual(mockState.lastPannedX, targetX, "Second [M] pans to quest targetX")
        AssertEqual(mockState.lastPannedY, targetY, "Second [M] pans to quest targetY")

        -- 3. Normal [M] outside RPQuest still resets to player location
        SCENE_MANAGER:Hide("worldMap")
        mockState.mapId = 27
        MAIN_MENU_KEYBOARD:ShowCategory(MENU_CATEGORY_MAP)
        AssertEqual(mockState.mapId, playerMapId, "Normal [M] outside RPQuest still opens on player mapId")

        WORLD_MAP_MANAGER.SetMapById = origSetMapById
        SetMapToMapId = origSetMapToMapId
        MAIN_MENU_KEYBOARD.ShowCategory = origMainMenuShow
        SCENE_MANAGER.Show = origSceneShow
        SCENE_MANAGER.Hide = origSceneHide
    end)

    RunTest("Issue #310: zoom-out emerald area with deterministic offset, search area emerald tint, resize persistence, and pulse cleanup", function()
        mockState.language = "en"
        RPQuest.Locale:Initialize("en")
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.WorldMapArea:Initialize()

        local origGetMapId = _G.GetCurrentMapId
        local origGetMapType = _G.GetMapType
        local origGetNormWorld = _G.GetNormalizedWorldPosition

        mockState.mapId = 45
        mockState.mapType = MAPTYPE_ZONE
        mockState.zoneId = 104
        local projX, projY = 0.62, 0.38
        _G.GetCurrentMapId = function() return mockState.mapId end
        _G.GetMapType = function() return mockState.mapType end
        _G.GetNormalizedWorldPosition = function()
            return projX, projY
        end

        -- 1. Zoom-out pin layout config uses circular blob (no vanilla arrow texture)
        local zoomLayout = mockPinManager._customPins[RPQuest.WorldMapArea.zoomOutPinTypeId].pinLayoutData
        AssertEqual(zoomLayout.texture, "", "ZoomOut pin has empty texture (blob only, no vanilla arrow)")
        AssertEqual(zoomLayout.showsPinAndArea, false, "ZoomOut pin sets showsPinAndArea=false")
        AssertTrue((zoomLayout.minAreaSize or 0) >= 48, "ZoomOut pin defines legible minAreaSize")

        -- 2. Create quest on map 45 with search area & world position
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:UpdateDraftFields({ mapId = 45, zoneId = 104, worldX = 50000, worldZ = 50000 })
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Emerald Guard",
            mapId = 45,
            zoneId = 104,
            targetX = 0.5,
            targetY = 0.5,
            areaRadius = 0.125,
            worldX = 50000,
            worldZ = 50000,
        })
        local quest = RPQuest.QuestRepository:SaveDraft("Emerald Hunt", "Track the guard.")
        RPQuest.QuestRepository:SetActiveQuest(quest.id)
        RPQuest.QuestRepository:SetSetting("showSearchAreas", true)

        -- Same-map search area uses emerald SEARCH_AREA_COLOR, pulses, and persists across resize
        ANIMATION_MANAGER._timelines = {}
        RPQuest.WorldMapArea:RefreshPins()
        local searchPins = {}
        for _, p in ipairs(mockPinManager._createdPins) do
            if p.pinTypeId == RPQuest.WorldMapArea.pinTypeId then
                table.insert(searchPins, p)
            end
        end
        AssertEqual(#searchPins, 1, "Same map renders 1 search area pin")
        local emerald = RPQuest.Constants.UI.SEARCH_AREA_COLOR
        AssertEqual(searchPins[1].pinBlob.color.r, emerald.r, "Search pin uses emerald red channel")
        AssertEqual(searchPins[1].pinBlob.color.g, emerald.g, "Search pin uses emerald green channel")
        AssertEqual(searchPins[1].pinBlob.color.b, emerald.b, "Search pin uses emerald blue channel")
        AssertEqual(searchPins[1].pinBlob.color.a, emerald.a, "Search pin uses emerald alpha channel")
        AssertTrue(#(RPQuest.WorldMapArea._activePulseAnimations or {}) == 1, "Search pin starts 1 pulse animation")
        local searchTl = RPQuest.WorldMapArea._activePulseAnimations[1].timeline
        AssertEqual(searchTl:IsPlaying(), true, "Search pulse timeline is playing")
        AssertEqual(searchTl._playbackType, ANIMATION_PLAYBACK_PING_PONG, "Pulse uses ping-pong playback")

        mockPinManager:SimulateResize()
        AssertEqual(searchPins[1].pinBlob.color.r, emerald.r, "Search pin keeps emerald red channel after resize")
        AssertEqual(searchPins[1].pinBlob.color.g, emerald.g, "Search pin keeps emerald green channel after resize")
        AssertEqual(searchPins[1].pinBlob.color.b, emerald.b, "Search pin keeps emerald blue channel after resize")

        -- 3. Zoom-out to parent/world map (mapId = 1, MAPTYPE_WORLD): renders deterministic offset emerald area
        mockState.mapId = 1
        mockState.mapType = MAPTYPE_WORLD
        RPQuest.WorldMapArea:RefreshPins()
        AssertEqual(searchTl:IsPlaying(), false, "Previous search pulse timeline stopped on RefreshPins")

        local zoomPins = {}
        for _, p in ipairs(mockPinManager._createdPins) do
            if p.pinTypeId == RPQuest.WorldMapArea.zoomOutPinTypeId then
                table.insert(zoomPins, p)
            end
        end
        AssertEqual(#zoomPins, 1, "Zoom-out map renders 1 zoom-out area pin")
        local zp = zoomPins[1]
        AssertEqual(zp.radius, RPQuest.Constants.AREA_RADIUS.MEDIUM, "Zoom-out pin uses medium normalized radius")
        AssertEqual(zp.pinBlob.color.r, emerald.r, "Zoom-out pin uses emerald red channel")
        AssertEqual(zp.pinBlob.color.g, emerald.g, "Zoom-out pin uses emerald green channel")
        AssertEqual(zp.pinBlob.color.b, emerald.b, "Zoom-out pin uses emerald blue channel")

        -- Offset is non-zero (does not reveal exact projected point) and target remains inside radius
        local dx = zp.x - projX
        local dy = zp.y - projY
        local dist = math.sqrt((dx * dx) + (dy * dy))
        AssertTrue(dist > 0.001, "Zoom-out area center is offset from exact projected position")
        AssertTrue(dist <= zp.radius, "Projected target remains inside zoom-out area radius")

        -- Reopening / refreshing produces identical deterministic center (no jumping)
        local firstX, firstY = zp.x, zp.y
        RPQuest.WorldMapArea:RefreshPins()
        local zp2 = mockPinManager._createdPins[1]
        AssertEqual(zp2.x, firstX, "Zoom-out offset X is deterministic across refreshes")
        AssertEqual(zp2.y, firstY, "Zoom-out offset Y is deterministic across refreshes")

        -- Zoom-out color persists across resize
        mockPinManager:SimulateResize()
        AssertEqual(zp2.pinBlob.color.r, emerald.r, "Zoom-out pin keeps emerald red channel after resize")
        AssertEqual(zp2.pinBlob.color.g, emerald.g, "Zoom-out pin keeps emerald green channel after resize")

        -- Pulse animation stops and detaches cleanly on SCENE_HIDDEN
        local zoomEntry = RPQuest.WorldMapArea._activePulseAnimations[1]
        AssertTrue(zoomEntry ~= nil and zoomEntry.timeline:IsPlaying(), "Zoom-out pulse timeline is playing")
        SCENE_MANAGER:Hide("worldMap")
        AssertEqual(zoomEntry.timeline:IsPlaying(), false, "Pulse timeline stops on SCENE_HIDDEN")
        AssertEqual(#(RPQuest.WorldMapArea._activePulseAnimations or {}), 0, "Active pulse animations cleared on SCENE_HIDDEN")
        AssertEqual(zoomEntry.anim._control, nil, "Animated control detached from pinBlob on cleanup")
        AssertEqual(zp2.pinBlob:GetAlpha(), 1, "pinBlob alpha restored to 1 on cleanup")

        _G.GetCurrentMapId = origGetMapId
        _G.GetMapType = origGetMapType
        _G.GetNormalizedWorldPosition = origGetNormWorld
    end)

    RunTest("Issue #321: editor selected target concentric ping priority, fallback, and cleanup", function()
        mockState.language = "en"
        RPQuest.Locale:Initialize("en")
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.WorldMapArea:Initialize()

        local origGetMapId = _G.GetCurrentMapId
        local origGetMapType = _G.GetMapType
        local origGetNormWorld = _G.GetNormalizedWorldPosition
        local origCallLater = _G.zo_callLater
        local origSetMapById = WORLD_MAP_MANAGER.SetMapById

        local scheduled = {}
        _G.zo_callLater = function(fn, delayMs)
            table.insert(scheduled, { fn = fn, delayMs = delayMs })
        end

        mockState.mapId = 45
        mockState.mapType = MAPTYPE_ZONE
        mockState.zoneId = 104
        WORLD_MAP_MANAGER.SetMapById = function(_, mapId)
            mockState.mapId = mapId
        end
        _G.GetCurrentMapId = function() return mockState.mapId end
        _G.GetMapType = function() return mockState.mapType end
        _G.GetNormalizedWorldPosition = function(_, worldX, _, worldZ)
            if worldX == 1000 and worldZ == 2000 then
                return 0.75, 0.85
            elseif worldX == 1800 and worldZ == 2000 then
                return 0.78, 0.85
            end
            return nil, nil
        end

        local pingTypeId = RPQuest.WorldMapArea.targetPingPinTypeId
        AssertTrue(pingTypeId ~= nil, "Target ping custom pin type is registered")
        local pingLayout = mockPinManager._customPins[pingTypeId].pinLayoutData
        AssertEqual(pingLayout.texture, "EsoUI/Art/MapPins/QuestPing.dds", "Target ping uses QuestPing.dds texture")
        AssertEqual(pingLayout.framesWide, 32, "Target ping uses 32 horizontal frames")
        AssertEqual(pingLayout.framesHigh, 1, "Target ping uses 1 vertical frame")
        AssertEqual(pingLayout.framesPerSecond, 32, "Target ping runs at 32 fps")
        AssertEqual(pingLayout.isAnimated, true, "Target ping is animated")
        AssertEqual(pingLayout.minSize, 100, "Target ping minSize is 100")

        local function CountPingPins()
            local count = 0
            local lastPin = nil
            for _, p in ipairs(mockPinManager._createdPins) do
                if p.pinTypeId == pingTypeId then
                    count = count + 1
                    lastPin = p
                end
            end
            return count, lastPin
        end

        local quest = {
            id = "q_321",
            title = "Target Ping Quest",
            mapId = 45,
            zoneId = 104,
            showSearchAreas = false,
            showLocationAreas = false,
            targets = {
                {
                    name = "Target With Area And Location",
                    areaCenterX = 0.25,
                    areaCenterY = 0.35,
                    areaRadius = RPQuest.Constants.AREA_RADIUS.SMALL,
                    worldX = 1000,
                    worldZ = 2000,
                    zoneId = 104,
                    mapId = 45,
                },
                {
                    name = "Target With Location Only",
                    worldX = 1000,
                    worldZ = 2000,
                    zoneId = 104,
                    mapId = 45,
                },
                {
                    name = "Target Without Coordinates",
                },
            },
        }

        -- 1. Priority: Search Area center wins over Location projection
        SCENE_MANAGER:Show("worldMap")
        scheduled = {}
        local ok1 = RPQuest.WorldMapArea:ShowQuestOnMap(quest, 1)
        AssertEqual(ok1, true, "ShowQuestOnMap succeeds for target 1")
        AssertEqual(mockState.lastPannedX, 0.25, "Search Area X takes priority over Location X")
        AssertEqual(mockState.lastPannedY, 0.35, "Search Area Y takes priority over Location Y")
        local c1, p1 = CountPingPins()
        AssertEqual(c1, 1, "Creates 1 target ping pin for target 1")
        AssertEqual(p1.x, 0.25, "Ping pin placed at Search Area X")
        AssertEqual(p1.y, 0.35, "Ping pin placed at Search Area Y")

        local pingTimer1 = nil
        for _, item in ipairs(scheduled) do
            if item.delayMs == 4500 then
                pingTimer1 = item.fn
            end
        end
        AssertTrue(pingTimer1 ~= nil, "Schedules ~4.5s (4500ms) cleanup timer for target ping")

        -- 2. Second ShowQuestOnMap on target 2 (Location only) replaces ping and invalidates timer 1
        scheduled = {}
        local ok2 = RPQuest.WorldMapArea:ShowQuestOnMap(quest, 2)
        AssertEqual(ok2, true, "ShowQuestOnMap succeeds for target 2")
        AssertEqual(mockState.lastPannedX, 0.75, "Location projection X used when Search Area is absent")
        AssertEqual(mockState.lastPannedY, 0.85, "Location projection Y used when Search Area is absent")
        local c2, p2 = CountPingPins()
        AssertEqual(c2, 1, "Replaces previous ping with 1 pin for target 2")
        AssertEqual(p2.x, 0.75, "Ping pin placed at Location projection X")
        AssertEqual(p2.y, 0.85, "Ping pin placed at Location projection Y")

        -- Firing stale timer 1 must not clear target 2's ping
        pingTimer1()
        local cAfterStale = CountPingPins()
        AssertEqual(cAfterStale, 1, "Stale timer from previous ShowQuestOnMap does not clear new ping")

        -- Firing active timer 2 clears the ping
        local pingTimer2 = nil
        for _, item in ipairs(scheduled) do
            if item.delayMs == 4500 then
                pingTimer2 = item.fn
            end
        end
        AssertTrue(pingTimer2 ~= nil, "Schedules 4500ms timer for target 2")
        pingTimer2()
        local cAfterExpire = CountPingPins()
        AssertEqual(cAfterExpire, 0, "Ping is removed after 4.5s timer expires")

        -- 3. Closing map scene (SCENE_HIDDEN) cleans up active ping
        RPQuest.WorldMapArea:ShowQuestOnMap(quest, 1)
        AssertEqual(CountPingPins(), 1, "Ping active before closing map")
        SCENE_MANAGER:Hide("worldMap")
        AssertEqual(CountPingPins(), 0, "Ping is removed when map scene closes")

        -- 4. Target without own coordinates falls back to ResolveQuestMapTarget without ping
        SCENE_MANAGER:Show("worldMap")
        local ok3 = RPQuest.WorldMapArea:ShowQuestOnMap(quest, 3)
        AssertEqual(ok3, true, "Fallback ShowQuestOnMap succeeds for target without own coordinates")
        AssertEqual(mockState.lastPannedX, 0.25, "Fallback centers on quest general target X")
        AssertEqual(mockState.lastPannedY, 0.35, "Fallback centers on quest general target Y")
        AssertEqual(CountPingPins(), 0, "No target ping shown when selected target has no own coordinates")

        SCENE_MANAGER:Hide("worldMap")
        _G.GetCurrentMapId = origGetMapId
        _G.GetMapType = origGetMapType
        _G.GetNormalizedWorldPosition = origGetNormWorld
        _G.zo_callLater = origCallLater
        WORLD_MAP_MANAGER.SetMapById = origSetMapById
    end)

end
