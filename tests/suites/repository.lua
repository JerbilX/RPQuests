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

        -- 4. Progreso de bajas en mapa incorrecto (debe ignorarse)
        local recWrongMap = RPQuest.QuestRepository:RecordTargetEliminated("Nigromante Oscuro", {
            mapId = 999,
            zoneId = 999,
            x = 0.40,
            y = 0.60,
        })
        AssertEqual(recWrongMap, false, "Kill in wrong map/zone must not count")

        -- 5. Primera baja válida (1/2)
        local rec1, _, comp1 = RPQuest.QuestRepository:RecordTargetEliminated("Nigromante Oscuro^m", {
            mapId = 32,
            zoneId = 381,
            x = 0.40,
            y = 0.60,
        })
        AssertTrue(rec1, "First valid kill recorded")
        AssertEqual(comp1, false, "Not completed at 1/2")
        AssertEqual(quest.targets[1].currentCount, 1, "Current count is 1")

        -- 6. Segunda baja válida (2/2 -> Completada)
        local rec2, _, comp2 = RPQuest.QuestRepository:RecordTargetEliminated("Nigromante Oscuro", {
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
        RPQuest.JournalTab.collapsedSections = { missions = false, completed = true, preparing = true }
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

        -- 2b. Sección con item seleccionado no se colapsa; sin item seleccionado/activo sí colapsa y expande
        RPQuest.JournalTab:ToggleSection("preparing")
        AssertEqual(RPQuest.JournalTab.collapsedSections.preparing, false, "Section with selected quest stays expanded")
        RPQuest.JournalTab:SelectQuest(nil)
        RPQuest.JournalTab:ToggleSection("preparing")
        AssertEqual(RPQuest.JournalTab.collapsedSections.preparing, true, "ToggleSection collapses preparing when no item is selected/active")
        local prepRowVisible = false
        for _, b in pairs(RPQuest.JournalTab.rowBindings) do
            if b.questId == prep.id then prepRowVisible = true end
        end
        AssertEqual(prepRowVisible, false, "Collapsed section hides its quest rows")
        RPQuest.JournalTab:ToggleSection("preparing")
        AssertEqual(RPQuest.JournalTab.collapsedSections.preparing, false, "ToggleSection expands preparing again")
        RPQuest.JournalTab:SelectQuest(prep.id)

        -- 2c. Mostrar en mapa una misión en preparación (aunque no esté activa)
        RPQuest.WorldMapArea:Initialize()
        RPQuest.WorldMapArea:ShowQuestOnMap(prep)
        local pins = ZO_WorldMap_GetPinManager()._createdPins
        AssertEqual(#pins, 1, "ShowQuestOnMap renders area pin for prepared quest even when inactive")
        AssertEqual(pins[1].pinTag, prep.id, "Rendered preview pin belongs to prepared quest")
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

        -- Master exporta RPQ1 y otro jugador la importa y completa
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

        -- Rechaza un código RPQ1 como si fuera entrega
        local okQuestCode, errQuestCode = RPQuest.QuestRepository:ValidateResultCode(masterQuest.id, shareCode)
        AssertEqual(okQuestCode, false, "RPQ1 code rejected in delivery validator")
        AssertEqual(errQuestCode, "VALIDATE_ERR_NOT_COMPLETION_CODE", "Specific error returned for RPQ1 code")

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
        local q = RPQuest.QuestRepository:SaveDraft("Mision Extensa", longDesc, nil, "Completada con exito!")
        AssertTrue(q ~= nil, "Saved quest with 10 targets")

        local code = RPQuest.QuestRepository:ExportQuestToCode(q.id)
        AssertTrue(type(code) == "string" and #code > 100 and code:sub(1, 5) == "RPQ3:", "Exported RPQ3 code generated cleanly")

        -- Verificar que detailObjText tiene altura acotada (<= 96px)
        RPQuest.JournalTab:SelectQuest(q.id)
        local _, objHeight = RPQuest.JournalTab.detailObjText:GetDimensions()
        AssertTrue(objHeight <= 96, "detailObjText height capped at <= 96px to prevent vertical overflow")

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

        -- 1. Keybind string for discovery capture is registered
        RPQuest.Locale._stringsRegistered = false
        RPQuest.Locale:Initialize("en")
        AssertTrue(_G["SI_BINDING_NAME_RPQUEST_CAPTURE_DISCOVERY"] ~= nil, "SI_BINDING_NAME_RPQUEST_CAPTURE_DISCOVERY is registered")

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
            },
        })
        RPQuest.JournalTab:Initialize()
        RPQuest.JournalTab.collapsedSections = { pending = true, missions = false, completed = true, preparing = true }
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
        AssertEqual(hasRowForQuest(1), true, "Active mission row is visible initially")
        AssertEqual(hasRowForQuest(2), false, "Pending quest row is hidden initially")

        -- Clicking Pending while an active/selected quest is in Missions collapses Missions and expands Pending
        RPQuest.JournalTab:ToggleSection("pending")
        AssertEqual(RPQuest.JournalTab.collapsedSections.pending, false, "Pending expands on click")
        AssertEqual(RPQuest.JournalTab.collapsedSections.missions, true, "Missions collapses when Pending expands")
        AssertEqual(RPQuest.JournalTab.collapsedSections.completed, true, "Completed remains collapsed")
        AssertEqual(RPQuest.JournalTab.collapsedSections.preparing, true, "Preparing remains collapsed")
        AssertEqual(hasRowForQuest(2), true, "Pending quest row is visible after expanding Pending")
        AssertEqual(hasRowForQuest(1), false, "Missions quest row is hidden even though it is active/selected")

        -- Expanding Preparing collapses Pending
        RPQuest.JournalTab:ToggleSection("preparing")
        AssertEqual(RPQuest.JournalTab.collapsedSections.preparing, false, "Preparing expands on click")
        AssertEqual(RPQuest.JournalTab.collapsedSections.pending, true, "Pending collapses when Preparing expands")
        AssertEqual(hasRowForQuest(4), true, "Prepared quest row is visible")
        AssertEqual(hasRowForQuest(2), false, "Pending quest row is hidden")

        -- Expanding Completed collapses Preparing
        RPQuest.JournalTab:ToggleSection("completed")
        AssertEqual(RPQuest.JournalTab.collapsedSections.completed, false, "Completed expands on click")
        AssertEqual(RPQuest.JournalTab.collapsedSections.preparing, true, "Preparing collapses when Completed expands")
        AssertEqual(hasRowForQuest(3), true, "Completed quest row is visible")
        AssertEqual(hasRowForQuest(4), false, "Prepared quest row is hidden")

        -- Expanding Missions again collapses Completed
        RPQuest.JournalTab:ToggleSection("missions")
        AssertEqual(RPQuest.JournalTab.collapsedSections.missions, false, "Missions expands on click")
        AssertEqual(RPQuest.JournalTab.collapsedSections.completed, true, "Completed collapses when Missions expands")
        AssertEqual(hasRowForQuest(1), true, "Active mission row is visible again")
        AssertEqual(hasRowForQuest(3), false, "Completed quest row is hidden")
    end)

end
