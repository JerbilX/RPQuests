-- ============================================================================
-- RPQuest Test Suite: QuestRepository & Persistence Suites
-- ============================================================================
return function(T)
    local RunTest = T.RunTest
    local AssertEqual = T.AssertEqual
    local AssertTrue = T.AssertTrue
    local mockState = T.mockState

    RunTest("QuestRepository offset calculation keeps target inside circle but off-center", function()
        RPQuest.QuestRepository:Initialize({})
        local tx, ty = 0.50, 0.50
        local radius = 0.08
        for i = 0, 10 do
            local cx, cy = RPQuest.QuestRepository:ComputeOffsetCenter(tx, ty, radius, i / 10, 0.5)
            local dx = tx - cx
            local dy = ty - cy
            local dist = math.sqrt((dx * dx) + (dy * dy))
            AssertTrue(dist > 0.005, "Center must not be identical to target exact point")
            AssertTrue(dist < radius, "Target must strictly lie inside the search circle radius")
        end
    end)

    RunTest("Unified 5-tier AREA_RADIUS and DISCOVERY_RADIUS progression and ComputeOffsetCenter bounds", function()
        RPQuest.QuestRepository:Initialize({})
        local radii = RPQuest.Constants.AREA_RADIUS
        local discRadii = RPQuest.Constants.DISCOVERY_RADIUS
        local mult = RPQuest.Constants.AREA_SUBZONE_MULTIPLIER
        AssertTrue(math.abs(radii.TINY - 0.008) < 0.0001, "AREA_RADIUS.TINY matches 800 world units normalized (0.008)")
        AssertTrue(math.abs(radii.HUGE - 0.070) < 0.0001, "AREA_RADIUS.HUGE matches legacy Small search area (0.070)")
        AssertTrue(radii.TINY < radii.SMALL and radii.SMALL < radii.MEDIUM and radii.MEDIUM < radii.LARGE and radii.LARGE < radii.HUGE, "AREA_RADIUS maintains coherent 5-tier progression")
        AssertEqual(discRadii.TINY, 800, "DISCOVERY_RADIUS.TINY is 800 world units (~8m)")
        AssertEqual(discRadii.HUGE, 7000, "DISCOVERY_RADIUS.HUGE matches 0.070 normalized (7000 world units)")
        AssertTrue(discRadii.TINY < discRadii.SMALL and discRadii.SMALL < discRadii.MEDIUM and discRadii.MEDIUM < discRadii.LARGE and discRadii.LARGE < discRadii.HUGE, "DISCOVERY_RADIUS maintains coherent 5-tier progression")
        AssertTrue(mult > 1.0, "Subzone multiplier enlarges city/subzone maps")

        local testRadii = { radii.TINY, radii.SMALL, radii.MEDIUM, radii.LARGE, radii.HUGE, radii.MEDIUM * mult, radii.HUGE * mult }
        local corners = { { 0.01, 0.01 }, { 0.99, 0.01 }, { 0.01, 0.99 }, { 0.99, 0.99 }, { 0.50, 0.50 } }
        for _, r in ipairs(testRadii) do
            for _, pt in ipairs(corners) do
                for i = 0, 7 do
                    local cx, cy = RPQuest.WorldMapArea:ComputeOffsetCenter(pt[1], pt[2], r, i / 8, 1.0)
                    AssertTrue(cx >= 0 and cx <= 1, "Offset center X stays within [0, 1]")
                    AssertTrue(cy >= 0 and cy <= 1, "Offset center Y stays within [0, 1]")
                    local dx = pt[1] - cx
                    local dy = pt[2] - cy
                    local dist = math.sqrt((dx * dx) + (dy * dy))
                    AssertTrue(dist < r, "Target remains strictly inside enlarged circle")
                end
            end
        end
    end)

    RunTest("QuestRepository full lifecycle: Draft, Save, Edit, Kill Progress, Complete, Reset, Export/Import, Delete", function()
        mockState.language = "es"
        RPQuest.Locale:Initialize("es")
        RPQuest.QuestRepository:Initialize({})

        -- 1. Capturar objetivo en borrador (2 veces para inferir requiredCount = 2)
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Nigromante Oscuro^m",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.40,
            targetY = 0.60,
        })
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Nigromante Oscuro^m",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.40,
            targetY = 0.60,
        })

        -- 2. Guardar misión con 2 bajas requeridas inferidas
        local quest, err = RPQuest.QuestRepository:SaveDraft("Purga en el Bosque", "Elimina a los nigromantes.", 0.075)
        AssertTrue(quest ~= nil, "Quest should be created: " .. tostring(err))
        AssertEqual(quest.role, RPQuest.Constants.QUEST_ROLE.PREPARED, "Newly created quest has role=prepared")
        AssertEqual(quest.targets[1].name, "Nigromante Oscuro", "Gender suffix stripped")
        AssertEqual(quest.targets[1].requiredCount, 2, "Required count is 2")
        AssertEqual(RPQuest.QuestRepository:GetActiveQuest(), nil, "Newly created prepared quest does not auto-activate")
        RPQuest.QuestRepository:SetActiveQuest(quest.id)
        AssertEqual(RPQuest.QuestRepository:GetActiveQuest().id, quest.id, "Prepared quest can be activated manually for local testing")

        -- 3. Editar la misión
        RPQuest.QuestRepository:LoadQuestIntoDraft(quest.id)
        local updated = RPQuest.QuestRepository:SaveDraft("Purga Real en el Bosque", "Nueva descripción", 0.075)
        AssertEqual(updated.title, "Purga Real en el Bosque", "Quest title updated in place")
        AssertEqual(#RPQuest.QuestRepository:GetAllQuests(), 1, "Still 1 quest after edit")

        -- 4. Progreso de bajas en cualquier lugar de Tamriel cuando locationRequired == false
        local recAnywhere = RPQuest.QuestRepository:RecordTargetEliminated("Nigromante Oscuro", {
            mapId = 999,
            zoneId = 999,
            x = 0.40,
            y = 0.60,
        })
        AssertTrue(recAnywhere, "Kill in any map/zone counts when locationRequired is false")
        AssertEqual(quest.targets[1].currentCount, 1, "Current count is 1 after Tamriel-wide kill")

        -- 5. Segunda baja válida (2/2 -> Completada)
        local rec2, _, comp2 = RPQuest.QuestRepository:RecordTargetEliminated("Nigromante Oscuro^m", {
            mapId = 32,
            zoneId = 381,
            x = 0.40,
            y = 0.60,
        })
        AssertTrue(rec2, "Second valid kill recorded")
        AssertTrue(comp2, "Completed at 2/2")
        AssertTrue(quest.completed, "Quest marked completed")
        AssertEqual(RPQuest.QuestRepository:GetActiveQuest(), nil, "Active quest cleared upon completion")
        AssertEqual(#RPQuest.QuestRepository:GetCompletedQuests(), 1, "1 quest in completed list")

        -- 7. Exportar e Importar misión por código
        local shareCode = RPQuest.QuestRepository:ExportQuestToCode(quest.id)
        AssertTrue(shareCode ~= nil, "Share code exported")
        local imported, impErr = RPQuest.QuestRepository:ImportQuestFromCode(shareCode)
        AssertTrue(imported ~= nil, "Imported quest created: " .. tostring(impErr))
        AssertEqual(imported.title, "Purga Real en el Bosque", "Imported title matches")
        AssertEqual(imported.completed, false, "Imported quest starts uncompleted")
        AssertEqual(imported.targets[1].currentCount, 0, "Imported quest starts at 0 kills")
        AssertEqual(RPQuest.QuestRepository:GetActiveQuest().id, imported.id, "Imported quest becomes active")

        -- 8. Reiniciar misión completada
        RPQuest.QuestRepository:ResetQuest(quest.id)
        AssertEqual(quest.completed, false, "Reset quest is uncompleted")
        AssertEqual(quest.targets[1].currentCount, 0, "Reset quest count is 0")

        -- 9. Eliminar misiones
        AssertTrue(RPQuest.QuestRepository:DeleteQuest(imported.id), "Delete imported quest")
        AssertTrue(RPQuest.QuestRepository:DeleteQuest(quest.id), "Delete original quest")
        AssertEqual(#RPQuest.QuestRepository:GetAllQuests(), 0, "All quests deleted")
    end)

    RunTest("13. Separación de roles: En Preparación vs Para Jugar, prueba local y bloqueo de edición en recibidas", function()
        mockState.language = "es"
        RPQuest.Locale:Initialize("es")

        -- 1. Migración de misiones legacy sin campo role -> received
        RPQuest.QuestRepository:Initialize({
            nextId = 2,
            quests = {
                { id = 1, title = "Legacy", description = "", targets = { { name = "Imp", currentCount = 0, requiredCount = 1 } }, completed = false },
            },
        })
        local legacy = RPQuest.QuestRepository:GetQuestById(1)
        AssertEqual(legacy.role, RPQuest.Constants.QUEST_ROLE.RECEIVED, "Legacy quest without role migrates to received")

        RPQuest.JournalTab:Initialize()
        RPQuest.JournalTab.collapsedSections = { missions = false, completed = true, preparing = true, sent = true }
        RPQuest.JournalTab:Refresh()
        -- Sin misiones en preparación, la sección PREPARANDO no aparece en el árbol
        local hasPreparingHeader = false
        for _, b in pairs(RPQuest.JournalTab.rowBindings) do
            if b.isHeader and b.sectionKey == "preparing" then
                hasPreparingHeader = true
            end
        end
        AssertEqual(hasPreparingHeader, false, "PREPARANDO section is hidden when empty")
        AssertEqual(RPQuest.JournalTab.collapsedSections.missions, false, "MISIONES section starts expanded")
        AssertEqual(RPQuest.JournalTab.collapsedSections.completed, true, "COMPLETADAS section starts collapsed")
        AssertEqual(RPQuest.JournalTab.collapsedSections.preparing, true, "PREPARANDO section starts collapsed")

        mockState.reticleExists = true
        mockState.reticleName = "Cultista"
        mockState.mapId = 32
        mockState.zoneId = 381
        mockState.mapName = "Auridon"
        mockState.playerX = 0.5
        mockState.playerY = 0.5

        -- 2. Crear misión nueva -> role=prepared, no se auto-activa, expande PREPARANDO
        RPQuest.TargetCapture:CaptureFromReticle()
        local prep = RPQuest.QuestRepository:SaveDraft("Misión GM", "Para probar y enviar", 0.05)
        AssertEqual(prep.role, RPQuest.Constants.QUEST_ROLE.PREPARED, "Created quest is prepared")
        AssertEqual(RPQuest.QuestRepository:GetActiveQuest(), nil, "Created quest does not auto-activate")
        AssertEqual(RPQuest.JournalTab.collapsedSections.preparing, false, "JournalTab expands PREPARANDO on create")
        AssertEqual(RPQuest.JournalTab.btnEdit:IsHidden(), false, "Edit button visible for prepared quest")
        AssertEqual(RPQuest.JournalTab.btnActivate:GetText(), "Probar", "Activate button says Probar for prepared quest")

        -- 2b. Acordeón excluyente: la sección abierta nunca se colapsa al hacer clic de nuevo (con o sin ítem seleccionado)
        RPQuest.JournalTab:ToggleSection("preparing")
        AssertEqual(RPQuest.JournalTab.collapsedSections.preparing, false, "Section with selected quest stays expanded")
        RPQuest.JournalTab:SelectQuest(nil)
        RPQuest.JournalTab:ToggleSection("preparing")
        AssertEqual(RPQuest.JournalTab.collapsedSections.preparing, false, "ToggleSection keeps preparing expanded even when no item is selected/active")
        local prepRowVisible = false
        for _, b in pairs(RPQuest.JournalTab.rowBindings) do
            if b.questId == prep.id then prepRowVisible = true end
        end
        AssertEqual(prepRowVisible, true, "Expanded section keeps its quest rows visible")
        RPQuest.JournalTab:SelectQuest(prep.id)

        -- 2c. Mostrar en mapa una misión en preparación (aunque no esté activa)
        RPQuest.QuestRepository:SetSetting("showSearchAreas", true)
        RPQuest.WorldMapArea:Initialize()
        RPQuest.WorldMapArea:ShowQuestOnMap(prep)
        local pins = ZO_WorldMap_GetPinManager()._createdPins
        AssertEqual(#pins, 1, "ShowQuestOnMap renders area pin for prepared quest even when inactive")
        AssertEqual(pins[1].pinTag.questId, prep.id, "Rendered preview pin belongs to prepared quest")
        AssertEqual(pins[1].radius, 0.05, "Rendered preview pin uses prepared quest radius")

        -- 3. Probar localmente y luego detener prueba
        RPQuest.JournalTab:OnToggleActiveClicked()
        AssertEqual(RPQuest.QuestRepository:GetActiveQuest().id, prep.id, "Prepared quest activated for local testing")
        AssertEqual(RPQuest.JournalTab.btnActivate:GetText(), "Dejar de probar", "Activate button says Dejar de probar while testing")

        -- 4. Compartir e importar -> misión recibida en MISIONES sin botón Editar
        local code = RPQuest.QuestRepository:ExportQuestToCode(prep.id)
        local imported = RPQuest.QuestRepository:ImportQuestFromCode(code)
        AssertEqual(imported.role, RPQuest.Constants.QUEST_ROLE.RECEIVED, "Imported quest has role=received")
        AssertEqual(RPQuest.JournalTab.collapsedSections.missions, false, "JournalTab expands MISIONES on import")
        AssertEqual(RPQuest.JournalTab.btnEdit:IsHidden(), true, "Edit button hidden for received quest")
        AssertEqual(RPQuest.JournalTab.btnReset:IsHidden(), true, "Reset button hidden for received quest")
        AssertEqual(RPQuest.JournalTab.btnActivate:GetText(), "Desactivar", "Imported quest is active so button says Desactivar")

        local deniedDraft, deniedErr = RPQuest.QuestRepository:LoadQuestIntoDraft(imported.id)
        AssertEqual(deniedDraft, nil, "LoadQuestIntoDraft rejects received quest")
        AssertTrue(type(deniedErr) == "string" and deniedErr ~= "", "Rejection returns localized error message")
    end)

    RunTest("15. Codigo de entrega RPQC1 y validacion por el Master", function()
        RPQuest.QuestRepository:Initialize({})
        RPQuest.JournalTab:Initialize()
        mockState.reticleExists = true
        mockState.reticleName = "Capitán Pirata^m"
        mockState.reticleIsPlayer = false
        mockState.reticleIsDead = false
        mockState.reticleAttackable = true
        mockState.mapId = 32
        mockState.zoneId = 381
        mockState.mapName = "Auridon"
        mockState.playerX = 0.42
        mockState.playerY = 0.61

        -- Master crea una misión en preparación
        RPQuest.TargetCapture:CaptureFromReticle()
        RPQuest.QuestRepository:UpdateDraftFields({
            title = "Cacería del Capitán",
            description = "Elimina al capitán pirata.",
        })
        local masterQuest = RPQuest.QuestRepository:SaveDraft()
        AssertTrue(masterQuest ~= nil, "Master quest saved")

        -- No se puede generar código de entrega si no está completada
        local noCode = RPQuest.QuestRepository:ExportCompletionCode(masterQuest.id)
        AssertEqual(noCode, nil, "Cannot export completion code for incomplete quest")

        -- Master exporta RPQ3 y otro jugador la importa y completa
        local shareCode = RPQuest.QuestRepository:ExportQuestToCode(masterQuest.id)
        local playerQuest = RPQuest.QuestRepository:ImportQuestFromCode(shareCode)
        AssertTrue(playerQuest ~= nil, "Player imported quest")

        RPQuest.QuestRepository:SetActiveQuest(playerQuest.id)
        RPQuest.QuestRepository:RecordTargetEliminated("Capitán Pirata", {
            mapId = 32,
            zoneId = 381,
            x = 0.42,
            y = 0.61,
        })
        local updatedPlayerQuest = RPQuest.QuestRepository:GetQuestById(playerQuest.id)
        AssertTrue(updatedPlayerQuest.completed, "Player quest completed")

        -- Jugador genera código de entrega RPQC1
        local completionCode = RPQuest.QuestRepository:ExportCompletionCode(playerQuest.id)
        AssertTrue(type(completionCode) == "string" and completionCode:match("^RPQC1:") ~= nil, "Completion code has RPQC1 prefix")

        -- Master valida el código contra su misión en preparación
        local ok, result = RPQuest.QuestRepository:ValidateResultCode(masterQuest.id, completionCode)
        AssertTrue(ok, "Completion code validates against master prepared quest")
        AssertEqual(result.characterName, "Jugador", "Completion code preserves characterName")

        -- Rechaza un código RPQ3 como si fuera entrega
        local okQuestCode, errQuestCode = RPQuest.QuestRepository:ValidateResultCode(masterQuest.id, shareCode)
        AssertEqual(okQuestCode, false, "RPQ3 code rejected in delivery validator")
        AssertEqual(errQuestCode, "VALIDATE_ERR_NOT_COMPLETION_CODE", "Specific error returned for RPQ3 code")

        -- Rechaza un código corrupto
        local okBad, errBad = RPQuest.QuestRepository:ValidateResultCode(masterQuest.id, completionCode .. "X")
        AssertEqual(okBad, false, "Corrupted RPQC1 code rejected")
        AssertEqual(errBad, "VALIDATE_ERR_INVALID_CODE", "Specific error returned for corrupted code")

        -- Rechaza un código de otra misión distinta
        RPQuest.TargetCapture:CaptureFromReticle()
        RPQuest.QuestRepository:UpdateDraftFields({ title = "Otra Misión Distinta" })
        local otherMasterQuest = RPQuest.QuestRepository:SaveDraft()
        local okWrong, errWrong = RPQuest.QuestRepository:ValidateResultCode(otherMasterQuest.id, completionCode)
        AssertEqual(okWrong, false, "RPQC1 from another quest rejected")
        AssertEqual(errWrong, "VALIDATE_ERR_WRONG_QUEST", "Specific error returned for wrong quest")

        -- Flujo UI en JournalTab: sin cajas de código manual ni validación por pegado
        RPQuest.JournalTab:SelectQuest(playerQuest.id)
        AssertEqual(RPQuest.JournalTab.btnCompletionCode, nil, "On-demand completion code button removed")
        AssertEqual(RPQuest.JournalTab.btnActivate:IsHidden(), true, "Set Active button hidden for completed player quest")
        AssertEqual(RPQuest.JournalTab.deliveryBg, nil, "Manual deliveryBg removed")
        AssertEqual(RPQuest.JournalTab.validateBg, nil, "Manual validateBg removed")

        -- Keybind X Abandon presente en keybindStripDescriptor
        AssertTrue(RPQuest.JournalTab.abandonQuestDescriptor ~= nil, "Abandon quest keybind descriptor exists")
        AssertEqual(RPQuest.JournalTab.abandonQuestDescriptor.keybind, "UI_SHORTCUT_NEGATIVE", "Abandon uses UI_SHORTCUT_NEGATIVE")

        -- Sección con misión seleccionada/activa no puede colapsarse (comportamiento vanilla)
        RPQuest.JournalTab.collapsedSections.completed = false
        RPQuest.JournalTab:ToggleSection("completed")
        AssertEqual(RPQuest.JournalTab.collapsedSections.completed, false, "Section with selected quest cannot be collapsed")

        RPQuest.JournalTab:SelectQuest(masterQuest.id)
        AssertEqual(RPQuest.JournalTab.btnValidateDelivery, nil, "Manual validate delivery button removed")
        AssertEqual(RPQuest.JournalTab.btnSendDirect:IsHidden(), false, "Direct send button visible for prepared quest")
    end)

    RunTest("18. Issue 47: Deep optimization, overflow caps, deferred map pins and O(1) caches", function()
        RPQuest.QuestRepository:Initialize(RPQuest.QuestRepository:GetDefaults())
        RPQuest.JournalTab:Initialize()
        RPQuest.CombatTracker:Initialize()
        RPQuest.WorldMapArea:Initialize()

        local mockPinManager = ZO_WorldMap_GetPinManager()
        local refreshCalls = 0
        local origRefreshCustomPins = mockPinManager.RefreshCustomPins
        mockPinManager.RefreshCustomPins = function(self, ...)
            refreshCalls = refreshCalls + 1
            return origRefreshCustomPins(self, ...)
        end

        -- 1. RequestRefreshPins debe diferirse cuando el mapa está cerrado
        SCENE_MANAGER:Hide("worldMap")
        refreshCalls = 0
        RPQuest.WorldMapArea:RequestRefreshPins()
        AssertEqual(refreshCalls, 0, "RequestRefreshPins defers when world map is hidden")
        AssertEqual(RPQuest.WorldMapArea._pinsDirty, true, "Deferred refresh marks _pinsDirty")
        mockPinManager.RefreshCustomPins = origRefreshCustomPins

        -- 2. TargetCapture no debe llamar SetMapToPlayerLocation si DoesCurrentMapMatchMapForPlayerLocation() == true
        local setMapCalls = 0
        local origSetMap = SetMapToPlayerLocation
        local origDoesMatch = DoesCurrentMapMatchMapForPlayerLocation
        SetMapToPlayerLocation = function() setMapCalls = setMapCalls + 1; return SET_MAP_RESULT_CURRENT_MAP_UNCHANGED end
        DoesCurrentMapMatchMapForPlayerLocation = function() return true end
        RPQuest.TargetCapture:GetPlayerMapContext(false)
        AssertEqual(setMapCalls, 0, "Skips SetMapToPlayerLocation when map already matches player location")
        SetMapToPlayerLocation = origSetMap
        DoesCurrentMapMatchMapForPlayerLocation = origDoesMatch

        -- 3. UI vertical overflow cap (>4 objetivos) y códigos largos (>1024 chars)
        for i = 1, 10 do
            RPQuest.QuestRepository:SetDraftCapturedTarget({
                targetName = "Objetivo Largo Numero " .. i .. " de Prueba",
                mapId = 32,
                zoneId = 381,
                mapName = "Auridon",
                targetX = 0.5,
                targetY = 0.5,
            })
        end
        local longDesc = string.rep("Descripcion extensa para probar limites de Base64Url. ", 8)
        RPQuest.QuestRepository:UpdateDraftFields({ recommendHideMapAreas = false })
        local q = RPQuest.QuestRepository:SaveDraft("Mision Extensa", longDesc, nil, "Completada con exito!")
        AssertTrue(q ~= nil, "Saved quest with 10 targets")

        local code = RPQuest.QuestRepository:ExportQuestToCode(q.id)
        AssertTrue(type(code) == "string" and #code > 100 and code:sub(1, 5) == "RPQ3:", "Exported RPQ3 code generated cleanly")

        -- Verificar que detailObjText tiene altura acotada (4 líneas de objetivos + líneas de config Master <= 144px)
        RPQuest.JournalTab:SelectQuest(q.id)
        local _, objHeight = RPQuest.JournalTab.detailObjText:GetDimensions()
        AssertTrue(objHeight <= 144, "detailObjText height capped at <= 144px to prevent vertical overflow")

        -- Verificar invalidación de caché de ExportQuestToCode al editar
        RPQuest.QuestRepository:LoadQuestIntoDraft(q.id)
        local updated = RPQuest.QuestRepository:SaveDraft("Mision Extensa Editada", longDesc, nil, "Nuevo mensaje")
        local updatedCode = RPQuest.QuestRepository:ExportQuestToCode(updated.id)
        AssertTrue(updatedCode ~= code, "Share code cache invalidated on quest update")

        -- 4. Ring buffer O(1) en CombatTracker:MarkUnitKilled (>32 unidades)
        for u = 1, 40 do
            RPQuest.CombatTracker:MarkUnitKilled(u)
        end
        AssertEqual(RPQuest.CombatTracker._recentKilledSet[1], nil, "Oldest unit evicted from 32-slot ring buffer")
        AssertEqual(RPQuest.CombatTracker._recentKilledSet[40], true, "Newest unit retained in ring buffer")
    end)

    RunTest("Optimizations: completion code cache, discovery-only FindPendingTarget, ShareCodec escape, keybind string", function()
        RPQuest.QuestRepository:Initialize(RPQuest.QuestRepository:GetDefaults())

        -- 1. Legacy discovery capture keybind is completely removed
        RPQuest.Locale._stringsRegistered = false
        RPQuest.Locale:Initialize("en")
        AssertEqual(_G["SI_BINDING_NAME_RPQUEST_CAPTURE_DISCOVERY"], nil, "SI_BINDING_NAME_RPQUEST_CAPTURE_DISCOVERY is not registered")
        AssertEqual(RPQuest.OnCaptureDiscoveryKeybind, nil, "OnCaptureDiscoveryKeybind is removed")

        -- 2. ShareCodec escaping roundtrip with special delimiters
        local specialQuest = {
            title = "100% Test | ; ~",
            description = "Line 1\nLine 2 %7C ~ ;",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.5,
            targetY = 0.5,
            areaCenterX = 0.5,
            areaCenterY = 0.5,
            areaRadius = 0.075,
            targets = { { name = "Bandit | Boss", requiredCount = 2 } },
        }
        local encoded = RPQuest.ShareCodec:EncodeQuest(specialQuest)
        local decoded = RPQuest.ShareCodec:DecodeQuest(encoded)
        AssertTrue(decoded ~= nil, "Special characters quest decoded")
        AssertEqual(decoded.title, specialQuest.title, "Special delimiter characters preserved in title")
        AssertEqual(decoded.description, specialQuest.description, "Newline and percent sequences preserved in description")
        AssertEqual(decoded.targets[1].name, "Bandit | Boss", "Pipe preserved in target name")

        -- 3. Discovery-only active quest skips target normalization in FindPendingTarget
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:AddDraftDiscoveryPoint({
            zoneId = 381,
            worldX = 1000,
            worldY = 0,
            worldZ = 2000,
            radius = 1000,
            message = "Clue",
        })
        local discQuest = RPQuest.QuestRepository:SaveDraft("Discovery Only", "Desc")
        RPQuest.QuestRepository:SetActiveQuest(discQuest.id)
        local matchedQ, matchedT = RPQuest.QuestRepository:FindPendingTarget("Random Mob")
        AssertEqual(matchedQ, nil, "FindPendingTarget returns nil for discovery-only quest")
        AssertEqual(matchedT, nil, "FindPendingTarget returns nil target for discovery-only quest")

        -- 4. ExportCompletionCode caches result and invalidates on ResetQuest
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Bandido",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.50,
            targetY = 0.50,
        })
        local q = RPQuest.QuestRepository:SaveDraft("Cache Test", "Desc")
        local code = RPQuest.QuestRepository:ExportQuestToCode(q.id)
        local imp = RPQuest.QuestRepository:ImportQuestFromCode(code)
        RPQuest.QuestRepository:RecordTargetEliminated("Bandido", { mapId = 32, zoneId = 381, x = imp.areaCenterX, y = imp.areaCenterY })
        AssertEqual(imp.completed, true, "Imported quest completed")
        local c1 = RPQuest.QuestRepository:ExportCompletionCode(imp.id)
        local c2 = RPQuest.QuestRepository:ExportCompletionCode(imp.id)
        AssertTrue(c1 ~= nil and c1 == c2, "ExportCompletionCode returns cached code")
        RPQuest.QuestRepository:ResetQuest(imp.id)
        local cAfterReset, errAfterReset = RPQuest.QuestRepository:ExportCompletionCode(imp.id)
        AssertEqual(cAfterReset, nil, "ExportCompletionCode cache invalidated on ResetQuest")
        AssertEqual(errAfterReset, "Quest is not completed", "ResetQuest marks quest incomplete")
    end)

    RunTest("QuestRepository:NormalizeAccountName and MailTransport:NormalizeDisplayName share identical edge-case behavior", function()
        local cases = {
            { input = nil, expected = "" },
            { input = 123, expected = "" },
            { input = {}, expected = "" },
            { input = "", expected = "" },
            { input = "   \t\n  ", expected = "" },
            { input = "PlayerOne", expected = "@PlayerOne" },
            { input = "  PlayerOne  ", expected = "@PlayerOne" },
            { input = "@PlayerOne", expected = "@PlayerOne" },
            { input = "  @PlayerOne  ", expected = "@PlayerOne" },
        }

        for _, c in ipairs(cases) do
            local label = tostring(c.input)
            local repoRes = RPQuest.QuestRepository:NormalizeAccountName(c.input)
            local mailRes = RPQuest.MailTransport:NormalizeDisplayName(c.input)
            AssertEqual(repoRes, c.expected, "QuestRepository:NormalizeAccountName(" .. label .. ")")
            AssertEqual(mailRes, c.expected, "MailTransport:NormalizeDisplayName(" .. label .. ")")
        end
    end)

    RunTest("QuestRepository:MigrateCharacterSavedVars migrates multiple characters non-destructively and resolves ID collisions", function()
        local rawRoot = {
            Default = {
                ["@TestPlayer"] = {
                    ["char-A"] = {
                        nextId = 3,
                        activeQuestId = 2,
                        quests = {
                            { id = 1, title = "Char A Prepared", description = "Desc A1", role = "prepared", targets = {}, discoveries = {} },
                            { id = 2, title = "Char A Received", description = "Desc A2", role = "received", targets = {}, discoveries = {} },
                        },
                        ingestedMailIds = { ["mail-100"] = true },
                        settings = { autoDeleteMail = false, autoAcceptMail = true, autoSendCompletionMail = false },
                        draft = { title = "Draft A", description = "In progress", targets = {}, discoveries = {}, dialogues = {}, editingQuestId = 1 },
                    },
                    ["char-B"] = {
                        nextId = 2,
                        activeQuestId = 1,
                        quests = {
                            { id = 1, title = "Char B Quest", description = "Desc B1", role = "prepared", targets = {}, discoveries = {} },
                        },
                        ingestedMailIds = { ["mail-200"] = true },
                        settings = { autoDeleteMail = true, autoAcceptMail = false, autoSendCompletionMail = true },
                    },
                },
            },
        }

        local sv = RPQuest.QuestRepository:GetDefaults()
        local migrated = RPQuest.QuestRepository:MigrateCharacterSavedVars(rawRoot, "@TestPlayer", sv, "char-A")
        AssertEqual(migrated, 3, "Migrated all 3 quests across both characters")
        AssertEqual(#sv.quests, 3, "Account-wide quests table has 3 quests")
        AssertEqual(sv.nextId, 4, "nextId advanced past resolved collision ID")
        AssertEqual(sv.activeQuestId, 2, "Current character activeQuestId preserved")
        AssertTrue(sv.ingestedMailIds["mail-100"] == true, "Char A ingestedMailIds merged")
        AssertTrue(sv.ingestedMailIds["mail-200"] == true, "Char B ingestedMailIds merged")
        AssertEqual(sv.settings.autoDeleteMail, false, "Current character settings preserved")
        AssertEqual(sv.settings.autoAcceptMail, true, "Current character autoAcceptMail preserved")
        AssertEqual(sv.draft.title, "Draft A", "Current character draft preserved")
        AssertEqual(sv.draft.editingQuestId, 1, "Draft editingQuestId preserved")

        -- Verify IDs are unique
        local seenIds = {}
        for _, q in ipairs(sv.quests) do
            AssertTrue(not seenIds[q.id], "Quest ID " .. tostring(q.id) .. " is unique")
            seenIds[q.id] = true
        end

        -- Verify original character tables are untouched (non-destructive)
        AssertEqual(#rawRoot.Default["@TestPlayer"]["char-A"].quests, 2, "Original char-A quests preserved")
        AssertEqual(#rawRoot.Default["@TestPlayer"]["char-B"].quests, 1, "Original char-B quests preserved")

        -- Verify idempotency: running migration again does not duplicate
        local secondRun = RPQuest.QuestRepository:MigrateCharacterSavedVars(rawRoot, "@TestPlayer", sv, "char-B")
        AssertEqual(secondRun, 0, "Second migration run is idempotent (0 quests added)")
        AssertEqual(#sv.quests, 3, "Quest count remains 3 after second migration")
    end)

    RunTest("Account-wide SavedVars allows Character B to find and update quest prepared on Character A", function()
        local rawRoot = {
            Default = {
                ["@TestPlayer"] = {
                    ["char-A"] = {
                        nextId = 2,
                        quests = {
                            {
                                id = 1,
                                title = "Cross-Char Contract",
                                description = "Sent from Char A",
                                role = "prepared",
                                targets = { { name = "Bandit", requiredCount = 1, currentCount = 0 } },
                                discoveries = {},
                                deliveries = {},
                            },
                        },
                    },
                },
            },
        }

        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:MigrateCharacterSavedVars(rawRoot, "@TestPlayer", sv, "char-B")
        RPQuest.QuestRepository:Initialize(sv)

        local found = RPQuest.QuestRepository:GetQuestById(1)
        AssertTrue(found ~= nil, "Character B finds quest prepared on Character A")
        AssertEqual(found.title, "Cross-Char Contract", "Quest title matches")

        local delivery = RPQuest.QuestRepository:RecordMailDelivery(1, "@Recipient", {
            characterName = "RecipientAlt",
            completedAt = 1234567890,
            completed = true,
            wasDetected = false,
        })
        AssertTrue(delivery ~= nil, "Character B records completion delivery on quest prepared by Character A")
        AssertEqual(#found.deliveries, 1, "Delivery recorded on shared quest")
    end)

    RunTest("Optional objectives: manual completion when mandatory satisfied, auto-complete when all satisfied", function()
        RPQuest.QuestRepository:Initialize(RPQuest.QuestRepository:GetDefaults())
        RPQuest.QuestRepository:SetDraftCapturedTarget({ targetName = "Boss", mapId = 1, zoneId = 2, mapName = "Zone", targetX = 0.5, targetY = 0.5 })
        RPQuest.QuestRepository:SetDraftCapturedTarget({ targetName = "BonusGuard", mapId = 1, zoneId = 2, mapName = "Zone", targetX = 0.5, targetY = 0.5 })
        local draft = RPQuest.QuestRepository:GetDraft()
        AssertEqual(draft.targets[1].optional, false, "Captured target defaults to optional=false")
        RPQuest.QuestRepository:UpdateDraftTarget(2, { optional = true })

        local prepared = RPQuest.QuestRepository:SaveDraft("Optional Test", "Desc")
        local code = RPQuest.QuestRepository:ExportQuestToCode(prepared.id)
        local imported = RPQuest.QuestRepository:ImportQuestFromCode(code, "@Master")
        RPQuest.QuestRepository:SetActiveQuest(imported.id)

        AssertEqual(RPQuest.QuestRepository:CanManuallyCompleteQuest(imported), false, "Cannot manually complete before mandatory target")

        -- Eliminate mandatory target only
        local ok, q1, justCompleted = RPQuest.QuestRepository:RecordTargetEliminated("Boss")
        AssertEqual(ok, true, "Mandatory target recorded")
        AssertEqual(justCompleted, false, "Quest does not auto-complete while optional target remains")
        AssertEqual(q1.completed, false, "Quest still incomplete")
        AssertEqual(RPQuest.QuestRepository:CanManuallyCompleteQuest(q1), true, "Can manually complete once mandatory target is done")

        -- Complete manually
        local completedEventFired = false
        RPQuest.QuestRepository:RegisterListener(function(ev)
            if ev == "QUEST_COMPLETED" then
                completedEventFired = true
            end
        end)
        local compOk, compQ = RPQuest.QuestRepository:CompleteQuest(q1.id)
        AssertEqual(compOk, true, "CompleteQuest succeeds")
        AssertEqual(compQ.completed, true, "Quest marked completed")
        AssertEqual(completedEventFired, true, "QUEST_COMPLETED event fired on manual completion")
        AssertEqual(RPQuest.QuestRepository:GetActiveQuest(), nil, "Active quest cleared after manual completion")

        -- Reset and complete both mandatory and optional -> auto-completes seamlessly
        RPQuest.QuestRepository:ResetQuest(compQ.id)
        RPQuest.QuestRepository:SetActiveQuest(compQ.id)
        RPQuest.QuestRepository:RecordTargetEliminated("Boss")
        local ok2, q2, justCompleted2 = RPQuest.QuestRepository:RecordTargetEliminated("BonusGuard")
        AssertEqual(ok2, true, "Optional target recorded")
        AssertEqual(justCompleted2, true, "Quest auto-completes when all targets including optional are done")
        AssertEqual(q2.completed, true, "Quest completed")
    end)

    RunTest("22. Issue 158: Exclusive accordion in JournalTab quest list", function()
        local roles = RPQuest.Constants.QUEST_ROLE
        local statuses = RPQuest.Constants.QUEST_STATUS
        RPQuest.QuestRepository:Initialize({
            activeQuestId = 1,
            quests = {
                { id = 1, title = "Active Mission", description = "", role = roles.RECEIVED, completed = false },
                { id = 2, title = "Pending Offer", description = "", role = roles.RECEIVED, status = statuses.OFFERED, completed = false },
                { id = 3, title = "Completed Mission", description = "", role = roles.RECEIVED, completed = true },
                { id = 4, title = "Prepared Mission", description = "", role = roles.PREPARED, completed = false },
                { id = 5, title = "Sent Mission", description = "", role = roles.PREPARED, sentTo = "@Recipient", completed = false },
            },
        })
        RPQuest.JournalTab:Initialize()
        RPQuest.JournalTab.collapsedSections = { pending = true, missions = false, completed = true, preparing = true, sent = true }
        RPQuest.JournalTab:SelectQuest(1)

        local function hasRowForQuest(questId)
            for _, b in pairs(RPQuest.JournalTab.rowBindings) do
                if b.questId == questId then return true end
            end
            return false
        end

        AssertEqual(RPQuest.JournalTab.collapsedSections.missions, false, "Missions starts expanded")
        AssertEqual(RPQuest.JournalTab.collapsedSections.pending, true, "Pending starts collapsed")
        AssertEqual(RPQuest.JournalTab.collapsedSections.completed, true, "Completed starts collapsed")
        AssertEqual(RPQuest.JournalTab.collapsedSections.preparing, true, "Preparing starts collapsed")
        AssertEqual(RPQuest.JournalTab.collapsedSections.sent, true, "Sent starts collapsed")
        AssertEqual(hasRowForQuest(1), true, "Active mission row is visible initially")
        AssertEqual(hasRowForQuest(2), false, "Pending quest row is hidden initially")

        -- Clicking Pending while an active/selected quest is in Missions collapses Missions and expands Pending
        RPQuest.JournalTab:ToggleSection("pending")
        AssertEqual(RPQuest.JournalTab.collapsedSections.pending, false, "Pending expands on click")
        AssertEqual(RPQuest.JournalTab.collapsedSections.missions, true, "Missions collapses when Pending expands")
        AssertEqual(RPQuest.JournalTab.collapsedSections.completed, true, "Completed remains collapsed")
        AssertEqual(RPQuest.JournalTab.collapsedSections.preparing, true, "Preparing remains collapsed")
        AssertEqual(RPQuest.JournalTab.collapsedSections.sent, true, "Sent remains collapsed")
        AssertEqual(hasRowForQuest(2), true, "Pending quest row is visible after expanding Pending")
        AssertEqual(hasRowForQuest(1), false, "Missions quest row is hidden even though it is active/selected")

        -- Expanding Preparing collapses Pending and only shows unsent drafts
        RPQuest.JournalTab:ToggleSection("preparing")
        AssertEqual(RPQuest.JournalTab.collapsedSections.preparing, false, "Preparing expands on click")
        AssertEqual(RPQuest.JournalTab.collapsedSections.pending, true, "Pending collapses when Preparing expands")
        AssertEqual(hasRowForQuest(4), true, "Prepared draft row is visible")
        AssertEqual(hasRowForQuest(5), false, "Sent quest row is NOT in Preparing")
        AssertEqual(hasRowForQuest(2), false, "Pending quest row is hidden")

        -- Expanding Sent collapses Preparing and shows sent quests
        RPQuest.JournalTab:ToggleSection("sent")
        AssertEqual(RPQuest.JournalTab.collapsedSections.sent, false, "Sent expands on click")
        AssertEqual(RPQuest.JournalTab.collapsedSections.preparing, true, "Preparing collapses when Sent expands")
        AssertEqual(hasRowForQuest(5), true, "Sent quest row is visible in Sent")
        AssertEqual(hasRowForQuest(4), false, "Prepared draft row is hidden")

        -- Expanding Completed collapses Sent
        RPQuest.JournalTab:ToggleSection("completed")
        AssertEqual(RPQuest.JournalTab.collapsedSections.completed, false, "Completed expands on click")
        AssertEqual(RPQuest.JournalTab.collapsedSections.sent, true, "Sent collapses when Completed expands")
        AssertEqual(hasRowForQuest(3), true, "Completed quest row is visible")
        AssertEqual(hasRowForQuest(5), false, "Sent quest row is hidden")

        -- Expanding Missions again collapses Completed
        RPQuest.JournalTab:ToggleSection("missions")
        AssertEqual(RPQuest.JournalTab.collapsedSections.missions, false, "Missions expands on click")
        AssertEqual(RPQuest.JournalTab.collapsedSections.completed, true, "Completed collapses when Missions expands")
        AssertEqual(hasRowForQuest(1), true, "Active mission row is visible again")
        AssertEqual(hasRowForQuest(3), false, "Completed quest row is hidden")

        -- Clicking an already-expanded section keeps it open (never leaves all sections collapsed)
        RPQuest.JournalTab:ToggleSection("missions")
        AssertEqual(RPQuest.JournalTab.collapsedSections.missions, false, "Clicking already-open Missions keeps it expanded")
        AssertEqual(hasRowForQuest(1), true, "Active mission row remains visible")
    end)

    RunTest("QuestRepository:DuplicateQuest copies Preparing and Sent into Preparing and rejects Received", function()
        local repo = RPQuest.QuestRepository
        repo:Initialize(repo:GetDefaults())

        -- Create a PREPARING quest with targets, discoveries, dialogues, and metadata
        repo:SetDraftCapturedTarget({
            targetName = "Bandit Cutthroat",
            mapId = 101,
            zoneId = 202,
            mapName = "Glenumbra",
            targetX = 0.45,
            targetY = 0.55,
            worldX = 1000,
            worldZ = 2000,
        })
        repo:AddDraftDiscoveryPoint({
            zoneId = 202,
            worldX = 1100,
            worldY = 100,
            worldZ = 2100,
            mapId = 101,
            x = 0.46,
            y = 0.56,
            radius = 1500,
            message = "Hidden note",
        })
        repo:AddDraftDialogue("Innkeeper", 202, "Behind the mill.", "Look near the river.")
        local prepQuest = repo:SaveDraft("Contract One", "Desc One", 0.075, "Well done", true, "@TargetUser", "HeroChar")
        AssertTrue(prepQuest ~= nil, "Prepared quest created")
        -- Simulate runtime test progress on the prepared quest
        prepQuest.targets[1].currentCount = 1
        prepQuest.discoveries[1].discovered = true
        prepQuest.wasDetected = true
        prepQuest.completed = true

        local copyFromPrep = repo:DuplicateQuest(prepQuest.id)
        AssertTrue(copyFromPrep ~= nil, "Copy from PREPARING succeeds")
        AssertEqual(copyFromPrep.id ~= prepQuest.id, true, "Copy has a new unique quest ID")
        AssertEqual(copyFromPrep.role, RPQuest.Constants.QUEST_ROLE.PREPARED, "Copy has PREPARED role")
        AssertEqual(repo:GetQuestLifecycle(copyFromPrep), "draft", "Copy from PREPARING is in draft/Preparing")
        AssertEqual(repo:GetQuestResolution(copyFromPrep), nil, "Copy from PREPARING has nil resolution")
        AssertEqual(copyFromPrep.title, "Contract One", "Title preserved")
        AssertEqual(copyFromPrep.description, "Desc One", "Description preserved")
        AssertEqual(copyFromPrep.completionMessage, "Well done", "Completion message preserved")
        AssertEqual(copyFromPrep.stealthMode, "optional", "Stealth mode preserved")
        AssertEqual(copyFromPrep.recipientAccount, "@TargetUser", "Recipient account preserved")
        AssertEqual(copyFromPrep.recipientCharacterName, "HeroChar", "Recipient character preserved")
        AssertEqual(#copyFromPrep.targets, 1, "Targets cloned")
        AssertEqual(copyFromPrep.targets[1].currentCount, 0, "Target currentCount reset to 0")
        AssertEqual(#copyFromPrep.discoveries, 1, "Discoveries cloned")
        AssertEqual(copyFromPrep.discoveries[1].discovered, false, "Discovery state reset")
        AssertEqual(#copyFromPrep.dialogues, 1, "Dialogues cloned")
        AssertEqual(copyFromPrep.dialogues[1].npcName, "Innkeeper", "Dialogue NPC preserved")
        AssertEqual(copyFromPrep.completed, false, "Completed flag reset")
        AssertEqual(copyFromPrep.wasDetected, false, "Detected flag reset")

        -- Mutating copy does not mutate source
        copyFromPrep.targets[1].name = "Mutated"
        AssertEqual(prepQuest.targets[1].name, "Bandit Cutthroat", "Source target not mutated")

        -- Mark original as SENT with delivery history and copy it
        repo:MarkPreparedQuestSent(prepQuest.id, "@TargetUser")
        repo:RecordMailDelivery(prepQuest.id, "@TargetUser", { status = "completed", characterName = "HeroChar" })
        AssertEqual(repo:GetQuestLifecycle(prepQuest), "sent", "Original is in SENT lifecycle")
        AssertEqual(repo:GetQuestResolution(prepQuest), "completed", "Original has completed resolution")

        local copyFromSent = repo:DuplicateQuest(prepQuest.id)
        AssertTrue(copyFromSent ~= nil, "Copy from SENT succeeds")
        AssertEqual(copyFromSent.id ~= prepQuest.id, true, "Sent copy has new ID")
        AssertEqual(repo:GetQuestLifecycle(copyFromSent), "draft", "Copy from SENT starts in Preparing")
        AssertEqual(repo:GetQuestResolution(copyFromSent), nil, "Copy from SENT has nil resolution")
        AssertTrue(copyFromSent.sentTo == nil, "sentTo cleared")
        AssertTrue(copyFromSent.sentAt == nil, "sentAt cleared")
        AssertTrue(copyFromSent.lastResult == nil, "lastResult cleared")
        AssertEqual(#copyFromSent.deliveries, 0, "deliveries cleared")
        AssertEqual(prepQuest.sentTo, "@TargetUser", "Source SENT quest remains unchanged")

        -- Received quest cannot be copied
        local recQuest = repo:BuildQuestRecord(99, "Received Quest", "Desc", {
            { name = "Wolf", currentCount = 0, requiredCount = 1 },
        }, { mapId = 1, zoneId = 2 }, RPQuest.Constants.QUEST_ROLE.RECEIVED)
        table.insert(repo.savedVars.quests, recQuest)
        repo._questById[recQuest.id] = recQuest

        local countBefore = #repo:GetAllQuests()
        local deniedCopy, denyErr = repo:DuplicateQuest(recQuest.id)
        AssertTrue(deniedCopy == nil, "Received quest cannot be copied")
        AssertEqual(denyErr, RPQuest.Locale:Get("ERR_CANNOT_COPY_RECEIVED"), "Expected error for received quest")
        AssertEqual(#repo:GetAllQuests(), countBefore, "No quest added when copy is rejected")
    end)

    RunTest("Quest schema versioning, sequential migration pipeline, and breaking fallback (ADR-0013)", function()
        local repo = RPQuest.QuestRepository
        local mig = RPQuest.QuestMigration

        -- 1. New quests carry CURRENT_VERSION
        repo:Initialize(nil)
        local fresh = repo:BuildQuestRecord(1, "Fresh", "Desc", {
            { name = "Imp", currentCount = 0, requiredCount = 1 },
        }, { mapId = 1, zoneId = 2 }, RPQuest.Constants.QUEST_ROLE.PREPARED)
        AssertEqual(fresh.schemaVersion, RPQuest.Constants.QUEST_SCHEMA.CURRENT_VERSION, "New quest has CURRENT_VERSION")

        -- 2. Sequential migration v1 -> v2 -> v3 with deterministic transforms
        local legacyQuest = {
            id = 5,
            title = "Legacy",
            description = "Old format",
            role = RPQuest.Constants.QUEST_ROLE.RECEIVED,
            targets = { { name = "Wolf", currentCount = 0, requiredCount = 1 } },
            legacyFlag = true,
        }
        local migrated, didMigrate = mig:MigrateQuestRecord(legacyQuest, {
            targetVersion = 3,
            migrators = {
                [1] = function(q)
                    q.step1Applied = (q.legacyFlag == true)
                    q.legacyFlag = nil
                    return true
                end,
                [2] = function(q)
                    q.step2Applied = true
                    return true
                end,
            },
        })
        AssertTrue(didMigrate, "Legacy quest was migrated")
        AssertEqual(migrated.schemaVersion, 3, "Quest reached target schemaVersion 3")
        AssertEqual(migrated.step1Applied, true, "v1->v2 migrator ran")
        AssertEqual(migrated.step2Applied, true, "v2->v3 migrator ran")
        AssertTrue(migrated.legacyFlag == nil, "Legacy field cleaned up")
        AssertTrue(migrated.needsMigration == nil, "Clean migration does not set needsMigration")

        -- 3. Breaking migration marks needsMigration, clears activeQuestId on Initialize, and allows MigratePreparedQuest
        local origMigrators = mig.SCHEMA_MIGRATORS
        local origVersion = RPQuest.Constants.QUEST_SCHEMA.CURRENT_VERSION
        RPQuest.Constants.QUEST_SCHEMA.CURRENT_VERSION = 2
        mig.SCHEMA_MIGRATORS = {
            [1] = function(q)
                if q.role == RPQuest.Constants.QUEST_ROLE.PREPARED and q.title == "Broken Prep" then
                    return false, "Missing required v2 field"
                end
                return true
            end,
        }

        local sv = {
            nextId = 3,
            activeQuestId = 1,
            quests = {
                {
                    id = 1,
                    schemaVersion = 1,
                    title = "Broken Prep",
                    description = "Needs manual update",
                    role = RPQuest.Constants.QUEST_ROLE.PREPARED,
                    targets = { { name = "Bandit", currentCount = 0, requiredCount = 1 } },
                },
                {
                    id = 2,
                    schemaVersion = 1,
                    title = "Auto Received",
                    description = "Migrates cleanly",
                    role = RPQuest.Constants.QUEST_ROLE.RECEIVED,
                    targets = { { name = "Wolf", currentCount = 0, requiredCount = 1 } },
                },
            },
            ingestedMailIds = {},
        }
        repo:Initialize(sv)

        local broken = repo:GetQuestById(1)
        local autoRec = repo:GetQuestById(2)
        AssertEqual(broken.needsMigration, true, "Breaking PREPARED quest flagged with needsMigration")
        AssertEqual(broken.migrationReason, "Missing required v2 field", "Migration reason preserved")
        AssertEqual(autoRec.schemaVersion, 2, "Auto-migratable quest upgraded on Initialize")
        AssertTrue(repo:GetActiveQuest() == nil, "activeQuestId cleared when active quest needsMigration")
        AssertEqual(repo:SetActiveQuest(1), false, "Cannot activate quest flagged with needsMigration")

        local draftLoaded, draftErr = repo:LoadQuestIntoDraft(1)
        AssertTrue(draftLoaded == nil, "Cannot directly edit quest flagged with needsMigration")
        AssertEqual(draftErr, RPQuest.Locale:Get("ERR_QUEST_NEEDS_MIGRATION"), "Returns migration error on edit")

        local migratedCopy = repo:MigratePreparedQuest(1)
        AssertTrue(migratedCopy ~= nil, "MigratePreparedQuest creates updated copy")
        AssertEqual(migratedCopy.schemaVersion, 2, "Migrated copy has CURRENT_VERSION")
        AssertTrue(migratedCopy.needsMigration == nil, "Migrated copy clears needsMigration")
        AssertEqual(migratedCopy.title, "Broken Prep", "Migrated copy preserves title")

        -- 4. ShareCodec:DecodeQuest runs migration at boundary
        local encoded = RPQuest.ShareCodec:EncodeQuest(autoRec)
        AssertTrue(type(encoded) == "string", "Quest encoded")
        -- Simulate v1->v2 transform when decoding
        mig.SCHEMA_MIGRATORS = {
            [1] = function(q)
                q.boundaryMigrated = true
                return true
            end,
        }
        local decoded = RPQuest.ShareCodec:DecodeQuest(encoded)
        AssertTrue(decoded ~= nil, "Quest decoded")
        AssertEqual(decoded.schemaVersion, 2, "Decoded quest migrated to CURRENT_VERSION")
        AssertEqual(decoded.boundaryMigrated, true, "Boundary migrator ran during DecodeQuest")

        -- Restore global constants/migrators
        RPQuest.Constants.QUEST_SCHEMA.CURRENT_VERSION = origVersion
        mig.SCHEMA_MIGRATORS = origMigrators
    end)

    RunTest("v1 -> v2 migration converts requireUndetected quests and saved drafts to stealthMode", function()
        local repo = RPQuest.QuestRepository
        local sv = {
            nextId = 3,
            quests = {
                {
                    id = 1,
                    schemaVersion = 1,
                    role = "prepared",
                    title = "Legacy Stealth",
                    description = "D",
                    requireUndetected = true,
                    targets = { { name = "Guard", requiredCount = 1, currentCount = 0 } },
                },
                {
                    id = 2,
                    schemaVersion = 1,
                    role = "received",
                    title = "Legacy Normal",
                    description = "D",
                    requireUndetected = false,
                    targets = { { name = "Bandit", requiredCount = 1, currentCount = 0 } },
                },
            },
            draft = {
                title = "Old Draft",
                requireUndetected = true,
                targets = {},
                discoveries = {},
                dialogues = {},
            },
        }
        repo:Initialize(sv)

        local q1 = repo:GetQuestById(1)
        local q2 = repo:GetQuestById(2)
        AssertEqual(q1.schemaVersion, 6, "Quest 1 upgraded to current schema v6")
        AssertEqual(q1.stealthMode, "optional", "requireUndetected = true migrated to stealthMode = optional")
        AssertEqual(q1.requireUndetected, nil, "Legacy requireUndetected cleared on q1")
        AssertEqual(q2.schemaVersion, 6, "Quest 2 upgraded to current schema v6")
        AssertEqual(q2.stealthMode, "disabled", "requireUndetected = false migrated to stealthMode = disabled")
        AssertEqual(q2.requireUndetected, nil, "Legacy requireUndetected cleared on q2")

        local draft = repo:GetDraft()
        AssertEqual(draft.stealthMode, "optional", "Legacy draft requireUndetected = true normalized to stealthMode = optional")
        AssertEqual(draft.requireUndetected, nil, "Legacy draft requireUndetected cleared")
    end)

    RunTest("Issue #270 & #344: SaveDraft, activate, export, and send work for dialogue-only, pure free-form, and discovery-only quests", function()
        mockState.language = "en"
        RPQuest.Locale:Initialize("en")
        local repo = RPQuest.QuestRepository
        repo:Initialize({})
        RPQuest.MailTransport:Initialize()

        AssertEqual(repo:HasPlayableObjectives(nil), false, "HasPlayableObjectives false for nil")
        AssertEqual(repo:HasPlayableObjectives("invalid"), false, "HasPlayableObjectives false for non-table")

        -- 1. SaveDraft with 0 targets and 0 discoveries (dialogue-only) preserves all fields
        repo:AddDraftDialogue("Informant", 381, "Bring the seal.", "Meet at the pier")
        local saved, saveErr = repo:SaveDraft(
            "Investigation Draft",
            "Follow the clues at the harbor.",
            nil,
            "Case closed!",
            nil,
            "@Investigator",
            "Detective"
        )
        AssertTrue(saved ~= nil, "SaveDraft succeeds without targets or discoveries: " .. tostring(saveErr))
        AssertEqual(saved.title, "Investigation Draft", "Title preserved")
        AssertEqual(saved.description, "Follow the clues at the harbor.", "Description preserved")
        AssertEqual(saved.completionMessage, "Case closed!", "Completion message preserved")
        AssertEqual(saved.recipientAccount, "@Investigator", "Recipient account preserved")
        AssertEqual(saved.recipientCharacterName, "Detective", "Recipient character preserved")
        AssertEqual(#saved.dialogues, 1, "Dialogues preserved")
        AssertEqual(saved.completed, false, "Objective-less draft stays completed=false")
        AssertEqual(repo:HasPlayableObjectives(saved), true, "Dialogue-only quest passes HasPlayableObjectives")

        -- 2. Dialogue-only and pure free-form quests can be exported, activated, reset, and sent
        local code, exportErr = repo:ExportQuestToCode(saved.id)
        AssertTrue(type(code) == "string" and code:sub(1, 5) == "RPQ3:", "ExportQuestToCode succeeds for dialogue-only quest: " .. tostring(exportErr))

        local actOk, actErr = repo:SetActiveQuest(saved.id)
        AssertEqual(actOk, true, "SetActiveQuest accepts dialogue-only quest: " .. tostring(actErr))

        local resetOk, resetErr = repo:ResetQuest(saved.id)
        AssertEqual(resetOk, true, "ResetQuest(activate=true) accepts dialogue-only quest: " .. tostring(resetErr))

        local sendOk, sendErr = RPQuest.MailTransport:SendQuestToRecipients(saved, "@Investigator", "Roleplay intro")
        AssertEqual(sendOk, true, "SendQuestToRecipients accepts dialogue-only quest: " .. tostring(sendErr))
        RPQuest.MailTransport:Initialize()

        -- 3. Adding a discovery point (still 0 NPC targets) enables test, export, send, and completion
        repo:LoadQuestIntoDraft(saved.id)
        repo:AddDraftDiscoveryPoint({
            zoneId = 381,
            worldX = 1200,
            worldY = 0,
            worldZ = 2400,
            radius = 1000,
            message = "Found the hidden ledger",
        })
        local discSaved = repo:SaveDraft()
        AssertTrue(discSaved ~= nil and #discSaved.discoveries == 1 and #discSaved.targets == 0, "Discovery-only quest saved with 0 NPC targets")

        local discActOk = repo:ResetQuest(discSaved.id)
        AssertEqual(discActOk, true, "Discovery-only quest can be activated for testing")
        local discCode, discExportErr = repo:ExportQuestToCode(discSaved.id)
        AssertTrue(type(discCode) == "string" and string.sub(discCode, 1, 5) == "RPQ3:", "Discovery-only quest exports cleanly: " .. tostring(discExportErr))

        local imported = repo:ImportQuestFromCode(discCode)
        AssertTrue(imported ~= nil and #imported.discoveries == 1 and #imported.targets == 0, "Discovery-only quest imports cleanly")
        repo:AcceptOfferedQuest(imported.id)
        local found = repo:MarkDiscoveryTriggered(imported.id, 1)
        AssertEqual(found, true, "Discovery point recorded")
        AssertEqual(imported.completed, true, "Discovery-only quest completes without any NPC target")
    end)

    RunTest("Issue #277: v2 -> v3 migration, RemoveDraftTarget, and local map visibility defaults", function()
        local repo = RPQuest.QuestRepository
        local defaults = repo:GetDefaults()
        AssertEqual(defaults.draft.recommendHideMapAreas, true, "New draft defaults recommendHideMapAreas = true")
        AssertEqual(defaults.settings.showSearchAreas, false, "Local setting showSearchAreas defaults to false")
        AssertEqual(defaults.settings.showLocationAreas, false, "Local setting showLocationAreas defaults to false")
        AssertEqual(defaults.settings.showDiscoveryAreas, false, "Local setting showDiscoveryAreas defaults to false")
        AssertEqual(repo:HasQuestDiscoveryPoints({ discoveries = {} }), false, "HasQuestDiscoveryPoints false for empty discoveries")
        AssertEqual(repo:HasQuestDiscoveryPoints({ discoveries = { { message = "x" } } }), true, "HasQuestDiscoveryPoints true when discoveries exist")

        local sv = {
            nextId = 10,
            quests = {
                {
                    id = 1,
                    schemaVersion = 2,
                    role = RPQuest.Constants.QUEST_ROLE.PREPARED,
                    title = "Legacy v2 Hidden",
                    description = "Desc",
                    mapId = 32,
                    zoneId = 381,
                    areaCenterX = 0.41,
                    areaCenterY = 0.62,
                    areaRadius = 0.125,
                    hideMapArea = true,
                    targets = {
                        { name = "Target A", requiredCount = 1, currentCount = 0 },
                        { name = "Target B", requiredCount = 2, currentCount = 1 },
                    },
                },
                {
                    id = 2,
                    schemaVersion = 2,
                    role = RPQuest.Constants.QUEST_ROLE.RECEIVED,
                    title = "Legacy v2 Visible",
                    description = "Desc",
                    mapId = 32,
                    zoneId = 381,
                    areaCenterX = 0.33,
                    areaCenterY = 0.44,
                    areaRadius = 0.070,
                    hideMapArea = false,
                    targets = {
                        { name = "Target C", requiredCount = 1, currentCount = 0 },
                    },
                },
            },
        }
        repo:Initialize(sv)

        local q1 = repo:GetQuestById(1)
        local q2 = repo:GetQuestById(2)
        AssertEqual(q1.schemaVersion, 6, "v2 quest 1 migrated to schema v6")
        AssertEqual(q1.recommendHideMapAreas, true, "v2 hideMapArea=true preserved in recommendHideMapAreas")
        AssertEqual(q1.hideMapArea, nil, "Legacy hideMapArea cleared on q1")
        AssertEqual(q1.areaCenterX, nil, "Legacy quest-level areaCenterX cleared on q1")
        AssertEqual(q1.areaCenterY, nil, "Legacy quest-level areaCenterY cleared on q1")
        AssertEqual(q1.areaRadius, nil, "Legacy quest-level areaRadius cleared on q1")
        AssertEqual(q1.targets[1].areaCenterX, 0.41, "Target 1 inherits q1 areaCenterX")
        AssertEqual(q1.targets[2].areaCenterY, 0.62, "Target 2 inherits q1 areaCenterY")
        AssertEqual(q1.targets[2].areaRadius, 0.125, "Target 2 inherits q1 areaRadius")
        AssertEqual(q1.targets[1].customMessageInLocation, "", "Target 1 initializes customMessageInLocation")
        AssertEqual(q1.targets[1].customMessageOutsideLocation, nil, "Target 1 clears legacy customMessageOutsideLocation")

        AssertEqual(q2.schemaVersion, 6, "v2 quest 2 migrated to schema v6")

        -- v4 -> v5 -> v6 migration: consolidate customMessageOutsideLocation into customMessage and clean legacy field
        local svV4 = {
            quests = {
                {
                    id = 10,
                    schemaVersion = 4,
                    title = "V4 Consolidation",
                    targets = {
                        { name = "Guard", requiredCount = 1, customMessage = "", customMessageInLocation = "In loc", customMessageOutsideLocation = "Legacy outside" },
                        { name = "Scout", requiredCount = 1, customMessage = "Keep existing", customMessageInLocation = "", customMessageOutsideLocation = "Ignored legacy" },
                    },
                },
            },
        }
        repo:Initialize(svV4)
        local qV4 = repo:GetQuestById(10)
        AssertEqual(qV4.schemaVersion, 6, "v4 quest migrated to schema v6")
        AssertEqual(qV4.targets[1].customMessage, "Legacy outside", "Empty customMessage adopts customMessageOutsideLocation")
        AssertEqual(qV4.targets[1].customMessageInLocation, "In loc", "customMessageInLocation preserved")
        AssertEqual(qV4.targets[1].customMessageOutsideLocation, nil, "Target 1 legacy customMessageOutsideLocation removed")
        AssertEqual(qV4.targets[2].customMessage, "Keep existing", "Non-empty customMessage is not overwritten")
        AssertEqual(qV4.targets[2].customMessageOutsideLocation, nil, "Target 2 legacy customMessageOutsideLocation removed")
        AssertEqual(q2.recommendHideMapAreas, false, "v2 hideMapArea=false preserved in recommendHideMapAreas")
        AssertEqual(q2.targets[1].areaRadius, 0.070, "q2 target inherits 0.070 areaRadius")

        -- RemoveDraftTarget
        repo:ResetDraft()
        repo:SetDraftCapturedTarget({
            targetName = "First",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.2,
            targetY = 0.3,
        })
        repo:SetDraftCapturedTarget({
            targetName = "Second",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.6,
            targetY = 0.7,
        })
        AssertEqual(#repo:GetDraft().targets, 2, "2 targets in draft before RemoveDraftTarget")
        AssertEqual(repo:RemoveDraftTarget(99), nil, "RemoveDraftTarget returns nil for invalid index")
        local dAfter1 = repo:RemoveDraftTarget(1)
        AssertEqual(#dAfter1.targets, 1, "1 target remains after removing index 1")
        AssertEqual(dAfter1.targets[1].name, "Second", "Remaining target is Second")
        AssertEqual(dAfter1.lastCapturedDisplay, "Second", "lastCapturedDisplay updated to remaining target")
        AssertTrue(math.abs(dAfter1.targetX - 0.6) < 0.0001, "Centroid targetX updated after RemoveDraftTarget")

        local dAfter2 = repo:RemoveDraftTarget(1)
        AssertEqual(#dAfter2.targets, 0, "0 targets remain after removing last target")
        AssertEqual(dAfter2.lastCapturedDisplay, nil, "lastCapturedDisplay cleared when empty")
        AssertEqual(dAfter2.mapId, 0, "mapId cleared when targets and discoveries are empty")
    end)

    RunTest("Issue #255: v3 -> v4 migration, lifecycle/resolution orthogonality, GM testing isolation, and recipient reset", function()
        local repo = RPQuest.QuestRepository
        local sv = repo:GetDefaults()
        sv.nextId = 10
        sv.quests = {
            { id = 1, schemaVersion = 3, role = "prepared", title = "V3 Draft", targets = { { name = "A", requiredCount = 1 } } },
            { id = 2, schemaVersion = 3, role = "prepared", title = "V3 Sent Unanswered", sentTo = "@P1", sentAt = 100, targets = { { name = "A", requiredCount = 1 } } },
            { id = 3, schemaVersion = 3, role = "prepared", title = "V3 Sent Accepted", sentTo = "@P2", lastResult = { status = "accepted", characterName = "C2" }, targets = { { name = "A", requiredCount = 1 } } },
            { id = 4, schemaVersion = 3, role = "prepared", title = "V3 Sent Rejected", sentTo = "@P3", deliveries = { { status = "rejected", characterName = "C3" } }, targets = { { name = "A", requiredCount = 1 } } },
            { id = 5, schemaVersion = 3, role = "prepared", title = "V3 Sent Completed", sentTo = "@P4", lastResult = { status = "completed", characterName = "C4" }, targets = { { name = "A", requiredCount = 1 } } },
            { id = 6, schemaVersion = 3, role = "received", status = "offered", title = "V3 Offered", targets = { { name = "A", requiredCount = 1 } } },
            { id = 7, schemaVersion = 3, role = "received", status = "active", title = "V3 Active", targets = { { name = "A", requiredCount = 1 } } },
            { id = 8, schemaVersion = 3, role = "received", status = "active", completed = true, title = "V3 Completed", targets = { { name = "A", requiredCount = 1 } } },
            { id = 9, schemaVersion = 3, role = "received", status = "active", failed = true, title = "V3 Failed", targets = { { name = "A", requiredCount = 1 } } },
        }
        repo:Initialize(sv)

        local q1 = repo:GetQuestById(1)
        local q2 = repo:GetQuestById(2)
        local q3 = repo:GetQuestById(3)
        local q4 = repo:GetQuestById(4)
        local q5 = repo:GetQuestById(5)
        local q6 = repo:GetQuestById(6)
        local q7 = repo:GetQuestById(7)
        local q8 = repo:GetQuestById(8)
        local q9 = repo:GetQuestById(9)

        AssertEqual(q1.schemaVersion, 6, "v3 quests migrated to v6")
        AssertEqual(repo:GetQuestLifecycle(q1), "draft", "q1 lifecycle=draft")
        AssertEqual(repo:GetQuestResolution(q1), nil, "q1 resolution=nil")
        AssertEqual(repo:GetQuestLifecycle(q2), "sent", "q2 lifecycle=sent")
        AssertEqual(repo:GetQuestResolution(q2), nil, "q2 resolution=nil")
        AssertEqual(repo:GetQuestLifecycle(q3), "sent", "q3 lifecycle=sent")
        AssertEqual(repo:GetQuestResolution(q3), "accepted", "q3 resolution=accepted")
        AssertEqual(repo:GetQuestLifecycle(q4), "sent", "q4 lifecycle=sent")
        AssertEqual(repo:GetQuestResolution(q4), "rejected", "q4 resolution=rejected")
        AssertEqual(repo:GetQuestLifecycle(q5), "sent", "q5 lifecycle=sent")
        AssertEqual(repo:GetQuestResolution(q5), "completed", "q5 resolution=completed")
        AssertEqual(repo:GetQuestLifecycle(q6), "received", "q6 lifecycle=received")
        AssertEqual(repo:GetQuestResolution(q6), nil, "q6 offered resolution=nil")
        AssertEqual(repo:GetQuestLifecycle(q7), "received", "q7 lifecycle=received")
        AssertEqual(repo:GetQuestResolution(q7), "accepted", "q7 active resolution=accepted")
        AssertEqual(repo:GetQuestResolution(q8), "completed", "q8 completed resolution=completed")
        AssertEqual(repo:GetQuestResolution(q9), "failed", "q9 failed resolution=failed")
        AssertEqual(q9.failureReported, false, "q9 failureReported initialized to false")

        -- Local GM testing on Draft and Sent does not corrupt lifecycle or remote resolution
        repo:SetActiveQuest(q1.id)
        repo:RecordTargetEliminated("A", { mapId = 0, zoneId = 0, x = 0.5, y = 0.5 })
        AssertEqual(q1.completed, true, "Local GM test completes draft locally")
        AssertEqual(repo:GetQuestLifecycle(q1), "draft", "Draft lifecycle unchanged by GM test")
        AssertEqual(repo:GetQuestResolution(q1), nil, "Draft resolution stays nil even after GM test")
        repo:ResetQuest(q1.id, { activate = false })
        AssertEqual(repo:GetQuestResolution(q1), nil, "Draft resolution stays nil after Reset")

        repo:SetActiveQuest(q3.id)
        repo:RecordTargetEliminated("A", { mapId = 0, zoneId = 0, x = 0.5, y = 0.5 })
        AssertEqual(q3.completed, true, "Local GM test completes sent quest locally")
        AssertEqual(repo:GetQuestLifecycle(q3), "sent", "Sent lifecycle unchanged by GM test")
        AssertEqual(repo:GetQuestResolution(q3), "accepted", "Remote resolution on Sent quest untouched by GM test")
        repo:ResetQuest(q3.id, { activate = false })
        AssertEqual(repo:GetQuestResolution(q3), "accepted", "Remote resolution on Sent quest untouched by Reset")

        -- Editing recipientAccount on a Sent quest resets lifecycle to draft and clears resolution
        RPQuest.QuestDraftStore:LoadQuestIntoDraft(repo, q3.id)
        RPQuest.QuestDraftStore:SaveDraft(repo, q3.title, "New Desc", nil, "", "disabled", "@NewPlayer")
        AssertEqual(repo:GetQuestLifecycle(q3), "draft", "Changing recipient resets lifecycle to draft")
        AssertEqual(repo:GetQuestResolution(q3), nil, "Changing recipient clears resolution")
        AssertEqual(q3.sentTo, nil, "Changing recipient clears sentTo")
    end)

    RunTest("Issue #295 & #311: Entity caps (4/10/4), localized alerts, dynamic badges, and legacy backwards compatibility", function()
        mockState.language = "en"
        RPQuest.Locale:Initialize("en")
        local repo = RPQuest.QuestRepository
        repo:Initialize({})
        RPQuest.JournalTab:Initialize()

        AssertEqual(RPQuest.Constants.TARGET.MAX_TARGETS, 4, "MAX_TARGETS is 4")
        AssertEqual(RPQuest.Constants.DISCOVERY.MAX_POINTS, 10, "MAX_POINTS is 10")
        AssertEqual(RPQuest.Constants.DIALOGUE.MAX_NPCS, 4, "MAX_NPCS is 4")

        -- 1. Target cap (4) blocks 5th distinct target, but allows stacking existing target
        repo:ResetDraft()
        for i = 1, 4 do
            mockState.reticleExists = true
            mockState.reticleName = "Target " .. tostring(i)
            local d = RPQuest.TargetCapture:CaptureFromReticle()
            AssertTrue(d ~= nil, "Target " .. tostring(i) .. " captured")
        end
        -- Stacking existing target at cap 4/4 must still succeed
        mockState.reticleName = "Target 1"
        local stackedDraft = RPQuest.TargetCapture:CaptureFromReticle()
        AssertTrue(stackedDraft ~= nil and stackedDraft.targets[1].requiredCount == 2, "Stacking existing target allowed at cap")

        -- 5th distinct target must fail with ALERT_TARGET_LIMIT
        mockState.alerts = {}
        mockState.reticleName = "Target 5"
        local blockedTarget, targetErr = RPQuest.TargetCapture:CaptureFromReticle()
        AssertEqual(blockedTarget, nil, "5th distinct target rejected")
        AssertEqual(targetErr, RPQuest.Locale:Get("ALERT_TARGET_LIMIT", 4), "Target limit returns ALERT_TARGET_LIMIT")
        AssertEqual(#mockState.alerts, 1, "Target limit emits alert")

        -- 2. Discovery cap (10) blocks 11th discovery point with ALERT_DISCOVERY_LIMIT
        for i = 1, 10 do
            local d, idx = RPQuest.TargetCapture:CaptureDiscoveryPoint("Point " .. tostring(i))
            AssertTrue(d ~= nil and idx == i, "Discovery " .. tostring(i) .. " captured")
        end
        mockState.alerts = {}
        local blockedDisc, discErr = RPQuest.TargetCapture:CaptureDiscoveryPoint("Point 11")
        AssertEqual(blockedDisc, nil, "11th discovery point rejected")
        AssertEqual(discErr, RPQuest.Locale:Get("ALERT_DISCOVERY_LIMIT", 10), "Discovery limit returns ALERT_DISCOVERY_LIMIT")
        AssertEqual(#mockState.alerts, 1, "Discovery limit emits alert")

        -- 3. Dialogue cap (4) allows 4 NPCs and blocks 5th with ALERT_DIALOGUE_LIMIT
        for i = 1, 4 do
            local d, idx = repo:AddDraftDialogue("NPC " .. tostring(i), 381, "Resp " .. tostring(i), "Clue " .. tostring(i))
            AssertTrue(d ~= nil and idx == i, "Dialogue " .. tostring(i) .. " added")
        end
        local blockedDlg, dlgErr = repo:AddDraftDialogue("NPC 5", 381, "Resp 5", "Clue 5")
        AssertEqual(blockedDlg, nil, "5th dialogue NPC rejected")
        AssertEqual(dlgErr, RPQuest.Locale:Get("ALERT_DIALOGUE_LIMIT", 4), "Dialogue limit returns ALERT_DIALOGUE_LIMIT")

        -- 4. Dynamic [%d/%d] badges in JournalEditorPane
        RPQuest.JournalTab:RefreshEditorPane()
        local targetHdrText = RPQuest.JournalTab.editorSectionsByKey.target.headerBtn:GetText()
        local discHdrText = RPQuest.JournalTab.editorSectionsByKey.discovery.headerBtn:GetText()
        local dlgHdrText = RPQuest.JournalTab.editorSectionsByKey.dialogue.headerBtn:GetText()
        AssertTrue(targetHdrText:find("[4/4]", 1, true) ~= nil, "Target section badge shows [4/4]")
        AssertTrue(discHdrText:find("[10/10]", 1, true) ~= nil, "Discovery section badge shows [10/10]")
        AssertTrue(dlgHdrText:find("[4/4]", 1, true) ~= nil, "Dialogue section badge shows [4/4]")

        -- 5. Backwards compatibility: legacy quest exceeding new caps/lengths loads cleanly
        local longTitle = string.rep("T", 95)
        local longDesc = string.rep("D", 380)
        repo:Initialize({
            nextId = 2,
            quests = {
                {
                    id = 1,
                    schemaVersion = 4,
                    role = "received",
                    status = "active",
                    title = longTitle,
                    description = longDesc,
                    targets = {
                        { name = "A", requiredCount = 1 },
                        { name = "B", requiredCount = 1 },
                        { name = "C", requiredCount = 1 },
                        { name = "D", requiredCount = 1 },
                        { name = "E", requiredCount = 1 },
                    },
                    discoveries = {
                        { zoneId = 1, worldX = 1, worldY = 1, worldZ = 1, mapId = 1, x = 0.5, y = 0.5, radius = 800, message = "1" },
                        { zoneId = 1, worldX = 2, worldY = 1, worldZ = 2, mapId = 1, x = 0.5, y = 0.5, radius = 800, message = "2" },
                        { zoneId = 1, worldX = 3, worldY = 1, worldZ = 3, mapId = 1, x = 0.5, y = 0.5, radius = 800, message = "3" },
                        { zoneId = 1, worldX = 4, worldY = 1, worldZ = 4, mapId = 1, x = 0.5, y = 0.5, radius = 800, message = "4" },
                        { zoneId = 1, worldX = 5, worldY = 1, worldZ = 5, mapId = 1, x = 0.5, y = 0.5, radius = 800, message = "5" },
                    },
                },
            },
        })
        local legacy = repo:GetQuestById(1)
        AssertEqual(legacy.title, longTitle, "Legacy long title preserved")
        AssertEqual(legacy.description, longDesc, "Legacy long description preserved")
        AssertEqual(#legacy.targets, 5, "Legacy 5-target quest preserved")
        AssertEqual(#legacy.discoveries, 5, "Legacy 5-discovery quest preserved")
    end)

    RunTest("Issue #53: QuestDraftStore & QuestRepository persist, normalize, and clone quest icon", function()
        local repo = RPQuest.QuestRepository
        local store = RPQuest.QuestDraftStore
        repo:Initialize({
            nextId = 2,
            quests = {
                {
                    id = 1,
                    schemaVersion = 5,
                    title = "Legacy Quest Without Icon",
                    description = "Old",
                    role = RPQuest.Constants.QUEST_ROLE.RECEIVED,
                    targets = { { name = "Bandit", requiredCount = 1 } },
                },
            },
        })

        local legacy = repo:GetQuestById(1)
        AssertEqual(legacy.icon, nil, "Legacy quest without icon defaults to nil")
        AssertEqual(store:NormalizeQuestIcon("unknown_icon"), nil, "Unknown icon normalizes to nil")
        AssertEqual(store:NormalizeQuestIcon("none"), nil, "'none' normalizes to nil")
        AssertEqual(store:NormalizeQuestIcon("black_hand"), "black_hand", "Valid icon normalizes to id")
        AssertEqual(store:GetQuestIconTexture("search"), "/esoui/art/miscellaneous/gamepad/gp_icon_search_64.dds", "Search icon texture resolves")

        local draft = store:CreateNewPreparedDraft(repo)
        AssertEqual(repo:GetDraft().icon, nil, "New draft starts with nil icon")

        repo:UpdateDraftFields({ icon = "steal" })
        AssertEqual(repo:GetDraft().icon, "steal", "Draft icon updates to steal")

        local targetQuest = repo:GetQuestById(draft.id)
        table.insert(targetQuest.targets, { name = "Guard", requiredCount = 1, areaCenterX = 0.5, areaCenterY = 0.5, areaRadius = 0.039 })
        store:LoadQuestIntoDraft(repo, draft.id)
        repo:UpdateDraftFields({ icon = "black_hand" })
        local committed = store:CommitDraftChanges(repo)
        AssertTrue(committed ~= nil, "Draft commits cleanly")
        AssertEqual(committed.icon, "black_hand", "Committed quest persists icon")

        local cloned = repo:DuplicateQuest(committed.id)
        AssertTrue(cloned ~= nil, "Cloned quest created")
        AssertEqual(cloned.icon, "black_hand", "Cloned quest preserves icon")

        store:LoadQuestIntoDraft(repo, cloned.id)
        repo:UpdateDraftFields({ icon = "none" })
        local cleared = store:CommitDraftChanges(repo)
        AssertEqual(cleared.icon, nil, "Selecting none clears quest icon back to nil")
    end)

    RunTest("Issue #344: schema v6 migration, draft cloning, ResetQuest, DuplicateQuest, and pure free-form quests", function()
        local repo = RPQuest.QuestRepository
        local store = RPQuest.QuestDraftStore
        RPQuest.MailTransport:Initialize()

        -- 1. Non-destructive v4/v5 -> v6 migration preserves existing fields and initializes defaults
        repo:Initialize({
            nextId = 4,
            quests = {
                {
                    id = 1,
                    schemaVersion = 4,
                    role = RPQuest.Constants.QUEST_ROLE.RECEIVED,
                    status = RPQuest.Constants.QUEST_STATUS.ACTIVE,
                    title = "Legacy v4 Investigation",
                    description = "Keep existing progress",
                    discoveries = {
                        { zoneId = 381, worldX = 100, worldY = 0, worldZ = 200, mapId = 32, x = 0.5, y = 0.5, radius = 800, message = "Clue 1", discovered = true },
                    },
                    dialogues = {
                        { npcName = "Guard", zoneId = 381, clue = "Ask", response = "Answer" },
                    },
                },
                {
                    id = 2,
                    schemaVersion = 5,
                    role = RPQuest.Constants.QUEST_ROLE.PREPARED,
                    title = "Legacy v5 Preconfigured",
                    sequentialDiscoveries = true,
                    discoveries = {
                        { zoneId = 381, worldX = 300, worldY = 0, worldZ = 400, mapId = 32, x = 0.4, y = 0.6, radius = 800, message = "Clue A", required = true },
                        { zoneId = 381, worldX = 500, worldY = 0, worldZ = 600, mapId = 32, x = 0.5, y = 0.7, radius = 800, message = "Clue B" },
                    },
                    dialogues = {
                        { npcName = "Elder", zoneId = 381, clue = "Speak", response = "Go north", required = true, executed = true },
                        { npcName = "Bard", zoneId = 381, clue = "Sing", response = "La la" },
                    },
                },
            },
            draft = {
                title = "Legacy Draft",
                discoveries = {
                    { zoneId = 381, worldX = 10, worldY = 0, worldZ = 20, radius = 800, message = "Draft clue" },
                },
                dialogues = {
                    { npcName = "Merchant", zoneId = 381, clue = "Buy", response = "Sold", executed = true },
                },
            },
        })

        local q1 = repo:GetQuestById(1)
        AssertEqual(q1.schemaVersion, 6, "v4 quest upgraded to v6")
        AssertEqual(q1.sequentialDiscoveries, false, "v4 quest sequentialDiscoveries defaults to false")
        AssertEqual(q1.discoveries[1].discovered, true, "v4 discovery discovered=true preserved")
        AssertEqual(q1.discoveries[1].required, false, "v4 discovery required initialized to false")
        AssertEqual(q1.dialogues[1].required, false, "v4 dialogue required initialized to false")
        AssertEqual(q1.dialogues[1].executed, false, "v4 dialogue executed initialized to false")

        local q2 = repo:GetQuestById(2)
        AssertEqual(q2.schemaVersion, 6, "v5 quest upgraded to v6")
        AssertEqual(q2.sequentialDiscoveries, true, "v5 sequentialDiscoveries=true preserved")
        AssertEqual(q2.discoveries[1].required, true, "v5 discovery[1].required=true preserved")
        AssertEqual(q2.discoveries[2].required, false, "v5 discovery[2].required initialized to false")
        AssertEqual(q2.dialogues[1].required, true, "v5 dialogue[1].required=true preserved")
        AssertEqual(q2.dialogues[1].executed, true, "v5 dialogue[1].executed=true preserved on migration")
        AssertEqual(q2.dialogues[2].required, false, "v5 dialogue[2].required initialized to false")
        AssertEqual(q2.dialogues[2].executed, false, "v5 dialogue[2].executed initialized to false")

        local migratedDraft = repo:GetDraft()
        AssertEqual(migratedDraft.sequentialDiscoveries, false, "EnsureDraft initializes sequentialDiscoveries=false")
        AssertEqual(migratedDraft.discoveries[1].required, false, "EnsureDraft initializes discovery.required=false")
        AssertEqual(migratedDraft.dialogues[1].required, false, "EnsureDraft initializes dialogue.required=false")
        AssertEqual(migratedDraft.dialogues[1].executed, false, "EnsureDraft resets dialogue.executed=false on draft")

        -- 2. ResetQuest preserves sequentialDiscoveries and required while resetting dialogue.executed and discovery.discovered
        q2.discoveries[1].discovered = true
        q2.dialogues[1].executed = true
        q2.dialogues[2].executed = true
        AssertEqual(repo:ResetQuest(q2.id), true, "ResetQuest succeeds on v6 quest")
        AssertEqual(q2.sequentialDiscoveries, true, "ResetQuest preserves sequentialDiscoveries=true")
        AssertEqual(q2.discoveries[1].required, true, "ResetQuest preserves discovery.required=true")
        AssertEqual(q2.discoveries[1].discovered, false, "ResetQuest resets discovery.discovered=false")
        AssertEqual(q2.dialogues[1].required, true, "ResetQuest preserves dialogue.required=true")
        AssertEqual(q2.dialogues[1].executed, false, "ResetQuest resets dialogue[1].executed=false")
        AssertEqual(q2.dialogues[2].executed, false, "ResetQuest resets dialogue[2].executed=false")

        -- 3. DuplicateQuest and LoadQuestIntoDraft + SaveDraft preserve sequentialDiscoveries and required, resetting executed
        q2.dialogues[1].executed = true
        local dup = repo:DuplicateQuest(q2.id)
        AssertTrue(dup ~= nil, "DuplicateQuest succeeds")
        AssertEqual(dup.sequentialDiscoveries, true, "DuplicateQuest preserves sequentialDiscoveries")
        AssertEqual(dup.discoveries[1].required, true, "DuplicateQuest preserves discovery[1].required")
        AssertEqual(dup.discoveries[2].required, false, "DuplicateQuest preserves discovery[2].required=false")
        AssertEqual(dup.dialogues[1].required, true, "DuplicateQuest preserves dialogue[1].required")
        AssertEqual(dup.dialogues[1].executed, false, "DuplicateQuest resets dialogue[1].executed=false")

        local loadedDraft = store:LoadQuestIntoDraft(repo, q2.id)
        AssertEqual(loadedDraft.sequentialDiscoveries, true, "LoadQuestIntoDraft loads sequentialDiscoveries=true")
        AssertEqual(loadedDraft.discoveries[1].required, true, "LoadQuestIntoDraft loads discovery[1].required=true")
        AssertEqual(loadedDraft.dialogues[1].required, true, "LoadQuestIntoDraft loads dialogue[1].required=true")
        AssertEqual(loadedDraft.dialogues[1].executed, false, "LoadQuestIntoDraft resets dialogue.executed=false")

        repo:UpdateDraftDiscoveryPoint(2, { required = true })
        repo:UpdateDraftDialogue(2, { required = true })
        repo:UpdateDraftFields({ sequentialDiscoveries = false })
        local updatedQ2 = repo:SaveDraft()
        AssertEqual(updatedQ2.sequentialDiscoveries, false, "SaveDraft updates sequentialDiscoveries=false")
        AssertEqual(updatedQ2.discoveries[2].required, true, "SaveDraft persists updated discovery[2].required=true")
        AssertEqual(updatedQ2.dialogues[2].required, true, "SaveDraft persists updated dialogue[2].required=true")
        AssertEqual(updatedQ2.dialogues[1].executed, false, "SaveDraft resets dialogue[1].executed=false")

        -- 4. Pure free-form quest (0 targets, 0 discoveries, 0 dialogues) passes HasPlayableObjectives, activates, exports, imports, and sends
        repo:ResetDraft()
        local freeform = repo:SaveDraft("Pure Free-Form Contract", "Roleplay agreement at the tavern.", nil, "Well played!", nil, "@Partner")
        AssertTrue(freeform ~= nil, "Pure free-form quest saved")
        AssertEqual(#freeform.targets, 0, "0 targets")
        AssertEqual(#freeform.discoveries, 0, "0 discoveries")
        AssertEqual(#freeform.dialogues, 0, "0 dialogues")
        AssertEqual(freeform.sequentialDiscoveries, false, "Default sequentialDiscoveries=false")
        AssertEqual(repo:HasPlayableObjectives(freeform), true, "Pure free-form quest passes HasPlayableObjectives")
        AssertEqual(repo:SetActiveQuest(freeform.id), true, "Pure free-form quest activates")
        AssertEqual(repo:GetActiveQuest().id, freeform.id, "Pure free-form quest is active")

        local ffCode, ffErr = repo:ExportQuestToCode(freeform.id)
        AssertTrue(type(ffCode) == "string" and ffCode:sub(1, 5) == "RPQ3:", "Pure free-form quest exports to RPQ3: " .. tostring(ffErr))
        local ffImported, ffImpErr = repo:ImportQuestFromCode(ffCode, "@QuestMaster")
        AssertTrue(ffImported ~= nil, "Pure free-form quest imports cleanly: " .. tostring(ffImpErr))
        AssertEqual(ffImported.title, "Pure Free-Form Contract", "Imported free-form title preserved")
        AssertEqual(#ffImported.targets, 0, "Imported free-form has 0 targets")
        AssertEqual(#ffImported.discoveries, 0, "Imported free-form has 0 discoveries")
        AssertEqual(#ffImported.dialogues, 0, "Imported free-form has 0 dialogues")

        ffImported.completed = true
        local ffCompCode, ffCompErr = repo:ExportCompletionCode(ffImported.id)
        AssertTrue(type(ffCompCode) == "string" and ffCompCode:sub(1, 6) == "RPQC1:", "Free-form quest generates RPQC1 completion code: " .. tostring(ffCompErr))
        local ffValOk = repo:ValidateResultCode(freeform.id, ffCompCode)
        AssertEqual(ffValOk, true, "Master validates RPQC1 completion code for pure free-form quest")

        local ffSendOk, ffSendErr = RPQuest.MailTransport:SendQuestToRecipients(freeform, "@Partner", "Meet at eight.")
        AssertEqual(ffSendOk, true, "SendQuestToRecipients accepts pure free-form quest: " .. tostring(ffSendErr))
        RPQuest.MailTransport:Initialize()
    end)

end
