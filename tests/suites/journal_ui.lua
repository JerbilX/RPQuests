-- ============================================================================
-- RPQuest Test Suite: JournalTab UI & Lifecycle Suites
-- ============================================================================
return function(T)
    local RunTest = T.RunTest
    local AssertEqual = T.AssertEqual
    local AssertTrue = T.AssertTrue
    local mockState = T.mockState
    local mockPinManager = T.mockPinManager

    RunTest("RPQuest Initialize via EVENT_ADD_ON_LOADED sets up Account-Wide SavedVars and JournalTab", function()
        mockState.language = "es"
        RPQuest.Locale:Initialize()
        EVENT_MANAGER:FireEvent(EVENT_ADD_ON_LOADED, "RPQuest")

        AssertTrue(RPQuest.savedVars ~= nil, "Account-Wide SavedVars initialized")
        AssertTrue(RPQuest.JournalTab.isInitialized, "JournalTab initialized")
        AssertTrue(RPQuest.JournalTab.isTabAdded, "Custom Quests tab registered in QUEST_JOURNAL_KEYBOARD.tabs")

        -- Crear una misión desde la UI del Editor en la pestaña del Diario
        RPQuest.JournalTab:OpenTab()
        RPQuest.JournalTab:OpenCreateEditor()
        AssertEqual(RPQuest.JournalTab.editorPane:IsHidden(), false, "Editor pane is visible")

        mockState.reticleExists = true
        mockState.reticleIsPlayer = false
        mockState.reticleIsDead = false
        mockState.reticleName = "Señor Vampiro"
        mockState.mapId = 60
        mockState.zoneId = 200
        mockState.mapName = "Rivenspire"
        mockState.playerX = 0.25
        mockState.playerY = 0.75

        RPQuest:OnCaptureTargetKeybind()
        RPQuest.JournalTab.titleEdit:SetText("Cacería Nocturna")
        RPQuest.JournalTab.descEdit:SetText("Derrota al vampiro en las ruinas.")
        AssertEqual(RPQuest.JournalTab.countEdit, nil, "Manual countEdit must not exist in JournalTab")
        AssertEqual(RPQuest.JournalTab.btnSaveEditor:GetText(), "Crear Misión", "Spanish button label is Crear Misión")
        RPQuest.JournalTab.titleEdit:FireHandler("OnMouseDown")
        AssertTrue(RPQuest.JournalTab.titleEdit._focused, "Clicking titleEdit focuses it for keyboard input")
        RPQuest.JournalTab.descEdit:FireHandler("OnMouseDown")
        AssertTrue(RPQuest.JournalTab.descEdit._focused, "Clicking descEdit focuses it for keyboard input")
        RPQuest.JournalTab:OnSaveDraftClicked()

        local savedList = RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.PREPARED)
        AssertEqual(#savedList, 1, "Prepared quest saved from JournalTab")
        local preparedQuest = savedList[1]
        AssertEqual(preparedQuest.title, "Cacería Nocturna", "Saved title matches")
        AssertEqual(RPQuest.QuestRepository:GetActiveQuest(), nil, "Prepared quest is not auto-activated on save")

        -- Probar la misión manualmente desde En Preparación
        RPQuest.JournalTab:OnToggleActiveClicked()
        local active = RPQuest.QuestRepository:GetActiveQuest()
        AssertTrue(active ~= nil and active.id == preparedQuest.id, "Prepared quest activated for local testing via JournalTab")

        -- ShareCodec sigue funcionando como capa interna de serialización para MailTransport
        local generatedCode = RPQuest.QuestRepository:ExportQuestToCode(preparedQuest.id)
        AssertTrue(string.sub(generatedCode, 1, 5) == "RPQ3:", "Internal ExportQuestToCode produces RPQ3 code")
        AssertEqual(RPQuest.JournalTab.importPane, nil, "Manual importPane removed")
        AssertEqual(RPQuest.JournalTab.shareEdit, nil, "Manual shareEdit removed")
        AssertEqual(RPQuest.JournalTab.mailInboxPane, nil, "Manual mailInboxPane removed")

        -- Verificar que ImportQuestFromCode + AcceptOfferedQuest emite banner CSA
        mockState.csaMessages = {}
        local offeredQ = RPQuest.QuestRepository:ImportQuestFromCode(generatedCode, "@Master", {
            status = RPQuest.Constants.QUEST_STATUS.OFFERED,
            sourceMailId = "test_import_901",
        })
        RPQuest.QuestRepository:AcceptOfferedQuest(offeredQ.id)
        RPQuest.Announcements:AnnounceQuestAccepted(offeredQ)
        AssertEqual(#RPQuest.QuestRepository:GetAllQuests(), 2, "Second quest imported via internal repository flow")
        AssertEqual(#mockState.csaMessages, 1, "Accepting quest emits one CENTER_SCREEN_ANNOUNCE banner")
        AssertEqual(mockState.csaMessages[1].category, CSA_CATEGORY_LARGE_TEXT, "Quest accepted CSA uses large text category")
        AssertEqual(mockState.csaMessages[1].sound, SOUNDS.QUEST_ACCEPTED, "Quest accepted CSA plays SOUNDS.QUEST_ACCEPTED")
        AssertEqual(mockState.csaMessages[1].csaType, CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_ADDED, "Quest accepted CSA uses CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_ADDED")

        -- Verificar que salir de Edit mode seleccionando otra misión limpia editingQuestId
        RPQuest.JournalTab:OpenEditEditor(active.id)
        AssertEqual(RPQuest.QuestRepository:GetDraft().editingQuestId, active.id, "Draft has editingQuestId while in Edit mode")
        RPQuest.JournalTab:SelectQuest(active.id)
        AssertEqual(RPQuest.QuestRepository:GetDraft().editingQuestId, nil, "Selecting a quest in list clears orphaned editingQuestId")
    end)

    RunTest("Reticle inference: repeated same NPC (Imp x3) and multiple named NPCs + Create Quest button", function()
        mockState.language = "en"
        RPQuest.Locale:Initialize("en")
        AssertEqual(RPQuest.Locale:Get("BTN_SAVE"), "Create Quest", "English create button label is Create Quest")

        RPQuest.QuestRepository:Initialize({})
        mockState.reticleExists = true
        mockState.reticleIsPlayer = false
        mockState.reticleIsDead = false
        mockState.mapId = 32
        mockState.zoneId = 381
        mockState.mapName = "Auridon"
        mockState.playerX = 0.50
        mockState.playerY = 0.50

        -- Caso A: Apuntar a un Imp 3 veces -> objetivo inferido: Imp x3
        mockState.reticleName = "Imp"
        RPQuest.TargetCapture:CaptureFromReticle()
        RPQuest.TargetCapture:CaptureFromReticle()
        local draftImp = RPQuest.TargetCapture:CaptureFromReticle()
        AssertEqual(#draftImp.targets, 1, "Same NPC merges into 1 target entry")
        AssertEqual(draftImp.targets[1].requiredCount, 3, "Imp captured 3 times requires 3 kills")
        AssertEqual(RPQuest.QuestRepository:FormatTargetsSummary(draftImp.targets), "Imp x3", "Formatted summary is Imp x3")

        local impQuest = RPQuest.QuestRepository:SaveDraft("Imp Hunt", "Clear the imps.")
        AssertEqual(impQuest.targets[1].requiredCount, 3, "Saved quest inferred requiredCount = 3 from reticle")

        -- Caso B: Apuntar a dos NPCs con nombre distinto -> ambos son objetivos exclusivos
        mockState.reticleName = "Lord Vane"
        RPQuest.TargetCapture:CaptureFromReticle()
        mockState.reticleName = "Lady Vane"
        local draftDuo = RPQuest.TargetCapture:CaptureFromReticle()
        AssertEqual(#draftDuo.targets, 2, "Two distinct named NPCs create 2 target entries")
        AssertEqual(RPQuest.QuestRepository:FormatTargetsSummary(draftDuo.targets), "Lord Vane, Lady Vane", "Summary lists both named NPCs")

        local duoQuest = RPQuest.QuestRepository:SaveDraft("Twin Assassination", "Eliminate both targets.")
        AssertEqual(#duoQuest.targets, 2, "Saved quest has 2 distinct targets")
        RPQuest.QuestRepository:SetActiveQuest(duoQuest.id)

        -- Matar a Lord Vane 2 veces no debe completar a Lady Vane
        local r1, _, c1 = RPQuest.QuestRepository:RecordTargetEliminated("Lord Vane", { mapId = 32, zoneId = 381, x = 0.50, y = 0.50 })
        AssertTrue(r1 and not c1, "Killing Lord Vane advances progress but does not complete quest")
        local rDup = RPQuest.QuestRepository:RecordTargetEliminated("Lord Vane", { mapId = 32, zoneId = 381, x = 0.50, y = 0.50 })
        AssertEqual(rDup, false, "Killing already completed named target again is ignored")

        -- Matar a Lady Vane completa la misión
        local r2, _, c2 = RPQuest.QuestRepository:RecordTargetEliminated("Lady Vane", { mapId = 32, zoneId = 381, x = 0.50, y = 0.50 })
        AssertTrue(r2 and c2, "Killing second named target completes the quest")

        -- Exportar e importar misión multi-objetivo conserva todos los objetivos
        local code = RPQuest.QuestRepository:ExportQuestToCode(duoQuest.id)
        local imported = RPQuest.QuestRepository:ImportQuestFromCode(code)
        AssertEqual(#imported.targets, 2, "Imported multi-target quest preserves both targets")
        AssertEqual(imported.targets[1].name, "Lord Vane", "First imported target matches")
        AssertEqual(imported.targets[2].name, "Lady Vane", "Second imported target matches")

        -- Caso C: Capturar objetivos en mapas distintos reinicia la lista al nuevo mapa
        RPQuest.QuestRepository:ResetDraft()
        mockState.mapId = 32
        mockState.playerX = 0.20
        mockState.playerY = 0.20
        mockState.reticleName = "Guardia de Auridon"
        RPQuest.TargetCapture:CaptureFromReticle()

        mockState.mapId = 45
        mockState.playerX = 0.80
        mockState.playerY = 0.80
        mockState.reticleName = "Guardia de Deshaan"
        local draftMapSwitch = RPQuest.TargetCapture:CaptureFromReticle()
        AssertEqual(#draftMapSwitch.targets, 1, "Capturing target in a new map resets targets from previous map")
        AssertEqual(draftMapSwitch.targets[1].name, "Guardia de Deshaan", "Only the new map target remains")
        AssertEqual(draftMapSwitch.targetX, 0.80, "Centroid X is strictly from the new map")
        AssertEqual(draftMapSwitch.targetY, 0.80, "Centroid Y is strictly from the new map")

        -- Caso D: ClearDraftTargets limpia también metadatos del mapa
        RPQuest.QuestRepository:ClearDraftTargets()
        AssertEqual(draftMapSwitch.mapId, 0, "ClearDraftTargets resets mapId to 0")
        AssertEqual(draftMapSwitch.zoneId, 0, "ClearDraftTargets resets zoneId to 0")
        AssertEqual(draftMapSwitch.mapName, "", "ClearDraftTargets resets mapName to empty")
    end)

    RunTest("Bugfixes: DeleteQuest resets dangling draft and JournalTab scrolls >14 rows", function()
        RPQuest.QuestRepository:Initialize({})
        RPQuest.JournalTab:Initialize()

        -- 1. DeleteQuest limpia editingQuestId si esa misión estaba en edición
        mockState.reticleExists = true
        mockState.reticleName = "Bandido"
        RPQuest.TargetCapture:CaptureFromReticle()
        local q1 = RPQuest.QuestRepository:SaveDraft("Misión Uno", "Desc", 0.05)
        RPQuest.JournalTab:OpenEditEditor(q1.id)
        AssertEqual(RPQuest.QuestRepository:GetDraft().editingQuestId, q1.id, "Draft editing q1")
        RPQuest.QuestRepository:DeleteQuest(q1.id)
        AssertEqual(RPQuest.QuestRepository:GetDraft().editingQuestId, nil, "DeleteQuest clears dangling editingQuestId")

        -- 2. JournalTab pagina/desplaza más allá de 14 filas
        for i = 1, 16 do
            RPQuest.TargetCapture:CaptureFromReticle()
            RPQuest.QuestRepository:SaveDraft("Quest #" .. tostring(i), "", 0.05)
        end
        RPQuest.JournalTab:Refresh()
        AssertEqual(RPQuest.JournalTab.btnListNext:IsHidden(), false, "Scroll Next button shown when > 14 rows")
        AssertEqual(RPQuest.JournalTab.listOffset, 0, "Initial listOffset is 0")
        RPQuest.JournalTab:ScrollQuestList(2)
        AssertEqual(RPQuest.JournalTab.listOffset, 2, "ScrollQuestList advances offset")
        AssertEqual(RPQuest.JournalTab.rowBindings[1].questId, 3, "First visible row reflects scrolled offset")
    end)

    RunTest("12. Higiene UI: anclaje dinámico de botones, título único tras borrado y ciclo _dirty", function()
        RPQuest.QuestRepository:Initialize({})
        RPQuest.JournalTab:Initialize()
        mockState.reticleExists = true
        mockState.reticleName = "Bandido"

        -- 1. Título por defecto usa nextId y no colisiona tras borrar
        RPQuest.TargetCapture:CaptureFromReticle()
        local qa = RPQuest.QuestRepository:SaveDraft("", "", 0.05)
        RPQuest.TargetCapture:CaptureFromReticle()
        local qb = RPQuest.QuestRepository:SaveDraft("", "", 0.05)
        RPQuest.QuestRepository:DeleteQuest(qa.id)
        RPQuest.TargetCapture:CaptureFromReticle()
        local qc = RPQuest.QuestRepository:SaveDraft("", "", 0.05)
        AssertTrue(qb.title ~= qc.title, "Default title uses nextId and does not collide after deletion")

        -- 2. Detalle de misión preparada muestra botón de envío directo sin cajas de código manual
        RPQuest.JournalTab:SelectQuest(qc.id)
        AssertEqual(RPQuest.JournalTab.codeDivider, nil, "Manual codeDivider removed")
        AssertEqual(RPQuest.JournalTab.shareBg, nil, "Manual shareBg removed")
        AssertEqual(RPQuest.JournalTab.validateBg, nil, "Manual validateBg removed")
        AssertEqual(RPQuest.JournalTab.btnSendDirect:IsHidden(), false, "Direct mail send button visible for prepared quest")

        -- 3. _dirty se marca cuando panel está oculto y se limpia al abrir
        RPQuest.JournalTab.panel:SetHidden(true)
        RPQuest.QuestRepository:SetActiveQuest(qb.id)
        AssertEqual(RPQuest.JournalTab._dirty, true, "_dirty set while panel is hidden")
        RPQuest.JournalTab:OpenTab()
        AssertEqual(RPQuest.JournalTab._dirty, false, "_dirty cleared after OpenTab")
    end)

    RunTest("14. Mensaje de finalizacion editable y refresco de pin al editar radio y abrir mapa", function()
        RPQuest.QuestRepository:Initialize({})
        RPQuest.JournalTab:Initialize()
        RPQuest.WorldMapArea:Initialize()

        mockState.reticleExists = true
        mockState.reticleName = "Oveja"
        mockState.mapId = 45
        mockState.zoneId = 104
        mockState.mapName = "Deshaan"
        mockState.playerX = 0.50
        mockState.playerY = 0.50

        -- 1. Crear misión con mensaje de finalización personalizado desde JournalTab
        RPQuest.JournalTab:OpenCreateEditor()
        RPQuest.TargetCapture:CaptureFromReticle()
        RPQuest.JournalTab.titleEdit:SetText("Gran Cacería")
        RPQuest.JournalTab.descEdit:SetText("Caza en el valle.")
        RPQuest.JournalTab.completionEdit:SetText("¡Has limpiado el valle!")
        RPQuest.JournalTab:OnSaveDraftClicked()

        local q = RPQuest.QuestRepository:GetAllQuests()[1]
        AssertEqual(q.completionMessage, "¡Has limpiado el valle!", "completionMessage saved from JournalTab")

        -- 2. ShareCodec preserva completionMessage
        local code = RPQuest.QuestRepository:ExportQuestToCode(q.id)
        local decoded = RPQuest.ShareCodec:DecodeQuest(code)
        AssertEqual(decoded.completionMessage, "¡Has limpiado el valle!", "ShareCodec preserves completionMessage")

        -- 3. AnnounceQuestCompleted usa completionMessage en lugar de un único objetivo
        local capturedSubText = nil
        local origCSA = CENTER_SCREEN_ANNOUNCE
        CENTER_SCREEN_ANNOUNCE = {
            CreateMessageParams = function()
                return {
                    SetText = function(_, _, sub) capturedSubText = sub end,
                    SetCSAType = function() end,
                }
            end,
            AddMessageWithParams = function() end,
        }
        RPQuest.Announcements:AnnounceQuestCompleted(q)
        AssertEqual(capturedSubText, "¡Has limpiado el valle!", "AnnounceQuestCompleted uses custom completionMessage")

        -- Sin mensaje personalizado -> subText es nil (no muestra un único objetivo parcial)
        RPQuest.Announcements:AnnounceQuestCompleted({ title = "Sin Msg", completionMessage = "", targets = { { name = "Tirusa", currentCount = 1, requiredCount = 1 } } })
        AssertEqual(capturedSubText, nil, "AnnounceQuestCompleted omits subText when completionMessage is empty")
        CENTER_SCREEN_ANNOUNCE = origCSA

        -- 4. Editar radio de área, desactivar/reactivar y mostrar escena del mapa refresca el pin con el nuevo radio
        RPQuest.JournalTab:OpenEditEditor(q.id)
        RPQuest.QuestRepository:UpdateDraftFields({ areaRadius = RPQuest.Constants.AREA_RADIUS.LARGE })
        RPQuest.JournalTab:OnSaveDraftClicked()
        RPQuest.QuestRepository:SetActiveQuest(q.id)

        -- Simular apertura del mapa mundial via WORLD_MAP_SCENE
        SCENE_MANAGER:Show("worldMap")
        AssertEqual(#mockPinManager._createdPins, 1, "WorldMapArea pin rendered after edit + reactivate + map open")
        AssertEqual(mockPinManager._createdPins[1].radius, RPQuest.Constants.AREA_RADIUS.LARGE, "WorldMapArea pin uses updated LARGE radius")
    end)

    RunTest("16. Marca del mapa visible en preparacion y actualizada al instante al editar tamano", function()
        RPQuest.QuestRepository:Initialize({})
        RPQuest.JournalTab:Initialize()
        RPQuest.WorldMapArea:Initialize()

        local mockPinManager = ZO_WorldMap_GetPinManager()
        mockPinManager._createdPins = {}

        mockState.reticleExists = true
        mockState.reticleName = "Nigromante"
        mockState.reticleIsPlayer = false
        mockState.reticleIsDead = false
        mockState.reticleAttackable = true
        mockState.mapId = 45
        mockState.zoneId = 104
        mockState.mapName = "Deshaan"
        mockState.playerX = 0.50
        mockState.playerY = 0.50

        -- 1. En creación (sin guardar), capturar objetivo muestra el pin en el mapa y habilita Ver en Mapa en el editor
        RPQuest.JournalTab:OpenCreateEditor()
        AssertEqual(RPQuest.JournalTab.btnShowMapEditor:IsHidden(), true, "ShowMapEditor hidden before target capture")
        RPQuest.TargetCapture:CaptureFromReticle()
        AssertEqual(RPQuest.JournalTab.btnShowMapEditor:IsHidden(), false, "ShowMapEditor visible after target capture")
        AssertEqual(#mockPinManager._createdPins, 1, "Map pin rendered immediately during draft preparation")
        AssertEqual(mockPinManager._createdPins[1].radius, RPQuest.Constants.AREA_RADIUS.MEDIUM, "Draft pin starts with MEDIUM radius")

        -- 2. Cambiar radio en el editor antes de guardar actualiza el pin al instante
        RPQuest.JournalTab.btnRadiusLarge:FireHandler("OnClicked")
        AssertEqual(#mockPinManager._createdPins, 1, "Map pin refreshed on radius change")
        AssertEqual(mockPinManager._createdPins[1].radius, RPQuest.Constants.AREA_RADIUS.LARGE, "Draft pin immediately reflects LARGE radius")

        -- Guardar la misión preparada
        RPQuest.JournalTab.titleEdit:SetText("Ritual en Deshaan")
        RPQuest.JournalTab:OnSaveDraftClicked()
        local q = RPQuest.QuestRepository:GetAllQuests()[1]
        AssertEqual(q.areaRadius, RPQuest.Constants.AREA_RADIUS.LARGE, "Saved quest keeps LARGE radius")

        -- 3. Abrir Editar y cambiar radio a SMALL refleja el nuevo tamaño en el mapa al instante (sin guardar todavía)
        RPQuest.JournalTab:OpenEditEditor(q.id)
        RPQuest.JournalTab.btnRadiusSmall:FireHandler("OnClicked")
        AssertEqual(#mockPinManager._createdPins, 1, "Map pin refreshed when editing quest radius")
        AssertEqual(mockPinManager._createdPins[1].radius, RPQuest.Constants.AREA_RADIUS.SMALL, "Edited draft pin immediately reflects SMALL radius")

        -- 4. Pulsar Ver en Mapa desde el editor abre el mapa mostrando el pin editado
        RPQuest.JournalTab.btnShowMapEditor:FireHandler("OnClicked")
        AssertEqual(#mockPinManager._createdPins, 1, "ShowQuestOnMap from editor renders pin")
        AssertEqual(mockPinManager._createdPins[1].radius, RPQuest.Constants.AREA_RADIUS.SMALL, "ShowQuestOnMap from editor uses current edited SMALL radius")
    end)

    RunTest("Editor Accordion Sections: default state, toggle layout, and auto-expand on edit", function()
        RPQuest.QuestRepository:Initialize(RPQuest.QuestRepository:GetDefaults())
        RPQuest.JournalTab:Initialize()
        RPQuest.JournalTab:OpenTab()
        RPQuest.JournalTab:OpenCreateEditor()

        local sections = RPQuest.JournalTab.editorSectionsByKey
        AssertTrue(sections ~= nil, "editorSectionsByKey initialized")
        AssertEqual(sections.target.body:IsHidden(), true, "Target section starts collapsed")
        AssertEqual(sections.discovery.body:IsHidden(), true, "Discovery section starts collapsed")
        AssertEqual(sections.dialogue.body:IsHidden(), true, "Dialogue section starts collapsed")
        AssertEqual(sections.options.body:IsHidden(), true, "Options section starts collapsed")

        local yCollapsed = sections.dialogue.divider._anchors[1].y
        RPQuest.JournalTab:ToggleEditorSection("discovery")
        AssertEqual(sections.discovery.body:IsHidden(), false, "Discovery section expands on toggle")
        local yExpanded = sections.dialogue.divider._anchors[1].y
        AssertTrue(yExpanded > yCollapsed, "Subsequent section Y offset increases when discovery accordion expands")

        RPQuest.JournalTab:ToggleEditorSection("discovery")
        AssertEqual(sections.discovery.body:IsHidden(), true, "Discovery section collapses on second toggle")

        -- Save a quest with options configured and verify OpenEditEditor keeps all accordions collapsed by default
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Bandido",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.50,
            targetY = 0.50,
        })
        RPQuest.QuestRepository:UpdateDraftFields({ requireUndetected = true })
        local q = RPQuest.QuestRepository:SaveDraft("Misión Acordeón", "Prueba.", nil, "Listo.")
        AssertTrue(q ~= nil, "Quest saved for edit accordion test")

        RPQuest.JournalTab:OpenEditEditor(q.id)
        AssertEqual(sections.target.body:IsHidden(), true, "Target section starts collapsed on edit")
        AssertEqual(sections.options.body:IsHidden(), true, "Options section starts collapsed on edit")
        AssertEqual(sections.discovery.body:IsHidden(), true, "Discovery section starts collapsed on edit")
    end)

    RunTest("29. JournalTab:OpenTab defers SelectFragment during async scene transition from another scene", function()
        RPQuest.JournalTab:Initialize()

        local origIsShowing = SCENE_MANAGER.IsShowing
        local origShow = SCENE_MANAGER.Show
        local origSelectFragment = QUEST_JOURNAL_KEYBOARD.tabs.SelectFragment
        local selectCalls = 0

        QUEST_JOURNAL_KEYBOARD.tabs.SelectFragment = function(tabsSelf, name)
            selectCalls = selectCalls + 1
            origSelectFragment(tabsSelf, name)
        end

        -- Simular transición asíncrona (ej. desde Notificaciones o Correo en SCENE_HIDING):
        -- SCENE_MANAGER:Show("questJournal") encola la escena pero IsShowing("questJournal") sigue false hasta SCENE_SHOWING.
        SCENE_MANAGER.IsShowing = function(_, sceneName)
            return false
        end
        SCENE_MANAGER.Show = function(_, sceneName)
            -- No cambia a SCENE_SHOWN de forma síncrona
        end

        RPQuest.JournalTab:OpenTab()
        AssertEqual(selectCalls, 0, "SelectFragment not called synchronously while previous scene is still hiding")
        AssertEqual(QUEST_JOURNAL_KEYBOARD.mode, RPQuest.Constants.UI.TAB_DESCRIPTOR, "QuestJournal mode set before OnShowing")

        -- Cuando la escena previa termina de ocultarse, ESO dispara QUEST_JOURNAL_KEYBOARD:OnShowing()
        QUEST_JOURNAL_KEYBOARD:OnShowing()
        AssertEqual(selectCalls, 1, "SelectFragment called inside OnShowing once questJournal scene starts showing")

        -- Si questJournal ya estaba visible (p. ej. cambiando desde pestaña Quests), sí selecciona síncronamente
        SCENE_MANAGER.IsShowing = function(_, sceneName)
            return sceneName == "questJournal"
        end
        RPQuest.JournalTab:OpenTab()
        AssertEqual(selectCalls, 2, "SelectFragment called synchronously when questJournal is already showing")

        SCENE_MANAGER.IsShowing = origIsShowing
        SCENE_MANAGER.Show = origShow
        QUEST_JOURNAL_KEYBOARD.tabs.SelectFragment = origSelectFragment
    end)

    RunTest("37. OFFERED pending quest UI in JournalTab: Accept activates and Reject removes (Issue #143)", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.JournalTab:Initialize()

        local code = RPQuest.ShareCodec:EncodeQuest({
            title = "Contrato Pendiente",
            description = "Acepta o rechaza.",
            mapId = mockState.mapId,
            zoneId = mockState.zoneId,
            mapName = "Auridon",
            targets = { { name = "Lobo", requiredCount = 1 } },
        })

        local offered, _, isDup = RPQuest.QuestRepository:ImportQuestFromCode(code, "@Master", {
            status = RPQuest.Constants.QUEST_STATUS.OFFERED,
            sourceMailId = "mail_pending_1",
        })
        AssertTrue(offered ~= nil, "Offered quest imported")
        AssertEqual(isDup, false, "First import is not duplicate")
        AssertEqual(RPQuest.QuestRepository:GetActiveQuest(), nil, "Offered quest is not active yet")
        AssertEqual(RPQuest.QuestRepository:SetActiveQuest(offered.id), false, "Cannot set OFFERED quest active directly")

        -- Duplicate prevention by sourceMailId
        local dupQ, _, isDup2 = RPQuest.QuestRepository:ImportQuestFromCode(code, "@Master", {
            status = RPQuest.Constants.QUEST_STATUS.OFFERED,
            sourceMailId = "mail_pending_1",
        })
        AssertEqual(isDup2, true, "Second import with same sourceMailId detected as duplicate")
        AssertEqual(dupQ.id, offered.id, "Returns existing quest on duplicate")

        -- JournalTab shows Accept and Reject buttons for OFFERED quest
        RPQuest.JournalTab:SelectQuest(offered.id)
        RPQuest.JournalTab:Refresh()
        AssertEqual(RPQuest.JournalTab.btnAcceptOffered:IsHidden(), false, "Accept button visible for OFFERED quest")
        AssertEqual(RPQuest.JournalTab.btnRejectOffered:IsHidden(), false, "Reject button visible for OFFERED quest")
        AssertEqual(RPQuest.JournalTab.btnActivate:IsHidden(), true, "Activate button hidden for OFFERED quest")
        AssertEqual(RPQuest.JournalTab.abandonQuestDescriptor.visible(), false, "Abandon keybind hidden for OFFERED pending quest")
        AssertEqual(RPQuest.JournalTab.abandonQuestDescriptor.enabled(), false, "Abandon keybind disabled for OFFERED pending quest")
        AssertEqual(RPQuest.JournalTab:ConfirmAbandonQuest(offered.id), false, "ConfirmAbandonQuest blocked for OFFERED pending quest")

        -- Accept activates quest
        local accepted = RPQuest.JournalTab:AcceptSelectedOfferedQuest()
        AssertEqual(accepted, true, "AcceptSelectedOfferedQuest succeeds")
        AssertEqual(RPQuest.QuestRepository:GetActiveQuest().id, offered.id, "Quest becomes active after Accept")
        AssertEqual(RPQuest.JournalTab.btnAcceptOffered:IsHidden(), true, "Accept button hidden after Accept")
        AssertEqual(RPQuest.JournalTab.abandonQuestDescriptor.visible(), true, "Abandon keybind visible after accepting quest")
        AssertEqual(RPQuest.JournalTab.abandonQuestDescriptor.enabled(), true, "Abandon keybind enabled after accepting quest")

        -- Reject removes another offered quest
        local offered2 = RPQuest.QuestRepository:ImportQuestFromCode(code, "@Master", {
            status = RPQuest.Constants.QUEST_STATUS.OFFERED,
            sourceMailId = "mail_pending_2",
        })
        RPQuest.JournalTab:SelectQuest(offered2.id)
        local rejected = RPQuest.JournalTab:RejectSelectedOfferedQuest()
        AssertEqual(rejected, true, "RejectSelectedOfferedQuest succeeds")
        AssertEqual(RPQuest.QuestRepository:GetQuestById(offered2.id), nil, "Rejected quest removed from repository")
    end)

    RunTest("41. Show On Map keybind prompt visibility across quest selection, accept, activate, and modes (Issue #165)", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.JournalTab:Initialize()
        RPQuest.JournalTab.panel:SetHidden(false)

        -- 1. No quest selected -> hidden
        RPQuest.JournalTab:Refresh()
        AssertEqual(RPQuest.JournalTab.showOnMapKeybindButton:IsHidden(), true, "Show On Map hidden when no quest selected")
        AssertEqual(RPQuest.JournalTab.showOnMapDescriptor.visible(), false, "showOnMapDescriptor.visible false when no quest selected")

        -- 2. Import and select offered quest -> visible
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Bandido",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.5,
            targetY = 0.5,
        })
        local prepared = RPQuest.QuestRepository:SaveDraft("Misión Mapa", "Prueba Show On Map.")
        local code = RPQuest.QuestRepository:ExportQuestToCode(prepared.id)
        local offered = RPQuest.QuestRepository:ImportQuestFromCode(code, "@Master", {
            status = RPQuest.Constants.QUEST_STATUS.OFFERED,
            sourceMailId = "mail_map_1",
        })
        RPQuest.JournalTab:SelectQuest(offered.id)
        RPQuest.JournalTab:Refresh()
        AssertEqual(RPQuest.JournalTab.showOnMapKeybindButton:IsHidden(), false, "Show On Map visible for selected offered quest")
        AssertEqual(RPQuest.JournalTab.showOnMapDescriptor.visible(), true, "showOnMapDescriptor.visible true for selected offered quest")

        -- 3. Accept offered quest -> still visible immediately after accept
        local accepted = RPQuest.JournalTab:AcceptSelectedOfferedQuest()
        AssertEqual(accepted, true, "AcceptSelectedOfferedQuest succeeds")
        AssertEqual(RPQuest.JournalTab.showOnMapKeybindButton:IsHidden(), false, "Show On Map remains visible after accepting quest")
        AssertEqual(RPQuest.JournalTab.showOnMapDescriptor.visible(), true, "showOnMapDescriptor.visible remains true after accepting quest")

        -- 4. Quest with hideMapArea=true -> still visible when selected in DETAIL mode
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Cultista",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.3,
            targetY = 0.3,
        })
        RPQuest.QuestRepository:UpdateDraftFields({ hideMapArea = true })
        local hiddenAreaQuest = RPQuest.QuestRepository:SaveDraft("Misión Sin Área", "Área oculta.")
        RPQuest.JournalTab:SelectQuest(hiddenAreaQuest.id)
        RPQuest.JournalTab:Refresh()
        AssertEqual(RPQuest.JournalTab.showOnMapKeybindButton:IsHidden(), false, "Show On Map visible even when hideMapArea is true")
        AssertEqual(RPQuest.JournalTab.showOnMapDescriptor.visible(), true, "showOnMapDescriptor.visible true even when hideMapArea is true")

        -- 5. Callback invokes WorldMapArea:ShowQuestOnMap with selected quest
        local origShowQuestOnMap = RPQuest.WorldMapArea.ShowQuestOnMap
        local shownQuestId = nil
        RPQuest.WorldMapArea.ShowQuestOnMap = function(_, q)
            shownQuestId = q and q.id or nil
            return true
        end
        RPQuest.JournalTab.showOnMapDescriptor.callback()
        AssertEqual(shownQuestId, hiddenAreaQuest.id, "showOnMapDescriptor callback calls ShowQuestOnMap with selected quest")
        RPQuest.WorldMapArea.ShowQuestOnMap = origShowQuestOnMap

        -- 6. Editor mode -> hidden
        RPQuest.JournalTab:OpenCreateEditor()
        AssertEqual(RPQuest.JournalTab.showOnMapKeybindButton:IsHidden(), true, "Show On Map hidden in Editor mode")
        AssertEqual(RPQuest.JournalTab.showOnMapDescriptor.visible(), false, "showOnMapDescriptor.visible false in Editor mode")

        -- 7. Mail Send mode -> hidden
        RPQuest.JournalTab:SelectQuest(hiddenAreaQuest.id)
        RPQuest.JournalTab:OpenMailSendView()
        AssertEqual(RPQuest.JournalTab.showOnMapKeybindButton:IsHidden(), true, "Show On Map hidden in Mail Send mode")
        AssertEqual(RPQuest.JournalTab.showOnMapDescriptor.visible(), false, "showOnMapDescriptor.visible false in Mail Send mode")

        -- Restore detail mode
        RPQuest.JournalTab:SelectQuest(hiddenAreaQuest.id)
        RPQuest.JournalTab:Refresh()
        AssertEqual(RPQuest.JournalTab.showOnMapKeybindButton:IsHidden(), false, "Show On Map visible again when returning to Detail mode")
    end)

    RunTest("Journal UI: Optional target editor toggle, detail label, manual Complete button, and master report", function()
        RPQuest.QuestRepository:Initialize(RPQuest.QuestRepository:GetDefaults())
        RPQuest.JournalTab:Initialize()
        RPQuest.JournalTab:OpenCreateEditor()

        RPQuest.QuestRepository:SetDraftCapturedTarget({ targetName = "MainTarget", mapId = 1, zoneId = 2, mapName = "Auridon", targetX = 0.5, targetY = 0.5 })
        RPQuest.QuestRepository:SetDraftCapturedTarget({ targetName = "OptionalTarget", mapId = 1, zoneId = 2, mapName = "Auridon", targetX = 0.5, targetY = 0.5 })
        RPQuest.JournalTab.selectedTargetIndex = 2
        RPQuest.JournalTab:RefreshEditorPane()

        AssertEqual(RPQuest.JournalTab.btnTargetOptional:IsHidden(), false, "btnTargetOptional visible when targets exist")
        RPQuest.JournalTab.btnTargetOptional:GetHandler("OnClicked")()
        local draft = RPQuest.QuestRepository:GetDraft()
        AssertEqual(draft.targets[2].optional, true, "Clicking btnTargetOptional toggles optional=true on selected target")

        local prepared = RPQuest.QuestRepository:SaveDraft("UI Optional Quest", "Desc")
        local code = RPQuest.QuestRepository:ExportQuestToCode(prepared.id)
        local imported = RPQuest.QuestRepository:ImportQuestFromCode(code, "@Master")
        RPQuest.QuestRepository:SetActiveQuest(imported.id)
        RPQuest.JournalTab:SelectQuest(imported.id)
        RPQuest.JournalTab:Refresh()

        local objText = RPQuest.JournalTab.detailObjText:GetText()
        AssertTrue(objText:find("Optional", 1, true) ~= nil, "Detail objectives label optional target with (Optional)")
        AssertEqual(RPQuest.JournalTab.btnComplete:IsHidden(), true, "btnComplete hidden before mandatory target is done")

        RPQuest.QuestRepository:RecordTargetEliminated("MainTarget")
        RPQuest.JournalTab:Refresh()
        AssertEqual(RPQuest.JournalTab.btnComplete:IsHidden(), false, "btnComplete visible once mandatory target is done")

        RPQuest.JournalTab:OnCompleteQuestClicked()
        AssertEqual(imported.completed, true, "OnCompleteQuestClicked completes the quest")
        AssertEqual(RPQuest.JournalTab.btnComplete:IsHidden(), true, "btnComplete hidden after quest is completed")

        -- Master report shows optional target completion status
        imported.completed = true
        local compCode = RPQuest.QuestRepository:ExportCompletionCode(imported.id)
        local okVal, valRes = RPQuest.QuestRepository:ValidateResultCode(prepared.id, compCode)
        AssertEqual(okVal, true, "Prepared quest validates completion code")
        RPQuest.QuestRepository:RecordMailDelivery(prepared.id, "@Player", valRes)
        RPQuest.JournalTab:SelectQuest(prepared.id)
        RPQuest.JournalTab:Refresh()
        local statusText = RPQuest.JournalTab.detailStatus:GetText()
        AssertTrue(statusText:find("0/1", 1, true) ~= nil, "Prepared quest status shows 0/1 optional objectives completed")
    end)

end
