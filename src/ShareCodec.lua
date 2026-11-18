-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.ShareCodec = {}
local ShareCodec = Addon.ShareCodec

local B64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local B64_LOOKUP = {}
for i = 1, #B64_ALPHABET do
    B64_LOOKUP[string.sub(B64_ALPHABET, i, i)] = i - 1
end

local function EscapeField(str)
    if str == nil then return "" end
    local s = tostring(str)
    s = s:gsub("%%", "%%25")
    s = s:gsub("|", "%%7C")
    s = s:gsub("\r", "")
    s = s:gsub("\n", "%%0A")
    return s
end

local function UnescapeField(str)
    if str == nil then return "" end
    local s = tostring(str)
    s = s:gsub("%%0A", "\n")
    s = s:gsub("%%7C", "|")
    s = s:gsub("%%25", "%%")
    return s
end

local function ComputeChecksum16(data)
    local sum1 = 0x5A
    local sum2 = 0xA5
    for i = 1, #data do
        local b = string.byte(data, i)
        sum1 = (sum1 + b) % 255
        sum2 = (sum2 + sum1) % 255
    end
    local combined = (sum2 * 256) + sum1
    return string.format("%04X", combined)
end

local function Base64UrlEncode(input)
    local out = {}
    local len = #input
    local i = 1
    while i <= len do
        local b1 = string.byte(input, i) or 0
        local b2 = string.byte(input, i + 1)
        local b3 = string.byte(input, i + 2)

        local n = (b1 * 65536) + ((b2 or 0) * 256) + (b3 or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64

        table.insert(out, string.sub(B64_ALPHABET, c1 + 1, c1 + 1))
        table.insert(out, string.sub(B64_ALPHABET, c2 + 1, c2 + 1))
        if b2 then
            table.insert(out, string.sub(B64_ALPHABET, c3 + 1, c3 + 1))
        end
        if b3 then
            table.insert(out, string.sub(B64_ALPHABET, c4 + 1, c4 + 1))
        end

        i = i + 3
    end
    return table.concat(out)
end

local function Base64UrlDecode(encoded)
    if type(encoded) ~= "string" or encoded == "" then
        return nil
    end

    local out = {}
    local len = #encoded
    local i = 1
    while i <= len do
        local ch1 = string.sub(encoded, i, i)
        local ch2 = string.sub(encoded, i + 1, i + 1)
        local ch3 = (i + 2 <= len) and string.sub(encoded, i + 2, i + 2) or nil
        local ch4 = (i + 3 <= len) and string.sub(encoded, i + 3, i + 3) or nil

        local v1 = B64_LOOKUP[ch1]
        local v2 = B64_LOOKUP[ch2]
        local v3 = ch3 and B64_LOOKUP[ch3] or 0
        local v4 = ch4 and B64_LOOKUP[ch4] or 0

        if v1 == nil or v2 == nil or (ch3 and B64_LOOKUP[ch3] == nil) or (ch4 and B64_LOOKUP[ch4] == nil) then
            return nil
        end

        local n = (v1 * 262144) + (v2 * 4096) + (v3 * 64) + v4
        local b1 = math.floor(n / 65536) % 256
        local b2 = math.floor(n / 256) % 256
        local b3 = n % 256

        table.insert(out, string.char(b1))
        if ch3 then
            table.insert(out, string.char(b2))
        end
        if ch4 then
            table.insert(out, string.char(b3))
        end

        i = i + 4
    end

    return table.concat(out)
end

local function SplitByPipe(raw)
    local fields = {}
    local startIdx = 1
    while true do
        local pos = string.find(raw, "|", startIdx, true)
        if not pos then
            table.insert(fields, string.sub(raw, startIdx))
            break
        end
        table.insert(fields, string.sub(raw, startIdx, pos - 1))
        startIdx = pos + 1
    end
    return fields
end

function ShareCodec:EncodeQuest(quest)
    if type(quest) ~= "table" or not quest.targetName or quest.targetName == "" then
        return nil, "Invalid quest table"
    end

    local prefix = (Addon.Constants and Addon.Constants.SHARE_CODEC and Addon.Constants.SHARE_CODEC.PREFIX) or "RPQ1"
    local fields = {
        EscapeField(quest.title or ""),
        EscapeField(quest.description or ""),
        EscapeField(quest.targetName or ""),
        tostring(math.max(1, math.floor(tonumber(quest.requiredCount) or 1))),
        tostring(math.floor(tonumber(quest.mapId) or 0)),
        tostring(math.floor(tonumber(quest.zoneId) or 0)),
        EscapeField(quest.mapName or ""),
        string.format("%.4f", tonumber(quest.targetX) or 0.5),
        string.format("%.4f", tonumber(quest.targetY) or 0.5),
        string.format("%.4f", tonumber(quest.areaCenterX) or 0.5),
        string.format("%.4f", tonumber(quest.areaCenterY) or 0.5),
        string.format("%.4f", tonumber(quest.areaRadius) or 0.075),
    }

    local rawPayload = table.concat(fields, "|")
    local checksum = ComputeChecksum16(rawPayload)
    local encodedPayload = Base64UrlEncode(rawPayload)

    return string.format("%s:%s:%s", prefix, checksum, encodedPayload)
end

function ShareCodec:DecodeQuest(codeString)
    if type(codeString) ~= "string" then
        return nil, "Code must be a string"
    end

    local trimmed = codeString:gsub("^%s+", ""):gsub("%s+$", "")
    local prefix = (Addon.Constants and Addon.Constants.SHARE_CODEC and Addon.Constants.SHARE_CODEC.PREFIX) or "RPQ1"

    local pfx, checksum, encodedPayload = string.match(trimmed, "^([A-Z0-9]+):([0-9A-Fa-f]+):([A-Za-z0-9%-_]+)$")
    if not pfx or pfx ~= prefix or not checksum or #checksum ~= 4 or not encodedPayload then
        return nil, "Invalid code format"
    end

    local rawPayload = Base64UrlDecode(encodedPayload)
    if not rawPayload then
        return nil, "Corrupted base64 payload"
    end

    local expectedChecksum = ComputeChecksum16(rawPayload)
    if checksum:upper() ~= expectedChecksum:upper() then
        return nil, "Checksum mismatch"
    end

    local fields = SplitByPipe(rawPayload)
    if #fields < 12 then
        return nil, "Incomplete quest payload"
    end

    local title = UnescapeField(fields[1])
    local description = UnescapeField(fields[2])
    local targetName = UnescapeField(fields[3])
    local requiredCount = tonumber(fields[4])
    local mapId = tonumber(fields[5])
    local zoneId = tonumber(fields[6])
    local mapName = UnescapeField(fields[7])
    local targetX = tonumber(fields[8])
    local targetY = tonumber(fields[9])
    local areaCenterX = tonumber(fields[10])
    local areaCenterY = tonumber(fields[11])
    local areaRadius = tonumber(fields[12])

    if not targetName or targetName == "" or not requiredCount or requiredCount < 1 then
        return nil, "Invalid target data in code"
    end

    if not areaCenterX or not areaCenterY or not areaRadius or areaRadius <= 0 then
        return nil, "Invalid area coordinates in code"
    end

    return {
        title = title,
        description = description,
        targetName = targetName,
        requiredCount = math.floor(requiredCount),
        mapId = math.floor(mapId or 0),
        zoneId = math.floor(zoneId or 0),
        mapName = mapName,
        targetX = targetX or areaCenterX,
        targetY = targetY or areaCenterY,
        areaCenterX = areaCenterX,
        areaCenterY = areaCenterY,
        areaRadius = areaRadius,
    }
end
