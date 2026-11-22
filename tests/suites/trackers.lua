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

        -- En el mismo mapa (mapId 45) debe dibujarse 1 pin de área grande
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
        local shown = RPQuest.WorldMapArea:ShowQuestOnMap(stonefallsQuest)
        AssertEqual(shown, true, "ShowQuestOnMap returns true")
        AssertEqual(setMapByIdCalledWith, 27, "WORLD_MAP_MANAGER:SetMapById called with Stonefalls mapId")
        AssertEqual(callOrder[1], "SetMapById", "SetMapById called before opening world map")
        AssertEqual(callOrder[2], "ShowScene:worldMap", "World map opened after SetMapById")
        AssertEqual(mockState.mapId, 27, "Current mapId switched to Stonefalls")
        AssertEqual(#mockPinManager._createdPins, 1, "Stonefalls quest pin rendered when viewing from Deshaan")
        AssertEqual(mockState.lastPannedX, stonefallsQuest.areaCenterX, "Map panned to quest areaCenterX")
        AssertEqual(mockState.lastPannedY, stonefallsQuest.areaCenterY, "Map panned to quest areaCenterY")

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
        RPQuest.QuestRepository:UpdateDraftFields({ requireUndetected = true })
        RPQuest.JournalTab:RefreshEditorPane()
        AssertTrue(RPQuest.JournalTab.btnRequireUndetected:GetText():find("%[X%]") ~= nil, "Editor toggle shows [X] when requireUndetected is true")

        local prepared = RPQuest.QuestRepository:SaveDraft("Contrato de Sigilo", "Sin testigos.", nil, "Trabajo limpio.")
        AssertTrue(prepared ~= nil, "Saved stealth quest")
        AssertEqual(prepared.requireUndetected, true, "Prepared quest has requireUndetected = true")
        AssertEqual(prepared.wasDetected, false, "Prepared quest starts with wasDetected = false")

        -- 2. ShareCodec preserves requireUndetected
        local shareCode = RPQuest.QuestRepository:ExportQuestToCode(prepared.id)
        local imported = RPQuest.QuestRepository:ImportQuestFromCode(shareCode)
        AssertTrue(imported ~= nil, "Imported stealth quest")
        AssertEqual(imported.requireUndetected, true, "Imported quest preserves requireUndetected = true")
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
        mockState.playerX = imported.areaCenterX
        mockState.playerY = imported.areaCenterY
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
        RPQuest.Announcements.AnnounceTargetCustomMessage = function(self, quest, target)
            table.insert(customMsgCalls, target.customMessage)
            origCustom(self, quest, target)
        end
        RPQuest.Announcements.AnnounceQuestFailed = function(self, quest, target)
            table.insert(failedCalls, quest.id)
            origFailed(self, quest, target)
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
            customMessage = "Silent takedown in the alley.",
        })
        local qReq = RPQuest.QuestRepository:SaveDraft("Required Loc Quest", "Desc")
        RPQuest.QuestRepository:SetActiveQuest(qReq.id)

        -- Kill outside required location -> fails quest, kill does NOT count
        _G.GetUnitWorldPosition = function() return 381, 50000, 0, 50000 end
        RPQuest.CombatTracker:OnCombatEvent(0, ACTION_RESULT_DIED, false, "", 0, 0, "Player", COMBAT_UNIT_TYPE_PLAYER, "Guard", 0, 1, 0, 0, false, 1, 901, 0)
        AssertEqual(qReq.failed, true, "Quest fails when required location target is killed outside radius")
        AssertEqual(qReq.targets[1].currentCount, 0, "Kill outside required location does not count")
        AssertEqual(#failedCalls, 1, "AnnounceQuestFailed called once")
        AssertEqual(RPQuest.QuestRepository:GetActiveQuest(), nil, "Failed quest is deactivated")

        -- Reset quest and kill inside required location -> counts kill + shows customMessage
        RPQuest.QuestRepository:ResetQuest(qReq.id)
        AssertEqual(qReq.failed, false, "ResetQuest clears failed flag")
        _G.GetUnitWorldPosition = function() return 381, 10200, 0, 20200 end
        RPQuest.CombatTracker:OnCombatEvent(0, ACTION_RESULT_DIED, false, "", 0, 0, "Player", COMBAT_UNIT_TYPE_PLAYER, "Guard", 0, 1, 0, 0, false, 1, 902, 0)
        AssertEqual(qReq.targets[1].currentCount, 1, "Kill inside required location counts")
        AssertEqual(qReq.completed, true, "Quest completes on kill inside required location")
        AssertEqual(#customMsgCalls, 1, "Custom message shown inside required location")
        AssertEqual(customMsgCalls[1], "Silent takedown in the alley.", "Exact custom message emitted")

        -- Case 3: Optional location + defined point
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
            customMessage = "Scout ambushed at the bridge!",
        })
        RPQuest.QuestRepository:GetDraft().targets[1].requiredCount = 2
        local qOpt = RPQuest.QuestRepository:SaveDraft("Optional Loc Quest", "Desc")
        RPQuest.QuestRepository:SetActiveQuest(qOpt.id)

        -- Kill outside defined point -> counts kill, does NOT show customMessage, does NOT fail
        _G.GetUnitWorldPosition = function() return 381, 50000, 0, 50000 end
        RPQuest.CombatTracker:OnCombatEvent(0, ACTION_RESULT_DIED, false, "", 0, 0, "Player", COMBAT_UNIT_TYPE_PLAYER, "Scout", 0, 1, 0, 0, false, 1, 903, 0)
        AssertEqual(qOpt.failed, false, "Optional location does not fail quest outside radius")
        AssertEqual(qOpt.targets[1].currentCount, 1, "Kill outside optional location still counts")
        AssertEqual(#customMsgCalls, 1, "Custom message NOT shown outside optional location")

        -- Kill inside defined point -> counts kill + shows customMessage
        _G.GetUnitWorldPosition = function() return 381, 10100, 0, 20100 end
        RPQuest.CombatTracker:OnCombatEvent(0, ACTION_RESULT_DIED, false, "", 0, 0, "Player", COMBAT_UNIT_TYPE_PLAYER, "Scout", 0, 1, 0, 0, false, 1, 904, 0)
        AssertEqual(qOpt.targets[1].currentCount, 2, "Second kill inside optional location counts")
        AssertEqual(#customMsgCalls, 2, "Custom message shown inside optional location")

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
        AssertEqual(#customMsgCalls, 3, "Custom message shown anywhere when no location defined")

        -- ShareCodec roundtrip for target conditions & custom message
        local exported = RPQuest.QuestRepository:ExportQuestToCode(qReq.id)
        local decoded = RPQuest.ShareCodec:DecodeQuest(exported)
        AssertTrue(decoded ~= nil and decoded.targets ~= nil and #decoded.targets == 1, "Encoded quest with target condition decoded")
        AssertEqual(decoded.targets[1].zoneId, 381, "Target zoneId preserved in ShareCodec")
        AssertEqual(decoded.targets[1].worldX, 10000, "Target worldX preserved in ShareCodec")
        AssertEqual(decoded.targets[1].worldZ, 20000, "Target worldZ preserved in ShareCodec")
        AssertEqual(decoded.targets[1].radius, 1000, "Target radius preserved in ShareCodec")
        AssertEqual(decoded.targets[1].locationRequired, true, "Target locationRequired preserved in ShareCodec")
        AssertEqual(decoded.targets[1].customMessage, "Silent takedown in the alley.", "Target customMessage preserved in ShareCodec")

        RPQuest.Announcements.AnnounceTargetCustomMessage = origCustom
        RPQuest.Announcements.AnnounceQuestFailed = origFailed
        _G.GetCurrentMapId = origGetMapId
        _G.GetMapPlayerPosition = origGetMapPos
        _G.GetUnitWorldPosition = origGetWorldPos
    end)

end
