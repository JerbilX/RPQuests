-- ============================================================================
-- RPQuest Test Suite: ShareCodec & BinaryCodec Suites
-- ============================================================================
return function(T)
    local RunTest = T.RunTest
    local AssertEqual = T.AssertEqual
    local AssertTrue = T.AssertTrue
    local mockState = T.mockState

    RunTest("ShareCodec roundtrip preserves UTF-8, pipes, newlines and coordinates", function()
        local original = {
            title = "Caza en Auridon: El Traidor | Parte 1",
            description = "Busca al capitán cerca del muelle.\nNo tengas piedad con él.",
            targets = {
                { name = "Capitán Pirata", currentCount = 0, requiredCount = 3 },
                { name = "Contramaestre", currentCount = 0, requiredCount = 1 },
            },
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.4215,
            targetY = 0.6180,
            areaCenterX = 0.4510,
            areaCenterY = 0.5920,
            areaRadius = 0.0750,
        }

        local code, err = RPQuest.ShareCodec:EncodeQuest(original)
        AssertTrue(code ~= nil, "Code should be generated without error: " .. tostring(err))
        AssertTrue(string.sub(code, 1, 5) == "RPQ3:", "Code must start with RPQ3:")

        local decoded, decErr = RPQuest.ShareCodec:DecodeQuest(code)
        AssertTrue(decoded ~= nil, "Decode should succeed: " .. tostring(decErr))
        AssertEqual(decoded.title, original.title, "Title matches")
        AssertEqual(decoded.description, original.description, "Description with newline matches")
        AssertEqual(#decoded.targets, 2, "Decoded targets count matches")
        AssertEqual(decoded.targets[1].name, "Capitán Pirata", "Target 1 name matches")
        AssertEqual(decoded.targets[1].requiredCount, 3, "Target 1 required count matches")
        AssertEqual(decoded.targets[2].name, "Contramaestre", "Target 2 name matches")
        AssertEqual(decoded.mapId, 32, "MapId matches")
        AssertEqual(decoded.zoneId, 381, "ZoneId matches")
        AssertEqual(decoded.mapName, "Auridon", "MapName matches")
        AssertTrue(math.abs(decoded.targets[1].areaCenterX - original.areaCenterX) < 0.001, "AreaCenterX matches on target")
        AssertTrue(math.abs(decoded.targets[1].areaCenterY - original.areaCenterY) < 0.001, "AreaCenterY matches on target")
        AssertTrue(math.abs(decoded.targets[1].areaRadius - original.areaRadius) < 0.001, "AreaRadius matches on target")
    end)

    RunTest("ShareCodec rejects tampered or malformed codes", function()
        local validQuest = {
            title = "Test",
            description = "Desc",
            targets = {
                { name = "Goblin", currentCount = 0, requiredCount = 1 },
            },
            mapId = 10,
            zoneId = 20,
            mapName = "Glenumbra",
            targetX = 0.5,
            targetY = 0.5,
            areaCenterX = 0.52,
            areaCenterY = 0.48,
            areaRadius = 0.075,
        }
        local code = RPQuest.ShareCodec:EncodeQuest(validQuest)
        local tampered = code:gsub("^RPQ3:[0-9A-F][0-9A-F][0-9A-F][0-9A-F]:", "RPQ3:0000:")
        local res, tamperErr = RPQuest.ShareCodec:DecodeQuest(tampered)
        AssertEqual(res, nil, "Tampered checksum must fail")
        AssertEqual(tamperErr, "ERR_IMPORT_TRUNCATED_OR_CORRUPT", "Tampered checksum returns specific error key")

        local malformed, malformedErr = RPQuest.ShareCodec:DecodeQuest("INVALID_STRING")
        AssertEqual(malformed, nil, "Malformed string must fail")
        AssertEqual(malformedErr, "ERR_IMPORT_INVALID_FORMAT", "Malformed string returns format error key")

        local emptyRes, emptyErr = RPQuest.ShareCodec:DecodeQuest("   ")
        AssertEqual(emptyRes, nil, "Empty string must fail")
        AssertEqual(emptyErr, "ERR_IMPORT_EMPTY", "Empty string returns empty error key")

        local futureCode = code:gsub("^RPQ3:", "RPQ9:")
        local futureRes, futureErr = RPQuest.ShareCodec:DecodeQuest(futureCode)
        AssertEqual(futureRes, nil, "Unknown version prefix must fail")
        AssertEqual(futureErr, "ERR_IMPORT_UNSUPPORTED_VERSION", "Unknown version prefix returns version error key")

        validQuest.completed = true
        local compCode = RPQuest.ShareCodec:EncodeCompletion(validQuest, "Tester", 12345)
        AssertTrue(compCode ~= nil, "Completion code should be generated")
        local compRes, compErr = RPQuest.ShareCodec:DecodeQuest(compCode)
        AssertEqual(compRes, nil, "Completion code in quest importer must fail")
        AssertEqual(compErr, "ERR_IMPORT_NOT_QUEST_CODE", "Completion code returns not-quest-code error key")

        local importedBad, importedErr = RPQuest.QuestRepository:ImportQuestFromCode(futureCode)
        AssertEqual(importedBad, nil, "ImportQuestFromCode must fail on incompatible version")
        AssertEqual(importedErr, RPQuest.Locale:Get("ERR_IMPORT_UNSUPPORTED_VERSION"), "ImportQuestFromCode returns localized specific error")
    end)

    RunTest("ShareCodec rejects quests created in another client language", function()
        local prevLang = mockState.language
        mockState.language = "en"
        RPQuest.Locale:Initialize("en")
        RPQuest.QuestRepository:Initialize({})

        local enQuest = {
            title = "Wool Hunt",
            description = "Hunt sheep",
            targets = {
                { name = "Sheep", currentCount = 0, requiredCount = 1 },
            },
            mapId = 1,
            zoneId = 2,
            mapName = "Glenumbra",
            targetX = 0.5,
            targetY = 0.5,
            areaCenterX = 0.52,
            areaCenterY = 0.48,
            areaRadius = 0.075,
        }
        local enCode = RPQuest.ShareCodec:EncodeQuest(enQuest)
        AssertTrue(enCode ~= nil, "EncodeQuest must succeed in EN")

        -- Switch client to Spanish
        mockState.language = "es"
        RPQuest.Locale:Initialize("es")

        local decoded, errKey = RPQuest.ShareCodec:DecodeQuest(enCode)
        AssertEqual(decoded, nil, "DecodeQuest must reject quest from another language")
        AssertEqual(errKey, "ERR_IMPORT_LANGUAGE_MISMATCH", "DecodeQuest returns ERR_IMPORT_LANGUAGE_MISMATCH")

        local imported, importErr = RPQuest.QuestRepository:ImportQuestFromCode(enCode)
        AssertEqual(imported, nil, "ImportQuestFromCode must reject quest from another language")
        AssertEqual(importErr, RPQuest.Locale:Get("ERR_IMPORT_LANGUAGE_MISMATCH"), "ImportQuestFromCode returns localized Spanish mismatch error")

        -- Same language (ES -> ES) must succeed
        local esCode = RPQuest.ShareCodec:EncodeQuest(enQuest)
        local decodedEs, errEs = RPQuest.ShareCodec:DecodeQuest(esCode)
        AssertTrue(decodedEs ~= nil, "DecodeQuest must accept quest in same language")
        AssertEqual(errEs, nil, "No error when language matches")
        AssertEqual(decodedEs.language, "es", "Decoded quest preserves source language")

        -- Restore
        mockState.language = prevLang
        RPQuest.Locale:Initialize(prevLang)
    end)

    RunTest("RPQ3 compact codec: compression ratio, negative varints, Discord safety, corrupt inputs (Issue #100)", function()
        local complexQuest = {
            title = "La Conspiración de Auridon — Año Nuevo (Ñoño)",
            description = "Investiga las ruinas antiguas al norte de Vulkhel Guard. "
                .. "Los agentes del Veiled Heritance han estado reuniendo suministros y "
                .. "enviando mensajeros secretos entre los campamentos de la costa. "
                .. "Elimina a los exploradores en el puente y recoge las pistas ocultas.",
            clue = "Busca el sello roto junto al muelle de los contrabandistas.",
            completionMessage = "¡Misión completada! Regresa con el capitán para recibir tu recompensa.",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.432149,
            targetY = 0.678951,
            areaCenterX = 0.451249,
            areaCenterY = 0.654351,
            areaRadius = 0.075,
            recommendHideMapAreas = true,
            stealthMode = "optional",
            targets = {
                {
                    name = "Explorador del Velo",
                    requiredCount = 3,
                    areaCenterX = 0.451249,
                    areaCenterY = 0.654351,
                    areaRadius = 0.075,
                    zoneId = 381,
                    worldX = -123456,
                    worldZ = -78901,
                    radius = 1500,
                    locationRequired = true,
                    customMessageInLocation = "Has interceptado al explorador en el puente secreto.",
                },
                {
                    name = "Capitán Contrabandista",
                    requiredCount = 1,
                    areaCenterX = 0.451249,
                    areaCenterY = 0.654351,
                    areaRadius = 0.075,
                    locationRequired = false,
                    customMessage = "El capitán cae tras una breve escaramuza.",
                },
            },
            discoveries = {
                {
                    zoneId = 381,
                    worldX = -45000,
                    worldY = 1200,
                    worldZ = 98765,
                    mapId = 32,
                    x = 0.4123,
                    y = 0.6123,
                    radius = 1500,
                    message = "Notas huellas recientes que conducen hacia la cueva oculta.",
                },
                {
                    zoneId = 381,
                    worldX = -46000,
                    worldY = 1250,
                    worldZ = 99500,
                    mapId = 32,
                    x = 0.4223,
                    y = 0.6223,
                    radius = 800,
                    message = "Encuentras una carta cifrada con el emblema del Velo.",
                },
            },
            dialogues = {
                { npcName = "Tabernero Orin", zoneId = 381, response = "Los contrabandistas suelen reunirse al anochecer cerca del muelle." },
                { npcName = "Guardia Elara", zoneId = 381, response = "Ten cuidado, los exploradores vigilan el puente norte." },
            },
        }

        local rpq3 = RPQuest.ShareCodec:EncodeQuest(complexQuest)
        AssertTrue(type(rpq3) == "string" and rpq3:sub(1, 5) == "RPQ3:", "EncodeQuest emits RPQ3 prefix")

        -- Verify Discord-safe Base85 payload (no *, _, ~, `, |, >, <, \, :, or whitespace)
        local payload = rpq3:match("^RPQ3:[0-9A-F][0-9A-F][0-9A-F][0-9A-F]:(.+)$")
        AssertTrue(payload ~= nil and #payload > 0, "RPQ3 envelope matches RPQ3:<CRC16>:<PAYLOAD>")
        AssertEqual(payload:find("[*_~`|>\\:<%s]"), nil, "RPQ3 Base85 payload contains no Discord-unsafe or delimiter chars")

        -- Verify >= 45% length reduction vs RPQ2 on a medium/large quest
        local repeatedQuest = {
            title = "Patrulla del Velo en Auridon",
            description = string.rep("Los exploradores del Velo vigilan los caminos del norte de Auridon. ", 6),
            clue = "Busca los campamentos del Velo en la costa norte.",
            completionMessage = "Los campamentos del Velo han sido despejados.",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.5,
            targetY = 0.5,
            areaCenterX = 0.52,
            areaCenterY = 0.48,
            areaRadius = 0.075,
            targets = {
                { name = "Explorador del Velo", requiredCount = 3, zoneId = 381, worldX = 10000, worldZ = 20000, radius = 1500, locationRequired = true, customMessage = "Explorador del Velo eliminado en el campamento." },
                { name = "Guardia del Velo", requiredCount = 2, zoneId = 381, worldX = 10500, worldZ = 20500, radius = 1500, locationRequired = false, customMessage = "Guardia del Velo eliminado en el campamento." },
                { name = "Capitán del Velo", requiredCount = 1, zoneId = 381, worldX = 11000, worldZ = 21000, radius = 1500, locationRequired = true, customMessage = "Capitán del Velo eliminado en el campamento." },
            },
            discoveries = {
                { zoneId = 381, worldX = 10000, worldY = 100, worldZ = 20000, mapId = 32, x = 0.5, y = 0.5, radius = 1500, message = "Campamento norte descubierto." },
                { zoneId = 381, worldX = 11000, worldY = 100, worldZ = 21000, mapId = 32, x = 0.55, y = 0.55, radius = 1500, message = "Campamento sur descubierto." },
            },
        }
        local rpq3Rep = RPQuest.ShareCodec:EncodeQuest(repeatedQuest)
        -- Compute exact RPQ2 length for repeatedQuest (18-field pipe string * 4/3 Base64Url)
        local rpq2RawLen = #repeatedQuest.title + #repeatedQuest.description + #repeatedQuest.clue + #repeatedQuest.completionMessage
            + #repeatedQuest.mapName + 5 * 6 + 17 + 3 * 70 + 2 * 75
        local rpq2Len = 10 + math.ceil(rpq2RawLen * 4 / 3)
        local reduction = 1 - (#rpq3Rep / rpq2Len)
        AssertTrue(reduction >= 0.45, string.format("RPQ3 achieves >= 45%% reduction vs RPQ2 (actual: %.1f%%, len=%d vs rpq2=%d)", reduction * 100, #rpq3Rep, rpq2Len))

        -- Verify exact round-trip (coords <= 0.0001)
        local decoded, decErr = RPQuest.ShareCodec:DecodeQuest(rpq3)
        AssertTrue(decoded ~= nil, "RPQ3 decodes cleanly: " .. tostring(decErr))
        AssertEqual(decoded.title, complexQuest.title, "UTF-8 title preserved")
        AssertEqual(decoded.description, complexQuest.description, "UTF-8 description preserved")
        AssertEqual(decoded.clue, complexQuest.clue, "Clue preserved")
        AssertEqual(decoded.completionMessage, complexQuest.completionMessage, "Completion message preserved")
        AssertTrue(math.abs(decoded.targetX - complexQuest.targetX) <= 0.0001, "targetX uint16 precision <= 0.0001")
        AssertTrue(math.abs(decoded.targetY - complexQuest.targetY) <= 0.0001, "targetY uint16 precision <= 0.0001")
        AssertTrue(math.abs(decoded.targets[1].areaCenterX - complexQuest.areaCenterX) <= 0.0001, "areaCenterX uint16 precision <= 0.0001")
        AssertTrue(math.abs(decoded.targets[1].areaCenterY - complexQuest.areaCenterY) <= 0.0001, "areaCenterY uint16 precision <= 0.0001")
        AssertTrue(math.abs(decoded.targets[1].areaRadius - complexQuest.areaRadius) <= 0.0001, "areaRadius uint16 precision <= 0.0001")
        AssertEqual(decoded.recommendHideMapAreas, true, "recommendHideMapAreas preserved")
        AssertEqual(decoded.stealthMode, "optional", "stealthMode = optional preserved")
        AssertEqual(#decoded.targets, 2, "2 targets preserved")
        AssertEqual(decoded.targets[1].worldX, -123456, "Negative worldX preserved via ZigZag varint")
        AssertEqual(decoded.targets[1].worldZ, -78901, "Negative worldZ preserved via ZigZag varint")
        AssertEqual(decoded.targets[1].locationRequired, true, "Target locationRequired preserved")
        AssertEqual(decoded.targets[1].customMessageInLocation, complexQuest.targets[1].customMessageInLocation, "Target customMessageInLocation preserved")
        AssertEqual(decoded.targets[2].worldX, nil, "Target without location has nil worldX")
        AssertEqual(#decoded.discoveries, 2, "2 discoveries preserved")
        AssertEqual(decoded.discoveries[1].worldX, -45000, "Discovery negative worldX preserved")
        AssertEqual(#decoded.dialogues, 2, "2 dialogues preserved")

        -- Truncated/corrupted RPQ3 rejection
        local trunc = rpq3:sub(1, #rpq3 - 5)
        local tRes, tErr = RPQuest.ShareCodec:DecodeQuest(trunc)
        AssertEqual(tRes, nil, "Truncated RPQ3 rejected")
        AssertEqual(tErr, "ERR_IMPORT_TRUNCATED_OR_CORRUPT", "Truncated RPQ3 returns corrupt error")

        local badChar = "RPQ3:0000:INVALID*CHAR"
        local bRes, bErr = RPQuest.ShareCodec:DecodeQuest(badChar)
        AssertEqual(bRes, nil, "Invalid Base85 char rejected")
        AssertEqual(bErr, "ERR_IMPORT_TRUNCATED_OR_CORRUPT", "Invalid Base85 char returns corrupt error")

        -- ComputeQuestSignature remains deterministic across RPQ3
        local sig1 = RPQuest.ShareCodec:ComputeQuestSignature(complexQuest)
        local sig2 = RPQuest.ShareCodec:ComputeQuestSignature(decoded)
        AssertTrue(sig1 ~= nil and #sig1 == 8, "ComputeQuestSignature returns 8-char hex")
        AssertEqual(sig1, sig2, "ComputeQuestSignature matches between original and RPQ3-decoded quest")
        decoded.completed = true
        local compCode = RPQuest.ShareCodec:EncodeCompletion(decoded, "Player", 1000)
        AssertTrue(compCode ~= nil and compCode:sub(1, 6) == "RPQC1:", "RPQC1 completion code works for RPQ3-decoded quest")
        local okVal, valRes = RPQuest.ShareCodec:ValidateCompletionForQuest(complexQuest, compCode)
        AssertEqual(okVal, true, "Original quest validates RPQC1 from RPQ3-decoded quest: " .. tostring(valRes))
    end)

    RunTest("ShareCodec:DecodeQuest surfaces ERR_IMPORT_UNSUPPORTED_VERSION for future RPQ prefixes and JournalTab shows version", function()
        RPQuest.JournalTab:Initialize()
        AssertTrue(RPQuest.JournalTab.versionLabel ~= nil, "JournalTab creates versionLabel")
        AssertEqual(RPQuest.JournalTab.versionLabel:GetText(), "v" .. RPQuest.Constants.METADATA.VERSION, "versionLabel displays addon version")

        local dec1, err1 = RPQuest.ShareCodec:DecodeQuest("RPQ4:1234:abcd")
        AssertEqual(dec1, nil, "RPQ4 standard envelope rejected")
        AssertEqual(err1, "ERR_IMPORT_UNSUPPORTED_VERSION", "RPQ4 returns ERR_IMPORT_UNSUPPORTED_VERSION")

        local dec2, err2 = RPQuest.ShareCodec:DecodeQuest("RPQ99:future_format_payload")
        AssertEqual(dec2, nil, "RPQ99 arbitrary format rejected")
        AssertEqual(err2, "ERR_IMPORT_UNSUPPORTED_VERSION", "RPQ99 returns ERR_IMPORT_UNSUPPORTED_VERSION")

        local imp, impErr = RPQuest.QuestRepository:ImportQuestFromCode("RPQ4:1234:abcd")
        AssertEqual(imp, nil, "ImportQuestFromCode fails for RPQ4")
        AssertEqual(impErr, RPQuest.Locale:Get("ERR_IMPORT_UNSUPPORTED_VERSION"), "ImportQuestFromCode returns localized unsupported version error")
    end)

    RunTest("ShareCodec encodes/decodes optional targets in RPQ3 and optional completion mask in RPQC1", function()
        local quest = {
            title = "Optional Ops",
            description = "Eliminate leader, optionally scouts.",
            mapId = 1,
            zoneId = 2,
            mapName = "Glenumbra",
            targetX = 0.5,
            targetY = 0.5,
            areaCenterX = 0.5,
            areaCenterY = 0.5,
            areaRadius = 0.05,
            targets = {
                { name = "Captain", requiredCount = 1, currentCount = 1, optional = false, areaCenterX = 0.5, areaCenterY = 0.5, areaRadius = 0.05 },
                { name = "Scout", requiredCount = 1, currentCount = 1, optional = true, areaCenterX = 0.5, areaCenterY = 0.5, areaRadius = 0.05 },
                { name = "Lookout", requiredCount = 1, currentCount = 0, optional = true, areaCenterX = 0.5, areaCenterY = 0.5, areaRadius = 0.05 },
            },
            discoveries = {},
            dialogues = {},
        }
        local code, err = RPQuest.ShareCodec:EncodeQuest(quest)
        AssertTrue(code ~= nil and code:sub(1, 5) == "RPQ3:", "RPQ3 encodes quest with optional targets: " .. tostring(err))
        local decoded, decErr = RPQuest.ShareCodec:DecodeQuest(code)
        AssertTrue(decoded ~= nil, "RPQ3 decodes quest with optional targets: " .. tostring(decErr))
        AssertEqual(#decoded.targets, 3, "All 3 targets decoded")
        AssertEqual(decoded.targets[1].optional, false, "Target 1 optional is false")
        AssertEqual(decoded.targets[2].optional, true, "Target 2 optional is true")
        AssertEqual(decoded.targets[3].optional, true, "Target 3 optional is true")

        local sig1 = RPQuest.ShareCodec:ComputeQuestSignature(quest)
        local sig2 = RPQuest.ShareCodec:ComputeQuestSignature(decoded)
        AssertEqual(sig1, sig2, "Signature matches between original and decoded quest with optional targets")

        quest.completed = true
        local compCode = RPQuest.ShareCodec:EncodeCompletion(quest, "Hero", 5000)
        AssertTrue(compCode ~= nil, "EncodeCompletion succeeds")
        local okVal, valRes = RPQuest.ShareCodec:ValidateCompletionForQuest(quest, compCode)
        AssertEqual(okVal, true, "ValidateCompletionForQuest succeeds")
        AssertTrue(type(valRes.optionalTargets) == "table", "optionalTargets table present in decoded completion")
        AssertEqual(#valRes.optionalTargets, 2, "optionalTargets has 2 entries for 2 optional targets")
        AssertEqual(valRes.optionalTargets[1], true, "First optional target reported completed")
        AssertEqual(valRes.optionalTargets[2], false, "Second optional target reported incomplete")
    end)

    RunTest("ShareCodec: stealthMode disabled/optional/required round-trip with and without charNames/dialogues", function()
        local cases = {
            { mode = "disabled", withNames = false, withDialogues = false },
            { mode = "optional", withNames = false, withDialogues = false },
            { mode = "required", withNames = false, withDialogues = false },
            { mode = "required", withNames = true, withDialogues = false },
            { mode = "required", withNames = false, withDialogues = true },
            { mode = "required", withNames = true, withDialogues = true },
        }
        for _, c in ipairs(cases) do
            local q = {
                title = "Stealth " .. c.mode,
                description = "Test",
                mapId = 32,
                zoneId = 381,
                mapName = "Auridon",
                targetX = 0.5,
                targetY = 0.5,
                areaCenterX = 0.5,
                areaCenterY = 0.5,
                areaRadius = 0.075,
                stealthMode = c.mode,
                senderCharacterName = c.withNames and "SenderChar" or nil,
                recipientCharacterName = c.withNames and "RecipChar" or nil,
                targets = { { name = "Guard", requiredCount = 1 } },
                discoveries = {},
                dialogues = c.withDialogues and { { npcName = "Informant", zoneId = 381, response = "Be quiet.", clue = "Ask about the guard" } } or {},
            }
            local code, err = RPQuest.ShareCodec:EncodeQuest(q)
            AssertTrue(code ~= nil, "Encode succeeds for " .. c.mode .. ": " .. tostring(err))
            local decoded, decErr = RPQuest.ShareCodec:DecodeQuest(code)
            AssertTrue(decoded ~= nil, "Decode succeeds for " .. c.mode .. ": " .. tostring(decErr))
            AssertEqual(decoded.stealthMode, c.mode, "stealthMode preserved for " .. c.mode)
            if c.withNames then
                AssertEqual(decoded.senderCharacterName, "SenderChar", "senderCharacterName preserved")
                AssertEqual(decoded.recipientCharacterName, "RecipChar", "recipientCharacterName preserved")
            end
            if c.withDialogues then
                AssertEqual(#decoded.dialogues, 1, "Dialogue preserved")
                AssertEqual(decoded.dialogues[1].clue, "Ask about the guard", "Dialogue clue preserved")
            end
        end

        -- Signatures differ between disabled, optional, and required
        local baseQ = {
            title = "Sig Test", description = "D", mapId = 1, zoneId = 1, mapName = "Z",
            targetX = 0.5, targetY = 0.5, areaCenterX = 0.5, areaCenterY = 0.5, areaRadius = 0.075,
            targets = { { name = "T", requiredCount = 1 } }, discoveries = {}, dialogues = {},
            stealthMode = "disabled",
        }
        local sigDis = RPQuest.ShareCodec:ComputeQuestSignature(baseQ)
        baseQ.stealthMode = "optional"
        local sigOpt = RPQuest.ShareCodec:ComputeQuestSignature(baseQ)
        baseQ.stealthMode = "required"
        local sigReq = RPQuest.ShareCodec:ComputeQuestSignature(baseQ)
        AssertTrue(sigDis ~= sigOpt and sigOpt ~= sigReq and sigDis ~= sigReq, "Signatures distinguish disabled/optional/required")

        -- Legacy requireUndetected = true encodes/hashes identically to stealthMode = optional
        local legacyQ = {
            title = "Sig Test", description = "D", mapId = 1, zoneId = 1, mapName = "Z",
            targetX = 0.5, targetY = 0.5, areaCenterX = 0.5, areaCenterY = 0.5, areaRadius = 0.075,
            targets = { { name = "T", requiredCount = 1 } }, discoveries = {}, dialogues = {},
            requireUndetected = true,
        }
        AssertEqual(RPQuest.ShareCodec:ComputeQuestSignature(legacyQ), sigOpt, "Legacy requireUndetected = true matches optional signature")
    end)

    RunTest("Issue #277: ShareCodec per-target areas, 3-state messages, and backward-compatible RPQ3 decoding", function()
        local questV3 = {
            title = "Per-Target Areas",
            description = "Two distinct areas on one map",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.5,
            targetY = 0.5,
            recommendHideMapAreas = false,
            targets = {
                {
                    name = "Vanguard",
                    requiredCount = 2,
                    areaCenterX = 0.25,
                    areaCenterY = 0.35,
                    areaRadius = 0.070,
                    zoneId = 381,
                    worldX = 11000,
                    worldZ = 22000,
                    radius = 1200,
                    locationRequired = true,
                    customMessage = "Unused when locationRequired=true",
                    customMessageInLocation = "Struck down inside the outpost!",
                    customMessageOutsideLocation = "The vanguard escaped the outpost!",
                },
                {
                    name = "Courier",
                    requiredCount = 1,
                    areaCenterX = 0.75,
                    areaCenterY = 0.65,
                    areaRadius = 0.195,
                    locationRequired = false,
                    customMessage = "Courier intercepted anywhere!",
                },
            },
            discoveries = {},
            dialogues = {},
        }

        local code, err = RPQuest.ShareCodec:EncodeQuest(questV3)
        AssertTrue(code ~= nil and code:sub(1, 5) == "RPQ3:", "v3 quest encoded cleanly: " .. tostring(err))

        local decoded, decErr = RPQuest.ShareCodec:DecodeQuest(code)
        AssertTrue(decoded ~= nil, "v3 quest decoded cleanly: " .. tostring(decErr))
        AssertEqual(decoded.schemaVersion, 4, "Decoded quest has schemaVersion = 4")
        AssertEqual(decoded.recommendHideMapAreas, false, "recommendHideMapAreas = false preserved")
        AssertEqual(decoded.showSearchAreas, nil, "Local preference showSearchAreas never serialized")
        AssertEqual(decoded.showLocationAreas, nil, "Local preference showLocationAreas never serialized")
        AssertEqual(decoded.showDiscoveryAreas, nil, "Local preference showDiscoveryAreas never serialized")
        AssertEqual(#decoded.targets, 2, "2 targets decoded")

        AssertTrue(math.abs(decoded.targets[1].areaCenterX - 0.25) < 0.001, "Target 1 areaCenterX preserved")
        AssertTrue(math.abs(decoded.targets[1].areaCenterY - 0.35) < 0.001, "Target 1 areaCenterY preserved")
        AssertTrue(math.abs(decoded.targets[1].areaRadius - 0.070) < 0.001, "Target 1 areaRadius preserved")
        AssertEqual(decoded.targets[1].customMessageInLocation, "Struck down inside the outpost!", "Target 1 customMessageInLocation preserved")
        AssertEqual(decoded.targets[1].customMessageOutsideLocation, "The vanguard escaped the outpost!", "Target 1 customMessageOutsideLocation preserved")

        AssertTrue(math.abs(decoded.targets[2].areaCenterX - 0.75) < 0.001, "Target 2 areaCenterX preserved")
        AssertTrue(math.abs(decoded.targets[2].areaCenterY - 0.65) < 0.001, "Target 2 areaCenterY preserved")
        AssertTrue(math.abs(decoded.targets[2].areaRadius - 0.195) < 0.001, "Target 2 areaRadius preserved")
        AssertEqual(decoded.targets[2].customMessage, "Courier intercepted anywhere!", "Target 2 customMessage preserved")

        local sig1 = RPQuest.ShareCodec:ComputeQuestSignature(questV3)
        local sig2 = RPQuest.ShareCodec:ComputeQuestSignature(decoded)
        AssertEqual(sig1, sig2, "Quest signature matches between v3 original and decoded")

        -- Backward compatibility: older RPQ3 payload without per-target area bits (bits 16/32/64 = 0)
        local legacyV2Payload = {
            title = "Older RPQ3",
            description = "No per-target area bits",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.5,
            targetY = 0.5,
            areaCenterX = 0.42,
            areaCenterY = 0.58,
            areaRadius = 0.125,
            hideMapArea = true,
            targets = {
                { name = "LegacyGuard", requiredCount = 1 },
            },
            discoveries = {},
            dialogues = {},
        }
        local legacyCode = RPQuest.ShareCodec:EncodeQuest(legacyV2Payload)
        local legacyDecoded = RPQuest.ShareCodec:DecodeQuest(legacyCode)
        AssertTrue(legacyDecoded ~= nil, "Older RPQ3-style payload decodes cleanly")
        AssertEqual(legacyDecoded.schemaVersion, 4, "Decoded older RPQ3 payload upgraded to schema v4")
        AssertEqual(legacyDecoded.recommendHideMapAreas, true, "Older hideMapArea bit mapped to recommendHideMapAreas")
        AssertTrue(math.abs(legacyDecoded.targets[1].areaCenterX - 0.42) < 0.001, "Target inherits header areaCenterX")
        AssertTrue(math.abs(legacyDecoded.targets[1].areaCenterY - 0.58) < 0.001, "Target inherits header areaCenterY")
        AssertTrue(math.abs(legacyDecoded.targets[1].areaRadius - 0.125) < 0.001, "Target inherits header areaRadius")
    end)

    RunTest("Issue #255: ShareCodec EncodeFailure / DecodeCompletion / ValidateResultForQuest round-trip", function()
        local quest = {
            id = 55,
            title = "Stealth Contract",
            description = "Do not get caught",
            stealthMode = "required",
            wasDetected = true,
            failed = true,
            targets = { { name = "Guard", requiredCount = 1 } },
            discoveries = {},
            dialogues = {},
        }
        local failCode, err = RPQuest.ShareCodec:EncodeFailure(quest, "ShadowPlayer", 1700001234)
        AssertTrue(failCode ~= nil and failCode:sub(1, 6) == "RPQC1:", "EncodeFailure returns RPQC1 code: " .. tostring(err))

        local decoded, decErr = RPQuest.ShareCodec:DecodeCompletion(failCode)
        AssertTrue(decoded ~= nil, "DecodeCompletion decodes failure code: " .. tostring(decErr))
        AssertEqual(decoded.resultType, "failed", "resultType is 'failed'")
        AssertEqual(decoded.failed, true, "failed boolean is true")
        AssertEqual(decoded.completed, false, "completed boolean is false")
        AssertEqual(decoded.rejected, false, "rejected boolean is false")
        AssertEqual(decoded.accepted, false, "accepted boolean is false")
        AssertEqual(decoded.wasDetected, true, "wasDetected=true preserved for stealth failure")
        AssertEqual(decoded.characterName, "ShadowPlayer", "characterName preserved")

        local okRes, valRes = RPQuest.ShareCodec:ValidateResultForQuest(quest, failCode)
        AssertEqual(okRes, true, "ValidateResultForQuest accepts failure code")
        AssertEqual(valRes.resultType, "failed", "Validated resultType is 'failed'")

        local okComp, compErr = RPQuest.ShareCodec:ValidateCompletionForQuest(quest, failCode)
        AssertEqual(okComp, false, "ValidateCompletionForQuest rejects failure code")
        AssertEqual(compErr, "VALIDATE_ERR_NOT_COMPLETED", "ValidateCompletionForQuest returns VALIDATE_ERR_NOT_COMPLETED")

        -- Non-stealth failure omits wasDetected
        local locFailQuest = {
            id = 56,
            title = "Location Contract",
            stealthMode = "disabled",
            failed = true,
            targets = { { name = "Scout", requiredCount = 1 } },
            discoveries = {},
            dialogues = {},
        }
        local locCode = RPQuest.ShareCodec:EncodeFailure(locFailQuest, "RogueTwo", 1700002000)
        local locDecoded = RPQuest.ShareCodec:DecodeCompletion(locCode)
        AssertEqual(locDecoded.resultType, "failed", "Location failure resultType is 'failed'")
        AssertEqual(locDecoded.wasDetected, nil, "wasDetected is nil when stealthMode is disabled")
    end)

    RunTest("Issue #295: ShareCodec prunes inactive target elimination messages and round-trips 4/4/4 caps", function()
        local quest = {
            title = "Prune Test",
            description = "Verify inactive elimination messages are pruned",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targets = {
                {
                    name = "Target A",
                    requiredCount = 1,
                    zoneId = 381,
                    worldX = 1000,
                    worldZ = 2000,
                    radius = 1500,
                    locationRequired = false,
                    customMessage = "Active general msg",
                    customMessageInLocation = "Stale in-loc msg",
                    customMessageOutsideLocation = "Stale out-loc msg",
                },
                {
                    name = "Target B",
                    requiredCount = 2,
                    zoneId = 381,
                    worldX = 3000,
                    worldZ = 4000,
                    radius = 1500,
                    locationRequired = true,
                    customMessage = "Stale general msg",
                    customMessageInLocation = "Active in-loc msg",
                    customMessageOutsideLocation = "Active out-loc msg",
                },
                { name = "Target C", requiredCount = 1 },
                { name = "Target D", requiredCount = 1 },
            },
            discoveries = {
                { zoneId = 381, worldX = 100, worldY = 10, worldZ = 100, mapId = 32, x = 0.1, y = 0.1, radius = 800, message = "D1" },
                { zoneId = 381, worldX = 200, worldY = 10, worldZ = 200, mapId = 32, x = 0.2, y = 0.2, radius = 800, message = "D2" },
                { zoneId = 381, worldX = 300, worldY = 10, worldZ = 300, mapId = 32, x = 0.3, y = 0.3, radius = 800, message = "D3" },
                { zoneId = 381, worldX = 400, worldY = 10, worldZ = 400, mapId = 32, x = 0.4, y = 0.4, radius = 800, message = "D4" },
                { zoneId = 381, worldX = 500, worldY = 10, worldZ = 500, mapId = 32, x = 0.5, y = 0.5, radius = 800, message = "D5" },
                { zoneId = 381, worldX = 600, worldY = 10, worldZ = 600, mapId = 32, x = 0.6, y = 0.6, radius = 800, message = "D6" },
                { zoneId = 381, worldX = 700, worldY = 10, worldZ = 700, mapId = 32, x = 0.7, y = 0.7, radius = 800, message = "D7" },
                { zoneId = 381, worldX = 800, worldY = 10, worldZ = 800, mapId = 32, x = 0.8, y = 0.8, radius = 800, message = "D8" },
                { zoneId = 381, worldX = 900, worldY = 10, worldZ = 900, mapId = 32, x = 0.9, y = 0.9, radius = 800, message = "D9" },
                { zoneId = 381, worldX = 1000, worldY = 10, worldZ = 1000, mapId = 32, x = 0.95, y = 0.95, radius = 800, message = "D10" },
            },
            dialogues = {
                { npcName = "NPC 1", zoneId = 381, clue = "C1", response = "R1" },
                { npcName = "NPC 2", zoneId = 381, clue = "C2", response = "R2" },
                { npcName = "NPC 3", zoneId = 381, clue = "C3", response = "R3" },
                { npcName = "NPC 4", zoneId = 381, clue = "C4", response = "R4" },
            },
        }

        local code = RPQuest.ShareCodec:EncodeQuest(quest)
        AssertTrue(code ~= nil and code:sub(1, 5) == "RPQ3:", "Max-cap quest encodes to RPQ3")
        local decoded = RPQuest.ShareCodec:DecodeQuest(code)
        AssertTrue(decoded ~= nil, "Max-cap quest decodes cleanly")
        AssertEqual(#decoded.targets, 4, "4 targets round-trip")
        AssertEqual(#decoded.discoveries, 10, "10 discoveries round-trip")
        AssertEqual(#decoded.dialogues, 4, "4 dialogues round-trip")

        AssertEqual(decoded.targets[1].customMessage, "Active general msg", "Target A keeps active customMessage")
        AssertEqual(decoded.targets[1].customMessageInLocation, "", "Target A prunes inactive customMessageInLocation")
        AssertEqual(decoded.targets[1].customMessageOutsideLocation, "", "Target A prunes inactive customMessageOutsideLocation")

        AssertEqual(decoded.targets[2].customMessage, "", "Target B prunes inactive customMessage")
        AssertEqual(decoded.targets[2].customMessageInLocation, "Active in-loc msg", "Target B keeps active customMessageInLocation")
        AssertEqual(decoded.targets[2].customMessageOutsideLocation, "Active out-loc msg", "Target B keeps active customMessageOutsideLocation")
    end)

end
