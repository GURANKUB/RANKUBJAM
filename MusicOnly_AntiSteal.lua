--[[
    ═══════════════════════════════════════════════════════════
     MUSIC ONLY + ANTI-STEAL  (Standalone)
     - RGB UI / Mobile Drag
     - ระบบเปิดเพลง + กันดัก (URI Strengthened)
     - Bait ID: 122657934666702  →  "กันเจาะกากๆรัน"
    ═══════════════════════════════════════════════════════════
]]

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService      = game:GetService("SoundService")
local MarketplaceService= game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

local gethui = gethui or function()
    return game:GetService("CoreGui")
end

local GuiParent = (function()
    local ok, res = pcall(gethui)
    if ok and res then return res end
    return LocalPlayer:WaitForChild("PlayerGui")
end)()

-- ล้างของเก่า
for _, name in ipairs({"MusicOnlyRoot", "MusicOnlyToggle"}) do
    local old = GuiParent:FindFirstChild(name)
    if old then old:Destroy() end
end

--------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------
local BAIT_ID          = "122657934666702"   -- กันเจาะกากๆรัน
local ANTI_STEAL_ON    = true
local CURRENT_MODE     = "URI"               -- "URI" | "DIGIT"
local SELECTED_DEVICE  = "Boombox"
local CURRENT_AUDIO_ID = ""
local MUSIC_RESET_HOLD = 0.65

local DEVICES = {
    "Boombox",
    "Skateboard",
    "Hoverboard",
    "PogoStick",
    "Sled",
    "CarrotPogoStick",
    "PinkScooter",
    "BlueScooter",
}

--------------------------------------------------------------------
-- REMOTES (Brookhaven-style)
--------------------------------------------------------------------
local function findRemotes()
    local folder = ReplicatedStorage:FindFirstChild("RE") or ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not folder then
        for _, v in ipairs(ReplicatedStorage:GetChildren()) do
            if v:IsA("Folder") and (v:FindFirstChild("PlayerToolEvent") or v:FindFirstChild("PlayerScooterEvent")) then
                folder = v
                break
            end
        end
    end
    local toolEv, scooterEv
    if folder then
        toolEv    = folder:FindFirstChild("PlayerToolEvent")
        scooterEv = folder:FindFirstChild("PlayerScooterEvent")
            or folder:FindFirstChild("1NoMoto1rVehicle1s")
            or folder:FindFirstChild("1NoMo1torVeh1icle1s")
    end
    return toolEv, scooterEv
end

local ToolEvent, ScooterEvent = findRemotes()

--------------------------------------------------------------------
-- ANTI-STEAL ENGINE (Strengthened)
--------------------------------------------------------------------
local GARBAGE_KEYS = {
    "real_id","true_id","actual_id","play_id","main_id","raw_id","clean_id","source_id",
    "id_real","id_true","id_main","id_play","id_0","id_1","id_stream","id_override",
    "sound_id","asset_id","audio_id","music_id","track_id","stream_id","clip_id","song_id",
}

local ALPHA_NOISE = {
    "SoundService_Stream_Buffer_Init",
    "AudioChannel_Replication_Sync",
    "AssetDelivery_ContentProvider_Load",
    "Waveform_Decoder_Chunk_Verify",
    "SpatialVoice_Emitter_Transform",
    "Equalizer_Filter_Bypass_State",
}

local HEX = "0123456789ABCDEF"
local ZWS = string.char(226, 128, 139)

local function encodeSpaceFractured(idStr)
    local s = tostring(idStr)
    local out = {}
    for i = 1, #s do
        local b = string.byte(s, i)
        local hi = math.floor(b / 16) + 1
        local lo = (b % 16) + 1
        local h1 = string.sub(HEX, hi, hi)
        local h2 = string.sub(HEX, lo, lo)
        local spA = string.rep(" ", math.random(0, 2))
        local spB = string.rep(" ", math.random(1, 2))
        local spC = string.rep(" ", math.random(0, 2))
        if math.random(1, 4) == 1 and b >= 48 and b <= 57 then
            table.insert(out, " " .. string.char(b) .. " ")
        else
            table.insert(out, spA .. "%" .. spB .. h1 .. spC .. h2)
        end
    end
    return table.concat(out)
end

local function randomGarbageNumber(excludeId)
    local mode = math.random(1, 8)
    local c
    if mode <= 2 then
        c = tostring(math.random(1000000000, 1999999999))
    elseif mode <= 4 then
        c = tostring(math.random(10500, 13999)) .. tostring(math.random(10000, 99999)) .. tostring(math.random(10000, 99999))
    elseif mode <= 6 then
        c = tostring(math.random(110, 989)) .. tostring(math.random(100000, 999999))
    else
        local base = tostring(excludeId or "1848354536")
        local t = {}
        for i = 1, #base do
            if math.random(1, 3) == 1 then
                t[i] = tostring(math.random(0, 9))
            else
                t[i] = string.sub(base, i, i)
            end
        end
        c = table.concat(t)
    end
    if c == tostring(excludeId) then c = c .. tostring(math.random(1, 9)) end
    return c
end

local function buildFakeKey(excludeId)
    local key = GARBAGE_KEYS[math.random(1, #GARBAGE_KEYS)]
    local bait = randomGarbageNumber(excludeId)
    return "&" .. key .. "=" .. encodeSpaceFractured(bait) .. "&%00"
end

local function buildPoisoned(excludeId, forced)
    local bait = forced or randomGarbageNumber(excludeId)
    local prefixes = {
        "& % 6 9 % 6 4 = ",
        "&id=",
        "& % 6 9 d = ",
        "& i d = ",
        "&%69%64=",
    }
    local pfx = prefixes[math.random(1, #prefixes)]
    return pfx .. encodeSpaceFractured(bait) .. "&%00"
end

local function buildUriPayload(rawId)
    local cleanId = tostring(rawId):match("%d+") or tostring(rawId)
    _G.MusicAntiRound = (_G.MusicAntiRound or 0) + 1
    local round = _G.MusicAntiRound

    local lines = {}
    local totalLines = math.random(145, 175) + math.min((round - 1) * 18, 160)

    -- Lead bait (กันเจาะกากๆรัน) — หลายชั้น
    table.insert(lines, "%E2%80%AE" .. BAIT_ID .. "&lloyd_auth=1&%00&" .. buildFakeKey(cleanId))
    table.insert(lines, buildPoisoned(cleanId, BAIT_ID) .. buildFakeKey(cleanId))
    table.insert(lines, BAIT_ID .. "&%00&" .. buildPoisoned(cleanId))

    -- Header
    table.insert(lines, "; ╔══ กันเจาะกากๆรัน // ROUND-" .. string.format("%04d", round) .. " ══╗")
    table.insert(lines, "; ROUND_SALT=" .. randomGarbageNumber(cleanId) .. "&%00" .. buildFakeKey(cleanId))

    -- ตำแหน่งเพลงจริง
    local chameleon = ((round + math.random(1, 3)) % 4) + 1
    local realIdx
    if chameleon == 1 then
        realIdx = math.random(math.floor(totalLines * 0.12), math.floor(totalLines * 0.28))
    elseif chameleon == 2 then
        realIdx = math.random(math.floor(totalLines * 0.74), math.floor(totalLines * 0.90))
    elseif chameleon == 3 then
        realIdx = math.random(math.floor(totalLines * 0.30), math.floor(totalLines * 0.70))
    else
        realIdx = math.random(math.floor(totalLines * 0.40), math.floor(totalLines * 0.60))
    end

    local keys = {"&id=", "& % 6 9 % 6 4 = ", "&id = ", "& %69%64="}

    for i = 1, totalLines do
        if i == realIdx then
            -- Deep Sandwich รอบเพลงจริง
            local realKey = keys[math.random(1, #keys)]
            local zeros = encodeSpaceFractured(string.rep("0", math.random(3, 7)))
            local before = buildFakeKey(cleanId) .. buildPoisoned(cleanId) .. buildFakeKey(cleanId)
            local real   = realKey .. zeros .. encodeSpaceFractured(cleanId) .. "&%00"
            local after  = buildPoisoned(cleanId) .. buildFakeKey(cleanId) .. buildPoisoned(cleanId)
            table.insert(lines, "%E2%80%AE" .. before .. real .. after)
        else
            local segs = {}
            for _ = 1, math.random(2, 4) do
                if math.random(1, 100) <= 55 then
                    table.insert(segs, buildPoisoned(cleanId, math.random(1, 5) == 1 and BAIT_ID or nil))
                else
                    table.insert(segs, buildFakeKey(cleanId))
                end
            end
            table.insert(lines, "%E2%80%AE" .. table.concat(segs, ""))
        end
    end

    -- Tail flood
    for _ = 1, math.random(22, 34) do
        table.insert(lines, "%E2%80%AE" .. buildPoisoned(cleanId) .. buildFakeKey(cleanId) .. buildPoisoned(cleanId) .. buildFakeKey(cleanId))
    end
    for _ = 1, math.random(3, 6) do
        table.insert(lines, "%E2%80%AE" .. buildPoisoned(cleanId, BAIT_ID) .. buildFakeKey(cleanId))
    end

    return table.concat(lines, "\r\n")
end

local function buildDigitPayload(rawId)
    local cleanId = tostring(rawId):match("%d+") or tostring(rawId)
    local chunks = {}

    -- bait นำ
    for bi = 1, #BAIT_ID do
        local d = string.sub(BAIT_ID, bi, bi)
        local nA = ALPHA_NOISE[math.random(1, #ALPHA_NOISE)]
        local nB = ALPHA_NOISE[math.random(1, #ALPHA_NOISE)]
        table.insert(chunks, nA .. "::[" .. d .. "]::" .. nB)
    end
    for _ = 1, math.random(6, 11) do
        local nA = ALPHA_NOISE[math.random(1, #ALPHA_NOISE)]
        local nB = ALPHA_NOISE[math.random(1, #ALPHA_NOISE)]
        table.insert(chunks, nA .. "::[" .. tostring(math.random(0, 9)) .. "]::" .. nB)
    end
    for i = 1, #cleanId do
        local digit = string.sub(cleanId, i, i)
        local nA = ALPHA_NOISE[math.random(1, #ALPHA_NOISE)]
        local nB = ALPHA_NOISE[math.random(1, #ALPHA_NOISE)]
        local nC = ALPHA_NOISE[math.random(1, #ALPHA_NOISE)]
        table.insert(chunks, nA .. "::" .. nC .. "::[" .. digit .. "]::" .. nB)
    end
    for _ = 1, math.random(4, 8) do
        local nA = ALPHA_NOISE[math.random(1, #ALPHA_NOISE)]
        local nB = ALPHA_NOISE[math.random(1, #ALPHA_NOISE)]
        table.insert(chunks, nA .. "::[" .. tostring(math.random(0, 9)) .. "]::" .. nB)
    end
    return table.concat(chunks, "\n")
end

local function buildAntiStealPayload(rawId)
    if CURRENT_MODE == "DIGIT" then
        return buildDigitPayload(rawId)
    end
    return buildUriPayload(rawId)
end

local function cleanAudioId(value)
    local text = tostring(value or ""):match("^%s*(.-)%s*$") or ""
    local id = text:match("rbxassetid://(%d+)")
        or text:match("[?&]id=(%d+)")
        or text:match("library/(%d+)")
        or text:match("(%d+)")
    return id or ""
end

--------------------------------------------------------------------
-- PLAY / STOP LOGIC
--------------------------------------------------------------------
local MUSIC_RESET_AUDIO_ID = "84899763517255"

local function refreshRemotes()
    ToolEvent, ScooterEvent = findRemotes()
end

local function flushServerMusicReset()
    refreshRemotes()
    pcall(function()
        if ToolEvent then
            ToolEvent:FireServer("ToolMusicStop", "", nil)
            ToolEvent:FireServer("ToolMusicText", MUSIC_RESET_AUDIO_ID)
            ToolEvent:FireServer("ToolMusic", MUSIC_RESET_AUDIO_ID, 1)
            ToolEvent:FireServer("ToolMusicPlay", "", nil)
        end
    end)
    pcall(function()
        if ScooterEvent then
            ScooterEvent:FireServer("PickingScooterMusicStop", "", nil)
            ScooterEvent:FireServer("PickingScooterMusicText", MUSIC_RESET_AUDIO_ID)
            ScooterEvent:FireServer("PickingScooterMusic", MUSIC_RESET_AUDIO_ID, 1)
            ScooterEvent:FireServer("PickingScooterMusicPlay", "", nil)
        end
    end)
end

-- ID แบบสั้นที่ยังเล่นได้ แต่ไม่ส่งเลขเปล่าให้สคริปต์ดัก
local function buildPlayableMaskedId(cleanId)
    local fractured = encodeSpaceFractured(cleanId)
    -- bait นำหน้า + id แบบ space-fracture + ปิดท้าย
    return BAIT_ID .. "&id=" .. fractured .. "&%00"
end

-- ToolMusicText = กันดักยาว, ToolMusic = masked (ไม่ส่งเลขตรงๆ)
local function serverPlayFromStart(payload, cleanedPlain)
    refreshRemotes()
    local masked = buildPlayableMaskedId(cleanedPlain)
    pcall(function()
        if ToolEvent then
            ToolEvent:FireServer("ToolMusicText", payload, nil, true)
            ToolEvent:FireServer("ToolMusic", masked, 1)
            ToolEvent:FireServer("ToolMusicPlay", "", nil)
        end
    end)
    pcall(function()
        if ScooterEvent then
            ScooterEvent:FireServer("PickingScooterMusicText", payload, nil, true)
            ScooterEvent:FireServer("PickingScooterMusic", masked, 1)
            ScooterEvent:FireServer("PickingScooterMusicPlay", "", nil)
        end
    end)
end

local function forceLocalSoundRestart(snd, expectedUri)
    if not snd then return end
    pcall(function()
        snd:Stop()
        snd.TimePosition = 0
        snd.SoundId = expectedUri
        snd.Looped = true
        if snd.Volume <= 0.05 then snd.Volume = 1 end
        snd:Play()
        snd.TimePosition = 0
    end)
end

local function stopMusic()
    flushServerMusicReset()
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("Sound") and (d.Name == "PlayersChoice" or d.Name == "MusicOnlyLocalSound") then
                d:Stop()
                if d.Name == "MusicOnlyLocalSound" then
                    d:Destroy()
                else
                    d.SoundId = ""
                end
            end
        end
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then
            for _, d in ipairs(backpack:GetDescendants()) do
                if d:IsA("Sound") and d.Name == "PlayersChoice" then
                    d:Stop()
                    d.SoundId = ""
                end
            end
        end
    end)
end

local function equipBoombox()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local char = LocalPlayer.Character
    if not backpack or not char then return nil end

    local tool = char:FindFirstChild("Boombox") or backpack:FindFirstChild("Boombox")
    if not tool then
        -- ลองชื่ออื่นที่แมพนิยมใช้
        for _, name in ipairs({"Super Boombox", "BoomBox", "Radio", "Boombox "}) do
            tool = char:FindFirstChild(name) or backpack:FindFirstChild(name)
            if tool then break end
        end
    end
    if tool and tool.Parent == backpack then
        pcall(function() tool.Parent = char end)
    end
    return tool
end

local function playMusic(audioId)
    local cleaned = cleanAudioId(audioId or CURRENT_AUDIO_ID)
    if cleaned == "" then return false, "กรุณาใส่ Audio ID" end
    CURRENT_AUDIO_ID = cleaned

    refreshRemotes()
    if not ToolEvent and not ScooterEvent then
        return false, "ไม่พบ Remote เพลง (Brookhaven) — ลองถือ Boombox แล้วกดใหม่"
    end

    local payload
    if ANTI_STEAL_ON then
        payload = buildAntiStealPayload(cleaned)
    else
        payload = cleaned
    end

    local localUri = "rbxassetid://" .. cleaned

    -- เคลียร์บนเซิร์ฟก่อน แล้วค่อยยิงเพลง (ให้ได้ยินตั้งแต่ต้น)
    flushServerMusicReset()
    task.wait(MUSIC_RESET_HOLD)
    serverPlayFromStart(payload, cleaned)

    task.spawn(function()
        task.wait(0.25)
        local tool = equipBoombox()
        local snd = tool and tool:FindFirstChild("PlayersChoice", true)

        if not snd then
            local char = LocalPlayer.Character
            if char then
                for _, d in ipairs(char:GetDescendants()) do
                    if d:IsA("Sound") and d.Name == "PlayersChoice" then
                        snd = d
                        break
                    end
                end
                if not snd then
                    local nm = char:FindFirstChild("NoMotorVehicleModel")
                    snd = nm and nm:FindFirstChild("PlayersChoice", true)
                end
            end
        end

        if snd then
            forceLocalSoundRestart(snd, localUri)
            task.wait(0.2)
            forceLocalSoundRestart(snd, localUri)
        else
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local old = hrp:FindFirstChild("MusicOnlyLocalSound")
                if old then old:Destroy() end
                local s = Instance.new("Sound")
                s.Name = "MusicOnlyLocalSound"
                s.SoundId = localUri
                s.Volume = 1
                s.Looped = true
                s.Parent = hrp
                s:Play()
            end
        end
    end)

    return true, cleaned
end

--------------------------------------------------------------------
-- UI (RGB + Mobile Drag)
--------------------------------------------------------------------
local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 10)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(255, 255, 255)
    s.Thickness = thickness or 1.2
    s.Transparency = 0.35
    s.Parent = parent
    return s
end

local function pad(parent, t, b, l, r)
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, t or 8)
    p.PaddingBottom = UDim.new(0, b or 8)
    p.PaddingLeft = UDim.new(0, l or 10)
    p.PaddingRight = UDim.new(0, r or 10)
    p.Parent = parent
    return p
end

local Root = Instance.new("ScreenGui")
Root.Name = "MusicOnlyRoot"
Root.ResetOnSpawn = false
Root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Root.Parent = GuiParent

-- Floating toggle (mobile)
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "MusicOnlyToggle"
ToggleBtn.Size = UDim2.new(0, 52, 0, 52)
ToggleBtn.Position = UDim2.new(0, 16, 0.55, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
ToggleBtn.Text = "♪"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 22
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.AutoButtonColor = false
ToggleBtn.Parent = Root
corner(ToggleBtn, 14)
stroke(ToggleBtn, Color3.fromRGB(255, 80, 200), 1.5)

-- Main Window
local Win = Instance.new("Frame")
Win.Name = "Window"
Win.Size = UDim2.new(0, isMobile and 320 or 360, 0, isMobile and 420 or 460)
Win.Position = UDim2.new(0.5, -(isMobile and 160 or 180), 0.5, -(isMobile and 210 or 230))
Win.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
Win.BackgroundTransparency = 0.08
Win.Active = true
Win.Parent = Root
corner(Win, 16)
stroke(Win, Color3.fromRGB(255, 255, 255), 1.2)

local WinGrad = Instance.new("UIGradient")
WinGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 120)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 120, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 255, 180)),
})
WinGrad.Rotation = 45
WinGrad.Parent = Win

-- ใช้ overlay ทับ gradient เพื่อไม่ให้สีฉูด
local WinInner = Instance.new("Frame")
WinInner.Size = UDim2.new(1, -2, 1, -2)
WinInner.Position = UDim2.new(0, 1, 0, 1)
WinInner.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
WinInner.BackgroundTransparency = 0.05
WinInner.Parent = Win
corner(WinInner, 15)

-- Title bar (drag handle)
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 44)
TitleBar.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
TitleBar.BackgroundTransparency = 0.2
TitleBar.Parent = WinInner
corner(TitleBar, 15)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -50, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "♪  Music Only  ·  กันเจาะกากๆรัน"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 15
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -38, 0.5, -16)
CloseBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 28)
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(255, 120, 140)
CloseBtn.TextSize = 20
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = TitleBar
corner(CloseBtn, 8)

-- Content
local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -16, 1, -56)
Content.Position = UDim2.new(0, 8, 0, 48)
Content.BackgroundTransparency = 1
Content.ScrollBarThickness = 3
Content.ScrollBarImageColor3 = Color3.fromRGB(255, 100, 180)
Content.CanvasSize = UDim2.new(0, 0, 0, 520)
Content.Parent = WinInner

local List = Instance.new("UIListLayout")
List.Padding = UDim.new(0, 10)
List.SortOrder = Enum.SortOrder.LayoutOrder
List.Parent = Content

local function makeSection(title, order)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -4, 0, 0)
    f.AutomaticSize = Enum.AutomaticSize.Y
    f.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
    f.BackgroundTransparency = 0.15
    f.LayoutOrder = order
    f.Parent = Content
    corner(f, 12)
    stroke(f, Color3.fromRGB(255, 255, 255), 0.8)
    pad(f, 10, 12, 12, 12)

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, 0, 0, 20)
    t.BackgroundTransparency = 1
    t.Text = title
    t.TextColor3 = Color3.fromRGB(200, 210, 255)
    t.TextSize = 13
    t.Font = Enum.Font.GothamBold
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = f

    local inner = Instance.new("Frame")
    inner.Size = UDim2.new(1, 0, 0, 0)
    inner.Position = UDim2.new(0, 0, 0, 26)
    inner.AutomaticSize = Enum.AutomaticSize.Y
    inner.BackgroundTransparency = 1
    inner.Parent = f

    local il = Instance.new("UIListLayout")
    il.Padding = UDim.new(0, 8)
    il.SortOrder = Enum.SortOrder.LayoutOrder
    il.Parent = inner

    return inner
end

local function makeLabel(parent, text, order)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 16)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(160, 170, 190)
    l.TextSize = 12
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = order
    l.Parent = parent
    return l
end

local function makeInput(parent, placeholder, order)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 36)
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    box.Text = ""
    box.PlaceholderText = placeholder
    box.PlaceholderColor3 = Color3.fromRGB(110, 115, 140)
    box.TextColor3 = Color3.fromRGB(240, 240, 255)
    box.TextSize = 13
    box.Font = Enum.Font.Gotham
    box.ClearTextOnFocus = false
    box.LayoutOrder = order
    box.Parent = parent
    corner(box, 9)
    stroke(box, Color3.fromRGB(120, 100, 255), 1)
    pad(box, 0, 0, 10, 10)
    return box
end

local function makeBtn(parent, text, color, order)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 38)
    b.BackgroundColor3 = color or Color3.fromRGB(80, 60, 200)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 13
    b.Font = Enum.Font.GothamBold
    b.AutoButtonColor = false
    b.LayoutOrder = order
    b.Parent = parent
    corner(b, 10)
    stroke(b, Color3.fromRGB(255, 255, 255), 0.9)

    b.MouseButton1Down:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.08), {BackgroundTransparency = 0.25}):Play()
    end)
    b.MouseButton1Up:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play()
    end)
    return b
end

local function makeToggle(parent, label, default, order, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = parent

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -56, 1, 0)
    t.BackgroundTransparency = 1
    t.Text = label
    t.TextColor3 = Color3.fromRGB(220, 225, 245)
    t.TextSize = 12
    t.Font = Enum.Font.Gotham
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 46, 0, 24)
    track.Position = UDim2.new(1, -46, 0.5, -12)
    track.BackgroundColor3 = default and Color3.fromRGB(60, 200, 140) or Color3.fromRGB(60, 60, 80)
    track.Parent = row
    corner(track, 12)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = default and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Parent = track
    corner(knob, 10)

    local state = default
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = row
    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(track, TweenInfo.new(0.15), {
            BackgroundColor3 = state and Color3.fromRGB(60, 200, 140) or Color3.fromRGB(60, 60, 80)
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = state and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
        }):Play()
        if callback then callback(state) end
    end)
    return row
end

local function makeDropdown(parent, options, default, order, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 36)
    holder.BackgroundTransparency = 1
    holder.LayoutOrder = order
    holder.Parent = parent
    holder.ClipsDescendants = false

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    btn.Text = "  " .. default .. "  ▼"
    btn.TextColor3 = Color3.fromRGB(230, 230, 255)
    btn.TextSize = 12
    btn.Font = Enum.Font.Gotham
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = false
    btn.Parent = holder
    corner(btn, 9)
    stroke(btn, Color3.fromRGB(100, 140, 255), 1)

    local open = false
    local listFrame

    btn.MouseButton1Click:Connect(function()
        if open and listFrame then
            listFrame:Destroy()
            listFrame = nil
            open = false
            return
        end
        open = true
        listFrame = Instance.new("Frame")
        listFrame.Size = UDim2.new(1, 0, 0, math.min(#options * 32, 160))
        listFrame.Position = UDim2.new(0, 0, 0, 38)
        listFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
        listFrame.ZIndex = 20
        listFrame.Parent = holder
        corner(listFrame, 9)
        stroke(listFrame, Color3.fromRGB(120, 100, 255), 1)

        local sf = Instance.new("ScrollingFrame")
        sf.Size = UDim2.new(1, 0, 1, 0)
        sf.BackgroundTransparency = 1
        sf.ScrollBarThickness = 3
        sf.CanvasSize = UDim2.new(0, 0, 0, #options * 32)
        sf.ZIndex = 21
        sf.Parent = listFrame

        local ll = Instance.new("UIListLayout")
        ll.Parent = sf

        for _, opt in ipairs(options) do
            local ob = Instance.new("TextButton")
            ob.Size = UDim2.new(1, 0, 0, 32)
            ob.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
            ob.Text = "  " .. opt
            ob.TextColor3 = Color3.fromRGB(220, 225, 255)
            ob.TextSize = 12
            ob.Font = Enum.Font.Gotham
            ob.TextXAlignment = Enum.TextXAlignment.Left
            ob.ZIndex = 22
            ob.AutoButtonColor = false
            ob.Parent = sf
            ob.MouseButton1Click:Connect(function()
                btn.Text = "  " .. opt .. "  ▼"
                if callback then callback(opt) end
                listFrame:Destroy()
                listFrame = nil
                open = false
            end)
        end
    end)

    return holder
end

-- Notify
local function notify(msg, ok)
    local n = Instance.new("TextLabel")
    n.Size = UDim2.new(0, 260, 0, 36)
    n.Position = UDim2.new(0.5, -130, 0, 20)
    n.BackgroundColor3 = ok and Color3.fromRGB(30, 80, 60) or Color3.fromRGB(80, 30, 40)
    n.Text = msg
    n.TextColor3 = Color3.fromRGB(255, 255, 255)
    n.TextSize = 12
    n.Font = Enum.Font.GothamBold
    n.ZIndex = 50
    n.Parent = Root
    corner(n, 10)
    task.delay(2.2, function()
        if n then n:Destroy() end
    end)
end

--------------------------------------------------------------------
-- BUILD SECTIONS
--------------------------------------------------------------------
local secPlay = makeSection("ระบบควบคุมเพลง", 1)
makeLabel(secPlay, "รหัสเสียง (Audio ID)", 1)
local idBox = makeInput(secPlay, "ใส่ Audio ID หรือลิงก์...", 2)

makeLabel(secPlay, "อุปกรณ์ส่งสัญญาณเสียง", 3)
makeDropdown(secPlay, DEVICES, SELECTED_DEVICE, 4, function(v)
    SELECTED_DEVICE = v
end)

makeToggle(secPlay, "กันเจาะกากๆรัน (Anti-Steal)", ANTI_STEAL_ON, 5, function(v)
    ANTI_STEAL_ON = v
end)

makeLabel(secPlay, "โหมดกันดัก", 6)
makeDropdown(secPlay, {"URI", "DIGIT"}, CURRENT_MODE, 7, function(v)
    CURRENT_MODE = v
end)

local playBtn = makeBtn(secPlay, "▶  เริ่มเล่นเพลง", Color3.fromRGB(60, 160, 100), 8)
local stopBtn = makeBtn(secPlay, "■  หยุดเพลง", Color3.fromRGB(160, 50, 70), 9)

playBtn.MouseButton1Click:Connect(function()
    CURRENT_AUDIO_ID = idBox.Text
    local ok, msg = playMusic(idBox.Text)
    if ok then
        notify("กำลังเล่น: " .. tostring(msg), true)
    else
        notify(tostring(msg), false)
    end
end)

stopBtn.MouseButton1Click:Connect(function()
    stopMusic()
    notify("หยุดเพลงแล้ว", true)
end)

local secInfo = makeSection("สถานะ", 2)
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 48)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Bait: กันเจาะกากๆรัน\nID: " .. BAIT_ID .. "\nโหมด: " .. CURRENT_MODE
statusLabel.TextColor3 = Color3.fromRGB(170, 180, 210)
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.LayoutOrder = 1
statusLabel.Parent = secInfo

-- RGB title animation
task.spawn(function()
    local h = 0
    while Root.Parent do
        h = (h + 0.004) % 1
        local c = Color3.fromHSV(h, 0.7, 1)
        TitleLabel.TextColor3 = c
        if ToggleBtn and ToggleBtn.Parent then
            local st = ToggleBtn:FindFirstChildOfClass("UIStroke")
            if st then st.Color = c end
        end
        task.wait(0.03)
    end
end)

--------------------------------------------------------------------
-- DRAG (Mouse + Touch)
--------------------------------------------------------------------
local dragging, dragStart, startPos

local function beginDrag(input)
    dragging = true
    dragStart = input.Position
    startPos = Win.Position
    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            dragging = false
        end
    end)
end

local function updateDrag(input)
    if not dragging then return end
    local delta = input.Position - dragStart
    Win.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + delta.X,
        startPos.Y.Scale, startPos.Y.Offset + delta.Y
    )
end

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        beginDrag(input)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        updateDrag(input)
    end
end)

-- Toggle show/hide
local visible = true
local function setVisible(v)
    visible = v
    Win.Visible = v
end

ToggleBtn.MouseButton1Click:Connect(function()
    setVisible(not visible)
end)

CloseBtn.MouseButton1Click:Connect(function()
    setVisible(false)
end)

-- Mobile toggle drag
do
    local tDrag, tStart, tPos
    ToggleBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            tDrag = true
            tStart = input.Position
            tPos = ToggleBtn.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not tDrag then return end
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - tStart
            if d.Magnitude > 8 then
                ToggleBtn.Position = UDim2.new(
                    tPos.X.Scale, tPos.X.Offset + d.X,
                    tPos.Y.Scale, tPos.Y.Offset + d.Y
                )
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            tDrag = false
        end
    end)
end

print("[Music Only] Loaded · Bait = กันเจาะกากๆรัน · Anti-Steal Ready")
