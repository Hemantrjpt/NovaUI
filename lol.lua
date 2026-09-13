-- Steal An Egg | Obsidian UI Port (deividcomsono)
-- Original logic preserved 1:1 from Oxide version

-- ==============================================================================
-- RE-EXECUTION GUARD + RESOURCE TRACKING
-- ==============================================================================
do
    local prev = _G.ObsidianStealAnEgg
    if prev and type(prev.Unload) == "function" then pcall(prev.Unload) end
end
local HUB = { conns = {}, drawings = {}, highlights = {}, dead = false }
_G.ObsidianStealAnEgg = HUB
local function track(conn) table.insert(HUB.conns, conn); return conn end
local function trackDrawing(d) if d then table.insert(HUB.drawings, d) end; return d end

-- ==============================================================================
-- OBSIDIAN UI LIBRARY LOAD
-- ==============================================================================
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

task.spawn(function()
    task.wait(1)
    pcall(function() Library:SetFont(Enum.Font.Gotham) end)
end)

local Window = Library:CreateWindow({
    Title = "TITANIC HUB",
    Footer = "Steal an Egg | FREEMIUM",
    Center = true,
    AutoShow = true,
    Resizable = true,
    ShowCustomCursor = true,
})

local Tabs = {
    Info = Window:AddTab("Info", "info"),
    Eggs = Window:AddTab("Eggs", "crown"),
    Base = Window:AddTab("Base", "bolt"),
    Combat = Window:AddTab("Combat", "swords"),
    Player = Window:AddTab("Player", "user"),
    Configs = Window:AddTab("Configs", "settings-2"),
    Settings = Window:AddTab("Settings", "settings"),
}

-- ==============================================================================
-- CONFIG / FLAG PERSISTENCE
-- ==============================================================================
local HAS_CONFIG = true
local CONFIG_NAME = "stealanegg"

local dropdownResync = {}
local function registerResync(handle, applyFn)
    if handle and applyFn then
        table.insert(dropdownResync, function() applyFn(handle:Get()) end)
    end
end
local function ResyncAll()
    for _, fn in ipairs(dropdownResync) do pcall(fn) end
end

-- ==============================================================================
-- SERVICES & LOCALS
-- ==============================================================================
local Players             = game:GetService("Players")
local RS                  = game:GetService("ReplicatedStorage")
local ReplicatedStorage   = RS
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local Workspace           = game:GetService("Workspace")
local Lighting            = game:GetService("Lighting")
local TeleportService     = game:GetService("TeleportService")
local VirtualUser         = game:GetService("VirtualUser")

local LP          = Players.LocalPlayer
local LocalPlayer = LP
local function GetCamera()
    return Workspace.CurrentCamera or Workspace:FindFirstChildOfClass("Camera")
end

pcall(function()
    local pps = game:GetService("ProximityPromptService")
    track(pps.PromptButtonHoldBegan:Connect(function(prompt, player)
        if player == LP and tostring(prompt) == "CarryAreaEgg" then
            prompt.HoldDuration = 0
        end
    end))
end)

pcall(function()
    local coreGui = game:GetService("CoreGui")
    track(coreGui.ChildAdded:Connect(function(child)
        if child.Name == "PurchasePrompt" then
            task.wait(0.04)
            pcall(function()
                local cancel = child:FindFirstChild("CancelButton", true)
                if cancel and typeof(cancel) == "Instance" and cancel:IsA("GuiButton") then
                    pcall(function() cancel.MouseButton1Click:Fire() end)
                end
            end)
        end
    end))
end)

local function Notify(title, content, kind, dur)
    pcall(function()
        Library:Notify({ Title = title, Description = content, Time = dur or 2.5 })
    end)
end

local function safeCallback(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            pcall(Notify, "Steal An Egg", "Error: " .. tostring(err), "Error", 4)
        end
    end
end

-- ==============================================================================
-- CLIENT AC NEUTRALIZER & UGI CONSTANT WIPER
-- ==============================================================================
local function bypassClientDetections()
    if typeof(filtergc) ~= "function" or typeof(debug) ~= "table" or typeof(debug.getupvalues) ~= "function" then
        return false, "no filtergc"
    end
    local ok, fn = pcall(function()
        return filtergc("function", {
            Constants = { "gmatch", "GetFullName" },
        }, true)
    end)
    if not ok or type(fn) ~= "function" then
        return false, "filter miss"
    end
    local setMeta = (typeof(setrawmetatable) == "function" and setrawmetatable)
        or (typeof(setmetatable) == "function" and setmetatable)
    if not setMeta then
        return false, "no setmeta"
    end
    local blocked = 0
    local okUv, ups = pcall(debug.getupvalues, fn)
    if not okUv or type(ups) ~= "table" then
        return false, "no upvalues"
    end
    for _, tbl in pairs(ups) do
        if typeof(tbl) == "table" then
            local okSet = pcall(setMeta, tbl, { __newindex = function() end })
            if okSet then blocked = blocked + 1 end
        end
    end
    return blocked > 0, blocked
end

pcall(bypassClientDetections)

pcall(function()
    local getgc = getgc or (debug and debug.getgc)
    local setmeta = setrawmetatable or setmetatable
    local getmeta = getrawmetatable or getmetatable
    if getgc and setmeta then
        for _, obj in ipairs(getgc(true)) do
            if typeof(obj) == "table" and not (getmeta and getmeta(obj)) then
                local mainrun = false
                for _, v in pairs(obj) do
                    if v == obj then mainrun = true; break end
                end
                if mainrun then
                    for _, v in pairs(obj) do
                        if typeof(v) == "number" and v >= 1 and v <= 3 and obj[v] == nil then
                            pcall(setmeta, obj, { __newindex = function() end })
                            break
                        end
                    end
                end
            end
        end
    end
end)

pcall(function()
    local getconstants = getconstants or (debug and debug.getconstants)
    local setconstant = setconstant or (debug and debug.setconstant)
    local islclosure = islclosure or function(Function)
        return not pcall(setfenv, getfenv(Function))
    end
    if getgc and getconstants and setconstant then
        for _, Function in ipairs(getgc(true)) do
            if typeof(Function) == "function" and islclosure(Function) then
                local ok, Source = pcall(debug.info, Function, "s")
                if ok and type(Source) == "string" and Source:find("ReplicatedFirst", 1, true) and Source:find("UGI", 1, true) then
                    local okC, Constants = pcall(getconstants, Function)
                    if okC and type(Constants) == "table" then
                        for Index, Constant in next, Constants do
                            if type(Constant) == "string" and Constant == "Humanoid" then
                                pcall(setconstant, Function, Index, "")
                            end
                        end
                    end
                end
            end
        end
    end
end)

pcall(function()
    local getconstants = getconstants or (debug and debug.getconstants)
    local islclosure = islclosure or function(fn) return not pcall(setfenv, getfenv(fn)) end
    local HookFn = hookfunction or replaceclosure or hookfunc
    if getgc and getconstants and HookFn and debug and debug.getstack and debug.setstack then
        for _, fn in ipairs(getgc(true)) do
            if typeof(fn) == "function" and islclosure(fn) then
                local ok, consts = pcall(getconstants, fn)
                if ok and type(consts) == "table" and table.find(consts, "X-14") then
                    local cb = nil
                    cb = HookFn(fn, function(...)
                        local stack = debug.getstack(1)
                        if type(stack) == "table" then
                            for idx, val in pairs(stack) do
                                if val == "X-14" then
                                    pcall(debug.setstack, 1, idx, nil)
                                end
                            end
                        end
                        if cb then return cb(...) end
                    end)
                end
            end
        end
    end
end)

pcall(function()
    local getgc = getgc or (debug and debug.getgc)
    local islclosure = islclosure or function(v) return not pcall(setfenv, getfenv(v)) end
    local getupvalues = getupvalues or (debug and debug.getupvalues)
    local getupvalue = getupvalue or (debug and debug.getupvalue)
    local setupvalue = setupvalue or (debug and debug.setupvalue)
    local clonefunction = clonefunction or function(f) return function(...) return f(...) end end
    if getgc and getupvalues and getupvalue and setupvalue then
        for _, v in ipairs(getgc(true)) do
            if typeof(v) == "function" and islclosure(v) then
                local ok, upvs = pcall(getupvalues, v)
                if ok and upvs and #upvs == 19 then
                    local ok2, u2 = pcall(getupvalue, v, 2)
                    if ok2 and typeof(u2) == "function" then
                        local old = clonefunction(u2)
                        pcall(setupvalue, v, 2, function(a, b)
                            if b and typeof(b) == "table" then
                                pcall(setmetatable, b, {})
                            end
                            return old(a, b)
                        end)
                    end
                end
            end
        end
    end
end)

-- ==============================================================================
-- CHARACTER & MOVEMENT HELPERS
-- ==============================================================================
local function findChar() return LP.Character end
local function findHum()
    local ch = LP.Character
    return ch and ch:FindFirstChildOfClass("Humanoid")
end
local function findHRP()
    local ch = LP.Character
    return ch and (ch:FindFirstChild("HumanoidRootPart") or ch.PrimaryPart or ch:FindFirstChildWhichIsA("BasePart"))
end

local GetCharacter = findChar
local GetHumanoid  = findHum
local GetHRP       = findHRP

local function GetRootCFrame()
    local hrp = findHRP()
    return hrp and hrp.CFrame
end

-- ==============================================================================
-- BAC TELEMETRY PACKET SPOOFER
-- ==============================================================================
local bxor = bit32.bxor
local unpack = table.unpack

local function isGuid(n)
    return #n==36 and n:sub(9,9)=="-" and n:sub(14,14)=="-" and n:sub(19,19)=="-" and n:sub(24,24)=="-" and n:gsub("-",""):match("^%x+$")~=nil
end

local remoteSet, anyRemote = {}, nil

local function scanRemotes()
    for _, s in ipairs(game:GetChildren()) do
        local ok, list = pcall(s.GetDescendants, s)
        if ok and list then
            for _, o in ipairs(list) do
                if o:IsA("RemoteEvent") and isGuid(o.Name) then
                    remoteSet[o] = true
                    anyRemote = anyRemote or o
                end
            end
        end
    end
end

scanRemotes()

local function parseCounter(v)
    if type(v) ~= "string" then return end
    local n = v:match("^X%-(%d+)$")
    return n and tonumber(n)
end

local function looksLikeState(t, r)
    if type(t) ~= "table" then return false end
    local hR, hM = false, false
    local ok = pcall(function()
        for _, v in pairs(t) do
            if v == r then hR = true
            elseif type(v) == "string" and v:match("^X%-%d+$") then hM = true end
        end
    end)
    return ok and hR and hM
end

local function findState(r)
    for l=2,24 do
        local _, fn = pcall(debug.info, l, "f")
        if type(fn) == "function" then
            local _, ups = pcall(debug.getupvalues, fn)
            if type(ups) == "table" then
                for _, v in pairs(ups) do
                    if looksLikeState(v, r) then return v end
                    if type(v) == "table" then
                        local nested
                        pcall(function()
                            for _, x in pairs(v) do
                                if looksLikeState(x, r) then nested = x; return end
                            end
                        end)
                        if nested then return nested end
                    end
                end
            end
        end
    end
end

local function mapState(st, a1, a2)
    local m = {}
    for k, v in pairs(st) do
        if type(v) == "string" then
            if v:match("^X%-%d+$") then m.marker = m.marker or k
            elseif a1 and v == a1 then m.arg1 = m.arg1 or k
            elseif a2 and v == a2 then m.arg2 = m.arg2 or k end
        end
    end
    return m
end

local model = nil

local function digits(n)
    n = n % 1000
    return math.floor(n/100), math.floor(n/10)%10, n%10
end

local function encode(m, c)
    local d1, d2, d3 = digits(c)
    return m.prefix .. string.char(bxor(d1, m.k1), bxor(d2, m.k2), bxor(d3, m.k3))
end

local function learn(r, a1, a2)
    local st = findState(r)
    if not st then return end
    local map = mapState(st, a1, a2)
    if not map.marker then return end
    local c = parseCounter(rawget(st, map.marker))
    if not c then return end
    local d1, d2, d3 = digits(c)
    local m = {
        state = st, map = map, remote = r,
        prefix = a1:sub(1, 9),
        k1 = bxor(a1:byte(10), d1),
        k2 = bxor(a1:byte(11), d2),
        k3 = bxor(a1:byte(12), d3),
        offset = c - os.time(),
        arg2 = a2
    }
    if encode(m, c) == a1 then return m end
end

local function liveCounter(m)
    if m.state and m.map.marker then
        local _, raw = pcall(rawget, m.state, m.map.marker)
        local c = parseCounter(raw)
        if c and math.abs((c - os.time()) - m.offset) <= 5 then
            return c
        end
    end
    return os.time() + m.offset
end

local function refreshArg2(m)
    if m.state and m.map.arg2 then
        local _, v = pcall(rawget, m.state, m.map.arg2)
        if type(v) == "string" then m.arg2 = v end
    end
    return m.arg2
end

local HookFn = hookfunction or replaceclosure or hookfunc or detour_function

if anyRemote and HookFn then
    local oldFire
    oldFire = HookFn(anyRemote.FireServer, function(self, ...)
        local args = table.pack(...)
        if not remoteSet[self] then
            return oldFire(self, unpack(args, 1, args.n))
        end
        local a1 = args[1]
        if type(a1) == "string" and #a1 == 12 then
            if not model then
                model = learn(self, a1, args[2])
            else
                local c = parseCounter(rawget(model.state, model.map.marker))
                if c and encode(model, c) ~= a1 then
                    local m = learn(self, a1, args[2])
                    if m then m.spoofed = model.spoofed; model = m end
                end
            end
            return oldFire(self, unpack(args, 1, args.n))
        end
        if model and type(a1) == "string" and #a1 == 4 then
            local c = liveCounter(model)
            args[1] = encode(model, c)
            args[2] = refreshArg2(model)
            model.spoofed = (model.spoofed or 0) + 1
            return oldFire(self, unpack(args, 1, math.max(args.n, 2)))
        end
        return oldFire(self, unpack(args, 1, args.n))
    end)
end

task.spawn(function()
    while not HUB.dead do
        task.wait(10)
        local alive = false
        for r in pairs(remoteSet) do
            if r:IsDescendantOf(game) then alive = true; break end
        end
        if not alive then
            table.clear(remoteSet)
            anyRemote = nil
            model = nil
            scanRemotes()
        end
    end
end)

task.spawn(function()
    if not getgc then return end
    local st = nil

    local function findIntegrityTable()
        local ok, objs = pcall(getgc, true)
        if ok and objs then
            for _, o in pairs(objs) do
                if type(o) == "table" then
                    local hit = false
                    pcall(function()
                        hit = (rawget(o, "ValidationLocked") ~= nil and rawget(o, "Evidence") ~= nil)
                            or (rawget(o, "ThreatLevel") ~= nil and rawget(o, "LastObservedSample") ~= nil)
                    end)
                    if hit then return o end
                end
            end
        end
        return nil
    end

    track(LP.CharacterAdded:Connect(function()
        task.wait(1)
        st = findIntegrityTable()
    end))

    while not HUB.dead do
        if not st then st = findIntegrityTable() end
        if st then
            pcall(function()
                local ev = rawget(st, "Evidence")
                if type(ev) == "table" then
                    if (tonumber(ev.Speed) or 0) > 0 then rawset(ev, "Speed", 0) end
                    if (tonumber(ev.Teleport) or 0) > 0 then rawset(ev, "Teleport", 0) end
                    if (tonumber(ev.Flight) or 0) > 0 then rawset(ev, "Flight", 0) end
                end
                if rawget(st, "ThreatLevel") ~= "Trusted" then rawset(st, "ThreatLevel", "Trusted") end
                if rawget(st, "ValidationLocked") == true then rawset(st, "ValidationLocked", false) end
                if rawget(st, "FirstSuspiciousAt") ~= nil then rawset(st, "FirstSuspiciousAt", nil) end
                if rawget(st, "KickQueued") == true then rawset(st, "KickQueued", false) end
                if rawget(st, "TamperScore") ~= nil then rawset(st, "TamperScore", 0) end
                if rawget(st, "InvalidHeartbeatCount") ~= nil then rawset(st, "InvalidHeartbeatCount", 0) end

                local los = rawget(st, "LastObservedSample")
                if los ~= nil then
                    if rawget(st, "LastGameplayTrustedSample") == nil then rawset(st, "LastGameplayTrustedSample", los) end
                    if rawget(st, "LastValidatedSample") == nil then rawset(st, "LastValidatedSample", los) end
                    if rawget(st, "LastValidatedGroundedSample") == nil then rawset(st, "LastValidatedGroundedSample", los) end
                    if rawget(st, "LastConfirmedGroundSample") == nil then rawset(st, "LastConfirmedGroundSample", los) end
                    if rawget(st, "LastGoodSample") == nil then rawset(st, "LastGoodSample", los) end
                end
            end)
        end
        task.wait(0.2)
    end
end)

-- ==============================================================================
-- GAME NETWORKING & MODULE INTEGRATION
-- ==============================================================================
local EggState, PlotState, AreasData, RarityData, AssetsData, EggToolDisplay, AreaEggSlotIdentity
pcall(function() EggState = require(RS.Client.EggState) end)
pcall(function() PlotState = require(RS.Client.PlotState) end)
pcall(function() AreasData = require(RS.Data.Areas) end)
pcall(function() RarityData = require(RS.Data.Rarity) end)
pcall(function() AssetsData = require(RS.Data.Assets) end)
local SaveModule
pcall(function() SaveModule = require(RS.Shared.Save) end)
pcall(function() EggToolDisplay = require(RS.Shared.Eggs.EggToolDisplay) end)
pcall(function()
    AreaEggSlotIdentity = (RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("Util") and require(RS.Shared.Util.AreaEggSlotIdentity))
        or (RS:FindFirstChild("Util") and require(RS.Util.AreaEggSlotIdentity))
        or (RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("Utils") and require(RS.Shared.Utils.AreaEggSlotIdentity))
end)

local function GetNetRemote(name)
    local net = RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("Networking")
    return net and net:FindFirstChild(name)
end

local function GetLocalSlot()
    if PlotState and PlotState.ResolveLocalSlot then
        local ok, slot = pcall(PlotState.ResolveLocalSlot)
        if ok and slot then return slot end
    end
    return 1
end

local function GetLocalPlotCenter()
    local plotObj = PlotState and PlotState.ResolvePlot and PlotState.ResolvePlot()
    local pt = plotObj and plotObj.CenterPoint and (typeof(plotObj.CenterPoint) == "Vector3" and plotObj.CenterPoint or (plotObj.CenterPoint:IsA("BasePart") and plotObj.CenterPoint.Position))
    if pt then
        return Vector3.new(pt.X, math.max(pt.Y, 70.4), pt.Z), CFrame.new(pt.X, math.max(pt.Y, 70.4), pt.Z)
    end
    return Vector3.new(464.7, 70.4, -364.0), CFrame.new(464.7, 70.4, -364.0)
end

-- ==============================================================================
-- CLEAN ROAD & FLIGHT PATH NAVIGATION
-- ==============================================================================
local MAIN_ROAD_Z = -364.5

local stealMovementMethod    = "Tween Glide"
local avoidTrapsEnabled       = true
local autoClaimMonsterChests  = false
local autoFeedMonster         = false

local function instantTP(cframe)
    local root = findHRP()
    if not root then return end
    root.CFrame = cframe
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    task.spawn(function()
        local char = LP.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    pcall(function() part.CanCollide = false end)
                end
            end
        end
    end)
end

local function heartbeatTP(cframeTarget, holdTime)
    local root = findHRP()
    if not root then return end
    local char = LP.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function() part.CanCollide = false end)
            end
        end
    end
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local r = findHRP()
        if r and r.Parent then
            r.CFrame = cframeTarget
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end
    end)
    task.wait(holdTime or 0.25)
    if conn then conn:Disconnect() end
    local r2 = findHRP()
    if r2 then
        r2.CFrame = cframeTarget
        r2.AssemblyLinearVelocity = Vector3.zero
        r2.AssemblyAngularVelocity = Vector3.zero
    end
end

local BYPASS_FLOAT_HEIGHT = 6.7
local BYPASS_LEG_OFFSET = Vector3.new(0, -6.7, 0)
local BYPASS_TP_OFFSET = Vector3.new(0, 6.7, 0)

local function bypassReturnTP(safeCFrame, holdTime)
    local hrp = findHRP()
    if not hrp then return false end
    local targetPart = Workspace:FindFirstChild("SpawnLocation", true)
    if not targetPart or not targetPart:IsA("BasePart") then
        heartbeatTP(safeCFrame, holdTime or 0.3)
        return true
    end
    pcall(function() targetPart.CanCollide = false end)
    local char = LP.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function() part.CanCollide = false end)
            end
        end
    end
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local r = findHRP()
        if not r or not r.Parent then return end
        pcall(function() targetPart.CFrame = r.CFrame * CFrame.new(BYPASS_LEG_OFFSET) end)
        r.CFrame = safeCFrame + BYPASS_TP_OFFSET
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
        pcall(function() targetPart.CFrame = safeCFrame end)
    end)
    task.wait(holdTime or 0.35)
    if conn then conn:Disconnect() end
    local r2 = findHRP()
    if r2 then
        r2.CFrame = safeCFrame
        r2.AssemblyLinearVelocity = Vector3.zero
        r2.AssemblyAngularVelocity = Vector3.zero
    end
    return true
end

local function restoreCollisions()
    local char = LP.Character
    if not char or not char.Parent then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.CanCollide = true
        end
    end
end

local function SafeTeleport(targetPos)
    local root = findHRP()
    if not root or not targetPos then return false end
    root.CFrame = CFrame.new(targetPos.X, math.max(targetPos.Y, 70.0), targetPos.Z)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    return true
end

local function NeutralizeTraps()
    local debris = Workspace:FindFirstChild("__DEBRIS")
    if not debris then return end
    for _, d in ipairs(debris:GetChildren()) do
        if d.Name == "PlayerTrap" and d:GetAttribute("Owner") ~= LP.Name then
            if d:IsA("BasePart") then
                d.CanTouch = false
                d.CanQuery = false
            end
            for _, c in ipairs(d:GetChildren()) do
                if c:IsA("BasePart") then
                    c.CanTouch = false
                    c.CanQuery = false
                    if c.Name == "Hitbox" then
                        c.CFrame = CFrame.new(0, -999, 0)
                    end
                end
            end
            local tt = d:FindFirstChildWhichIsA("TouchTransmitter", true)
            if tt then pcall(function() tt:Destroy() end) end
        end
    end
end

local function MoveToPoint(target, speed, easeOut)
    local hrp = findHRP()
    if not hrp or not target then return false end

    local start = hrp.Position
    local dist = (target - start).Magnitude
    if dist < 1.0 then
        hrp.CFrame = CFrame.new(target.X, math.max(target.Y, 70.0), target.Z)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        return true
    end

    speed = math.clamp(tonumber(speed) or tonumber(glideSpeed) or 750, 50, 750)

    local t0 = os.clock()
    local totalDist = dist
    while not HUB.dead do
        local dt = RunService.Heartbeat:Wait()
        local curPos = hrp.Position
        local toTarget = target - curPos
        local remain = toTarget.Magnitude
        if remain < 1.0 then break end
        local stepSpeed = speed
        if easeOut then
            local progress = 1 - math.clamp(remain / totalDist, 0, 1)
            stepSpeed = math.max(speed * (1 - progress * 0.8), 35)
        end
        local step = math.min(stepSpeed * dt, remain)
        local dir = toTarget.Unit
        local nextPos = curPos + dir * step
        hrp.CFrame = CFrame.lookAt(nextPos, nextPos + dir)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        if os.clock() - t0 > (totalDist / 50 + 5) then break end
    end

    hrp.CFrame = CFrame.new(target.X, math.max(target.Y, 70.0), target.Z)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    return true
end

local function FlyToPoint(target, speed, easeOut)
    local hrp = findHRP()
    if not hrp or not target then return false end
    local start = hrp.Position
    local dist = (target - start).Magnitude
    if dist < 1.0 then
        hrp.CFrame = CFrame.new(target.X, math.max(target.Y, 70.0), target.Z)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        return true
    end

    speed = math.clamp(tonumber(speed) or tonumber(glideSpeed) or 750, 50, 750)
    local moveTime = math.max(dist / speed, 0.02)
    if easeOut then moveTime = moveTime * 1.25 end

    local t0 = os.clock()
    local delta = target - start
    local dir = delta.Magnitude > 0.001 and delta.Unit or Vector3.new(1, 0, 0)

    while os.clock() - t0 < moveTime and not HUB.dead do
        local dt = RunService.Heartbeat:Wait()
        local linearAlpha = math.clamp((os.clock() - t0) / moveTime, 0, 1)
        local a = linearAlpha
        if easeOut then a = math.sin(linearAlpha * (math.pi / 2)) end
        local cur = start:Lerp(target, a)
        hrp.CFrame = CFrame.lookAt(cur, cur + dir)
        local curSpeed = speed
        if easeOut then curSpeed = math.max(speed * (1 - linearAlpha * 0.8), 35) end
        hrp.AssemblyLinearVelocity = Vector3.new(dir.X * curSpeed, math.clamp(dir.Y * curSpeed, -15, 150), dir.Z * curSpeed)
        hrp.AssemblyAngularVelocity = Vector3.zero
    end

    hrp.CFrame = CFrame.new(target.X, math.max(target.Y, 70.0), target.Z)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    return true
end

local SAFE_BOUNDARY_X = 580
local SAFE_ZONE_SPEED = 245

local function TravelRoadPath(targetPos, speed, isApproach)
    local hrp = findHRP()
    if not hrp or not targetPos then return false end
    if avoidTrapsEnabled then pcall(NeutralizeTraps) end

    local startPos = hrp.Position
    local safeY = math.max(startPos.Y, targetPos.Y, 70.4)
    local isReturningToBase = (targetPos.X < 560)

    if isReturningToBase and startPos.X > SAFE_BOUNDARY_X then
        local p1 = Vector3.new(startPos.X, safeY, MAIN_ROAD_Z)
        MoveToPoint(p1, speed, false)
        local pSafeApproach = Vector3.new(SAFE_BOUNDARY_X, safeY, MAIN_ROAD_Z)
        MoveToPoint(pSafeApproach, speed, false)
        local pBaseRoad = Vector3.new(targetPos.X, safeY, MAIN_ROAD_Z)
        MoveToPoint(pBaseRoad, SAFE_ZONE_SPEED, false)
        local pPen = targetPos + Vector3.new(0, 1.2, 0)
        MoveToPoint(pPen, SAFE_ZONE_SPEED, isApproach == true)
        return true
    else
        local p1 = Vector3.new(startPos.X, safeY, MAIN_ROAD_Z)
        local p2 = Vector3.new(targetPos.X, safeY, MAIN_ROAD_Z)
        local p3 = targetPos + Vector3.new(0, 1.2, 0)
        MoveToPoint(p1, speed, false)
        MoveToPoint(p2, speed, false)
        MoveToPoint(p3, speed, isApproach == true)
        return true
    end
end

local function TravelFlyDirect(targetPos, speed, isApproach)
    local hrp = findHRP()
    if not hrp or not targetPos then return false end
    if avoidTrapsEnabled then pcall(NeutralizeTraps) end

    local startPos = hrp.Position
    local isReturningToBase = (targetPos.X < 560)
    local flyAltitude = math.max(startPos.Y, targetPos.Y, 70.4) + 28

    if isReturningToBase and startPos.X > SAFE_BOUNDARY_X then
        local pSky1 = Vector3.new(startPos.X, flyAltitude, startPos.Z)
        local pSkySafe = Vector3.new(SAFE_BOUNDARY_X, flyAltitude, MAIN_ROAD_Z)
        FlyToPoint(pSky1, speed, false)
        FlyToPoint(pSkySafe, speed, false)
        local pGroundSafe = Vector3.new(SAFE_BOUNDARY_X, 70.4, MAIN_ROAD_Z)
        FlyToPoint(pGroundSafe, SAFE_ZONE_SPEED, false)
        local pBaseRoad = Vector3.new(targetPos.X, 70.4, MAIN_ROAD_Z)
        MoveToPoint(pBaseRoad, SAFE_ZONE_SPEED, false)
        local pPen = targetPos + Vector3.new(0, 1.2, 0)
        MoveToPoint(pPen, SAFE_ZONE_SPEED, isApproach == true)
        return true
    else
        local totalDist = (targetPos - startPos).Magnitude
        if totalDist < 25 then
            FlyToPoint(Vector3.new(targetPos.X, math.max(targetPos.Y, 70.0) + 1.2, targetPos.Z), speed, isApproach == true)
            return true
        end
        local pSky1 = Vector3.new(startPos.X, flyAltitude, startPos.Z)
        local pSky2 = Vector3.new(targetPos.X, flyAltitude, targetPos.Z)
        local pGround = Vector3.new(targetPos.X, math.max(targetPos.Y, 70.0) + 1.2, targetPos.Z)
        FlyToPoint(pSky1, speed, false)
        FlyToPoint(pSky2, speed, false)
        FlyToPoint(pGround, speed, isApproach == true)
        return true
    end
end

local function TravelSafeWalk(targetPos)
    local hum = findHum()
    local hrp = findHRP()
    if not hum or not hrp or not targetPos then return false end
    if avoidTrapsEnabled then pcall(NeutralizeTraps) end

    local startPos = hrp.Position
    local p1 = Vector3.new(startPos.X, startPos.Y, MAIN_ROAD_Z)
    local p2 = Vector3.new(targetPos.X, targetPos.Y, MAIN_ROAD_Z)
    local p3 = targetPos + Vector3.new(0, 1.2, 0)

    for _, pt in ipairs({ p1, p2, p3 }) do
        if HUB.dead then break end
        hum:MoveTo(pt)
        local t0 = os.clock()
        while (hrp.Position - pt).Magnitude > 4.5 and os.clock() - t0 < 5 and not HUB.dead do
            task.wait(0.05)
        end
    end
    return true
end

local function TravelToDestination(targetPos, speed, isApproach)
    if stealMovementMethod == "Fly Glide" then
        return TravelFlyDirect(targetPos, speed, isApproach)
    elseif stealMovementMethod == "Safe Walk" then
        return TravelSafeWalk(targetPos)
    else
        return TravelRoadPath(targetPos, speed, isApproach)
    end
end

-- ==============================================================================
-- RARITY & AREA DICTIONARIES
-- ==============================================================================
local RARITY_SCORE_MAP = {
    ["Titan"]           = 1100,
    ["Divine"]          = 1000,
    ["Transcendent"]    = 1000,
    ["Superior"]        = 1000,
    ["Eternal"]         = 900,
    ["Limited"]         = 900,
    ["Secret"]          = 800,
    ["Exotic"]          = 800,
    ["Cosmic"]          = 700,
    ["Exclusive"]       = 700,
    ["Admin"]           = 700,
    ["Mythic"]          = 600,
    ["Mythical"]        = 600,
    ["Prismatic"]       = 600,
    ["Rainbow"]         = 600,
    ["Squishy God"]     = 600,
    ["BrainrotGod"]     = 600,
    ["Legendary"]       = 500,
    ["Epic"]            = 400,
    ["Rare"]            = 300,
    ["SuperRare"]       = 200,
    ["Celestial"]       = 200,
    ["Uncommon"]        = 200,
    ["Basic"]           = 100,
    ["Common"]          = 100,
}

local AREA_COORDINATES = {
    ["Base / Plot"]      = Vector3.new(491.7, 70.4, -364.4),
    ["Stands & Shops"]   = Vector3.new(539.5, 68.0, -364.5),
    ["Forest"]           = Vector3.new(596.0, 68.0, -328.0),
    ["Lake"]             = Vector3.new(744.0, 68.5, -408.0),
    ["Desert"]           = Vector3.new(948.0, 69.5, -323.0),
    ["Jungle"]           = Vector3.new(1188.0, 68.5, -408.0),
    ["Snow"]             = Vector3.new(1492.0, 69.0, -315.0),
    ["Volcano"]          = Vector3.new(1882.0, 68.0, -398.0),
    ["Abyss Ocean"]      = Vector3.new(2280.0, 68.0, -326.0),
    ["Prehistoric"]      = Vector3.new(2812.0, 69.0, -398.0),
    ["Cosmic"]           = Vector3.new(3390.0, 68.0, -324.0),
    ["Cherry Blossom"]   = Vector3.new(4028.0, 68.5, -396.0),
    ["Titan Temple"]     = Vector3.new(4796.0, 69.5, -328.0),
    ["Monster Event"]    = Vector3.new(539.5, 68.0, -411.3),
    ["Dragon Event"]     = Vector3.new(539.5, 68.0, -318.0),
}

local AREA_NAMES = {
    "Forest", "Lake", "Desert", "Jungle", "Snow", "Volcano",
    "Abyss Ocean", "Prehistoric", "Cosmic", "Cherry Blossom", "Titan Temple",
    "Monster Event", "Dragon Event"
}

local RARITY_NAMES = {
    "Titan", "Divine", "Superior", "Eternal", "Limited",
    "Secret", "Exotic", "Cosmic", "Exclusive", "Mythic", "Rainbow",
    "Squishy God", "Legendary", "Epic", "Rare", "Uncommon", "Common"
}

local MUTATION_FILTERS = {
    "Normal Only", "Mutated Only", "Parasite / Infested", "Rainbow Only", "Gold Only", "Silver Only", "Monstrous"
}

-- ==============================================================================
-- AUTOMATION STATE
-- ==============================================================================
local autoStealEnabled          = false
local rareEggHunter             = true
local stealParasiteOnly         = false
local stealBigEggsOnly          = false
local selectedStealRarities     = {}
local selectedStealAreas        = {}
local selectedMutationTypes     = {}
local stealDelay                = 1.5
local glideSpeed                = 750
local ignoredEggs               = {}

local savedReturnCFrame         = nil

local autoHatchEnabled          = false
local autoPlantEnabled          = false
local hatchCheckDelay           = 2.0

local autoUpgradeBase           = false
local autoUpgradeTreadmill      = false
local autoTrainSpeed            = false
local autoBuyTrails             = false
local autoEquipBestPets         = false
local autoClaimRewards          = false

local autoSellPets              = false
local autoSellEggs              = false
local selectedSellPetRarities   = {}
local selectedSellEggRarities   = {}

local DEFAULT_LOW_TIER_SELL = {
    ["Common"] = true, ["Uncommon"] = true, ["Rare"] = true,
    ["Epic"] = true, ["Legendary"] = true, ["Mythic"] = true,
}
local SELL_REQUEST_DELAY = 0.1
local function getSellRarityFilter(selected)
    if not selected or next(selected) == nil then return DEFAULT_LOW_TIER_SELL end
    return selected
end

local instantPickupEnabled      = true
local noKnockbackEnabled        = true
local batAuraEnabled            = false
local batAuraRadius             = 20
local batAuraDelay              = 0.2
local antiRagdollEnabled        = true

-- ==============================================================================
-- EGG STEALING, PLANTING & HATCHING CORE LOGIC
-- ==============================================================================
local function GetEggRarityInfo(egg)
    if not egg then return "Common", 100 end

    if egg.Rarity then
        local r = egg.Rarity
        local name = type(r) == "table" and (r.DisplayName or r._id or r.Name) or tostring(r)
        local score = RARITY_SCORE_MAP[name] or (type(r) == "table" and tonumber(r.RarityNumber) and r.RarityNumber * 100) or 100
        return name, score
    end

    local cat = egg.AssetCategory or egg.Category or egg.Name
    if cat and AssetsData then
        local assetsDir = AssetsData.Directory or AssetsData
        local aInfo = assetsDir[cat]
        if aInfo and aInfo.Rarity then
            local r = aInfo.Rarity
            local name = type(r) == "table" and (r.DisplayName or r._id or r.Name) or tostring(r)
            local score = RARITY_SCORE_MAP[name] or (type(r) == "table" and tonumber(r.RarityNumber) and r.RarityNumber * 100) or 100
            return name, score
        end
    end

    local areaData = AreasData and (AreasData.Directory or AreasData) and (AreasData.Directory or AreasData)[egg.AreaId]
    local rarity = areaData and areaData.Rarity
    local rarityId = (type(rarity) == "table" and (rarity._id or rarity.DisplayName or rarity.Name)) or (type(rarity) == "string" and rarity) or "Common"
    local raritiesTable = RarityData and (RarityData.Rarities or RarityData) or {}
    local rInfo = raritiesTable[rarityId] or {}
    local rarityDisplayName = (type(rInfo) == "table" and (rInfo.DisplayName or rInfo._id)) or (type(rarity) == "table" and rarity.DisplayName) or rarityId or "Common"
    local baseScore = RARITY_SCORE_MAP[rarityDisplayName] or RARITY_SCORE_MAP[rarityId] or (type(rarity) == "table" and tonumber(rarity.RarityNumber) and rarity.RarityNumber * 100) or 100
    return rarityDisplayName, baseScore
end

local function isRarityAllowed(rarityName, filter)
    if not filter or type(filter) ~= "table" then return true end
    local count = 0
    for _ in pairs(filter) do count = count + 1 end
    if count == 0 then return true end

    if filter[rarityName] == true then return true end
    local rLower = string.lower(tostring(rarityName))
    for k, v in pairs(filter) do
        if type(v) == "string" and string.lower(v) == rLower then
            return true
        elseif type(k) == "string" and string.lower(k) == rLower and v == true then
            return true
        end
    end
    return false
end

local function isAreaAllowed(areaId, filter)
    if not filter or type(filter) ~= "table" then return true end
    local count = 0
    for _ in pairs(filter) do count = count + 1 end
    if count == 0 then return true end

    if filter[areaId] == true then return true end
    local aLower = string.lower(tostring(areaId))
    for k, v in pairs(filter) do
        if type(v) == "string" and string.lower(v) == aLower then
            return true
        elseif type(k) == "string" and string.lower(k) == aLower and v == true then
            return true
        end
    end
    return false
end

local function isMutationAllowed(muts, record, filter)
    local isParasite = (record and record.HasParasite == true)
        or (type(muts) == "table" and (table.find(muts, "Parasite") or table.find(muts, "Monstrous")))
        or (record and (record.BaseMutation == "Parasite" or record.BaseMutation == "Monstrous"))

    if stealParasiteOnly and not isParasite then return false end

    if not filter or type(filter) ~= "table" then return true end
    local count = 0
    for _ in pairs(filter) do count = count + 1 end
    if count == 0 then return true end

    local hasMut = type(muts) == "table" and #muts > 0
    local allowed = false
    for _, opt in pairs(filter) do
        if type(opt) == "string" then
            if opt == "Normal Only" and not hasMut and not isParasite then
                allowed = true
            elseif opt == "Mutated Only" and (hasMut or isParasite) then
                allowed = true
            elseif (opt == "Parasite / Infested" or opt == "Monstrous") and isParasite then
                allowed = true
            elseif opt == "Silver Only" and type(muts) == "table" and table.find(muts, "Silver") then
                allowed = true
            elseif opt == "Gold Only" and type(muts) == "table" and (table.find(muts, "Gold") or table.find(muts, "Golden")) then
                allowed = true
            elseif opt == "Rainbow Only" and type(muts) == "table" and table.find(muts, "Rainbow") then
                allowed = true
            end
        end
    end
    return allowed
end

local function isBigEgg(record)
    if not record then return false end
    local scale = tonumber(record.AssetScale) or 1
    local nestScale = tonumber(record.NestScale) or 1
    return scale >= 1.35 or nestScale >= 1.0
end

local function GetMatchingFieldEggs(areasFilter, raritiesFilter, mutationsFilter)
    if not EggState or not EggState.ReadFieldEggs then return {} end
    local ok, snapshot = pcall(EggState.ReadFieldEggs)
    if not ok or not snapshot or not snapshot.Records then return {} end

    local matched = {}
    for _, record in ipairs(snapshot.Records) do
        if record.State == "Slot" and record.BoundsCFrame then
            local isIgnored = ignoredEggs[record.Uid] and (os.clock() - ignoredEggs[record.Uid] < 2.5)
            if not isIgnored and (not stealBigEggsOnly or isBigEgg(record)) then
                local areaOk = isAreaAllowed(record.AreaId, areasFilter)
                local rarityName, baseScore = GetEggRarityInfo(record)
                local rarityOk = isRarityAllowed(rarityName, raritiesFilter)
                local muts = record.Mutations or {}
                local mutOk = isMutationAllowed(muts, record, mutationsFilter)

                if areaOk and rarityOk and mutOk then
                    local mutBonus = 0
                    for _, m in ipairs(muts) do
                        if m == "Rainbow" then mutBonus = mutBonus + 35
                        elseif m == "Gold" or m == "Golden" then mutBonus = mutBonus + 20
                        elseif m == "Silver" then mutBonus = mutBonus + 10 end
                    end

                    if record.HasParasite == true or (type(muts) == "table" and (table.find(muts, "Parasite") or table.find(muts, "Monstrous"))) then
                        mutBonus = mutBonus + 800
                    end

                    if isBigEgg(record) then mutBonus = mutBonus + 600 end

                    table.insert(matched, {
                        record = record,
                        rarity = rarityName,
                        score = baseScore + mutBonus
                    })
                end
            end
        end
    end

    if #matched > 1 then
        table.sort(matched, function(a, b) return a.score > b.score end)
    end

    return matched
end

local function EnsureSavedReturnPosition()
    if not savedReturnCFrame then
        local hrp = findHRP()
        if hrp then savedReturnCFrame = hrp.CFrame end
    end
end

local function isPlayerCarryingEgg()
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    local dropGui = pg and pg:FindFirstChild("DropHeldEgg")
    if dropGui and dropGui.Enabled == true then return true end

    local char = LP.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Model") and (t.Name:lower():find("egg") or t:GetAttribute("Uid") or t:GetAttribute("AssetCategory")) then
                return true
            end
            if t:IsA("Tool") then
                if EggToolDisplay and EggToolDisplay.IsEggTool and EggToolDisplay.IsEggTool(t) then return true end
                if t:GetAttribute("IsEgg") == true or t:GetAttribute("Uid") ~= nil or t:GetAttribute("AssetCategory") ~= nil then return true end
                local tName = t.Name:lower()
                if tName:find("egg") or (tName ~= "bat" and tName ~= "defaulttool" and not tName:find("bat") and not tName:find("slap") and not tName:find("coil") and not tName:find("potion") and not tName:find("lantern")) then
                    return true
                end
            end
        end
    end
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and EggToolDisplay and EggToolDisplay.IsEggTool and EggToolDisplay.IsEggTool(t) then
                return true
            end
        end
    end
    return false
end

local function PlantAllCarriedEggsInPen()
    local plotObj = PlotState and PlotState.ResolvePlot and PlotState.ResolvePlot()
    local plotCenter = plotObj and plotObj.CenterPoint and plotObj.CenterPoint.Position or Vector3.new(464.7, 68.2, -364.0)

    local toolsToPlant = {}
    for _, t in ipairs(LP.Character:GetChildren()) do
        if t:IsA("Tool") and EggToolDisplay and EggToolDisplay.IsEggTool and EggToolDisplay.IsEggTool(t) then
            local uid = EggToolDisplay.GetToolUid(t)
            if uid then table.insert(toolsToPlant, uid) end
        end
    end
    for _, t in ipairs(LP.Backpack:GetChildren()) do
        if t:IsA("Tool") and EggToolDisplay and EggToolDisplay.IsEggTool and EggToolDisplay.IsEggTool(t) then
            local uid = EggToolDisplay.GetToolUid(t)
            if uid then table.insert(toolsToPlant, uid) end
        end
    end

    local plantedCount = 0
    for _, eggUid in ipairs(toolsToPlant) do
        for attempt = 1, 3 do
            local offset = CFrame.new(math.random(-6, 6), 0, math.random(-6, 6))
            local ok, res = pcall(function()
                if EggState and EggState.PlantEgg then
                    return EggState.PlantEgg(eggUid, offset)
                end
                return false
            end)
            if ok and res then
                plantedCount = plantedCount + 1
                break
            end
            task.wait(0.1)
        end
    end
    return plantedCount
end

local function StealSpecificEggRobust(targetItem)
    local record = targetItem.record or targetItem
    if not record or not record.Uid or not record.BoundsCFrame then return false end

    if EggState and EggState.ReadFieldEggs then
        local ok, snap = pcall(EggState.ReadFieldEggs)
        if ok and snap and snap.Records then
            local stillThere = false
            for _, r in ipairs(snap.Records) do
                if r.Uid == record.Uid and r.State == "Slot" then
                    stillThere = true
                    record = r
                    break
                end
            end
            if not stillThere then return false end
        end
    end

    local hrp = findHRP()
    local hum = findHum()
    if not hrp then return false end

    EnsureSavedReturnPosition()

    local targetPos = record.BoundsCFrame.Position
    local speed = math.clamp(tonumber(glideSpeed) or 750, 50, 750)
    local isInstantTP = (stealMovementMethod == "Anti Guard")

    TravelToDestination(targetPos + Vector3.new(0, 1.2, 0), speed, true)
    if hrp then
        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 1.2, 0))
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
    task.wait(isInstantTP and 0.25 or 0.5)

    local slotKey = nil
    if AreaEggSlotIdentity and AreaEggSlotIdentity.LooksLikeFirstAreaUid and AreaEggSlotIdentity.LooksLikeFirstAreaUid(record.Uid) then
        slotKey = AreaEggSlotIdentity.SlotKey(record.AreaId, record.NestId)
    end

    local net = RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("Networking")
    local carryRemote = net and net:FindFirstChild("RF/EggWorld/AskFieldEggCarry")
    if carryRemote then
        pcall(function() carryRemote:InvokeServer({ Uid = record.Uid, FirstAreaSlotKey = slotKey }) end)
    end
    pcall(function()
        if EggState and EggState.CarryFieldEgg then
            EggState.CarryFieldEgg(record.Uid, slotKey)
        end
    end)

    local prompt = nil
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Name == "CarryAreaEgg" and d.Enabled then
            local act = (d.ActionText or ""):lower()
            local obj = (d.ObjectText or ""):lower()
            if not act:find("skip") and not act:find("robux") and not obj:find("skip") and not obj:find("robux") then
                local p = d.Parent
                if p:IsA("Attachment") then p = p.Parent end
                if p and (p.Position - hrp.Position).Magnitude < 14 then
                    prompt = d
                    break
                end
            end
        end
    end

    if prompt then
        prompt.HoldDuration = 0
        pcall(function() fireproximityprompt(prompt) end)
        pcall(function() fireproximityprompt(prompt, 0) end)
    end

    local safePlotCenter, _ = GetLocalPlotCenter()
    local safeCFrame = CFrame.new(safePlotCenter + Vector3.new(0, 1.2, 0))
    local tPickup = os.clock()
    local carried = false
    local instantFired = false
    local conns = {}
    local function fireInstantNow()
        if instantFired then return end
        instantFired = true
        carried = true
        task.spawn(function()
            bypassReturnTP(safeCFrame, 0.35)
            pcall(restoreCollisions)
            pcall(PlantAllCarriedEggsInPen)
        end)
    end
    if isInstantTP then
        local char = LP.Character
        local bp = LP:FindFirstChild("Backpack")
        local pg = LP:FindFirstChildOfClass("PlayerGui")
        pcall(function()
            if char then
                table.insert(conns, char.ChildAdded:Connect(function()
                    if isPlayerCarryingEgg() then fireInstantNow() end
                end))
            end
            if bp then
                table.insert(conns, bp.ChildAdded:Connect(function()
                    if isPlayerCarryingEgg() then fireInstantNow() end
                end))
            end
            if pg then
                table.insert(conns, pg.ChildAdded:Connect(function(c)
                    if c.Name == "DropHeldEgg" then fireInstantNow() end
                end))
                local dg = pg:FindFirstChild("DropHeldEgg")
                if dg then
                    table.insert(conns, dg:GetPropertyChangedSignal("Enabled"):Connect(function()
                        if dg.Enabled then fireInstantNow() end
                    end))
                end
            end
        end)
    end
    local maxWait = isInstantTP and 1.2 or 1.5
    while os.clock() - tPickup < maxWait and not HUB.dead do
        if carried or instantFired then carried = true; break end
        if isPlayerCarryingEgg() then carried = true; break end
        pcall(function()
            if EggState and EggState.CarryFieldEgg then
                EggState.CarryFieldEgg(record.Uid, slotKey)
            end
        end)
        if prompt then
            prompt.HoldDuration = 0
            pcall(function() fireproximityprompt(prompt) end)
        end
        if isInstantTP then task.wait() else task.wait(0.08) end
    end
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end

    if not carried then
        ignoredEggs[record.Uid] = os.clock()
        if isInstantTP then
            bypassReturnTP(safeCFrame, 0.2)
            restoreCollisions()
        end
        return false
    end

    -- Guard-hit double pickup trick
    do
        local guardHitEnabled = true
        if guardHitEnabled and carried then
            local tGuardStart = os.clock()
            local startHealth = 100
            local hum0 = findHum()
            if hum0 then startHealth = hum0.Health end
            local wasHit = false
            while os.clock() - tGuardStart < 4.0 and not HUB.dead do
                if not isPlayerCarryingEgg() then wasHit = true; break end
                local h = findHum()
                if h then
                    local hs = h:GetState()
                    if h.Health < startHealth - 1.5 or hs == Enum.HumanoidStateType.Physics or hs == Enum.HumanoidStateType.Ragdoll or hs == Enum.HumanoidStateType.FallingDown then
                        wasHit = true
                        local tPost = os.clock()
                        while os.clock() - tPost < 0.85 and not HUB.dead do
                            if not isPlayerCarryingEgg() then break end
                            task.wait(0.05)
                        end
                        break
                    end
                end
                task.wait(0.05)
            end

            if wasHit or not isPlayerCarryingEgg() then
                task.wait(0.65)
                do
                    local tRag = os.clock()
                    while os.clock() - tRag < 3.2 and not HUB.dead do
                        local h = findHum()
                        if not h then break end
                        local hs = h:GetState()
                        if hs ~= Enum.HumanoidStateType.Physics and hs ~= Enum.HumanoidStateType.Ragdoll and hs ~= Enum.HumanoidStateType.FallingDown then break end
                        pcall(function() h:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                        task.wait(0.12)
                    end
                    task.wait(0.35)
                end
                local hrpNow = findHRP()
                if hrpNow and (hrpNow.Position - targetPos).Magnitude > 14 then
                    pcall(function()
                        hrpNow.CFrame = CFrame.new(targetPos + Vector3.new(0, 1.8, 0))
                        hrpNow.AssemblyLinearVelocity = Vector3.zero
                        hrpNow.AssemblyAngularVelocity = Vector3.zero
                    end)
                    task.wait(0.35)
                end
                do
                    local tStand = os.clock()
                    while os.clock() - tStand < 1.5 and not HUB.dead do
                        local h = findHum()
                        if h and h:GetState() ~= Enum.HumanoidStateType.Physics and h:GetState() ~= Enum.HumanoidStateType.Ragdoll then break end
                        task.wait(0.08)
                    end
                end
                do
                    local tGuardSleep = os.clock()
                    while os.clock() - tGuardSleep < 4.5 and not HUB.dead do
                        local guardAsleep = false
                        pcall(function()
                            local areasRoot = Workspace:FindFirstChild("__OBJECTS") and Workspace.__OBJECTS:FindFirstChild("Areas") and Workspace.__OBJECTS.Areas:FindFirstChild("GuardAreas")
                            local guardModel = nil
                            if areasRoot and record.AreaId then
                                local areaFolder = areasRoot:FindFirstChild(record.AreaId)
                                if areaFolder then
                                    guardModel = areaFolder:FindFirstChild("Guard") or areaFolder:FindFirstChild("ForestGuardAuthored") or areaFolder:FindFirstChildWhichIsA("Model", true)
                                end
                            end
                            if not guardModel then
                                local nearest, nd = nil, 1e9
                                for _, m in ipairs(Workspace:GetDescendants()) do
                                    if m:IsA("Model") and m.Name:lower():find("guard") and m.PrimaryPart then
                                        local d = (m.PrimaryPart.Position - targetPos).Magnitude
                                        if d < nd and d < 90 then nd = d; nearest = m end
                                    end
                                end
                                guardModel = nearest
                            end
                            if guardModel then
                                local alert = guardModel:GetAttribute("Alert") or guardModel:GetAttribute("Alerted") or guardModel:GetAttribute("IsAlerted") or guardModel:GetAttribute("Chasing")
                                local sleeping = guardModel:GetAttribute("Sleeping") or guardModel:GetAttribute("IsSleeping") or guardModel:GetAttribute("Asleep") or guardModel:GetAttribute("Sleep")
                                local state = guardModel:GetAttribute("State")
                                if sleeping == true then guardAsleep = true
                                elseif alert == false or alert == nil then
                                    local hum = guardModel:FindFirstChildOfClass("Humanoid")
                                    local hrp = guardModel.PrimaryPart or guardModel:FindFirstChild("HumanoidRootPart") or guardModel:FindFirstChildWhichIsA("BasePart", true)
                                    local eggPoint = guardModel:FindFirstChild("EggPoint", true)
                                    if hrp and eggPoint then
                                        local distToHome = (hrp.Position - eggPoint.Position).Magnitude
                                        if distToHome < 7 and (not hum or hum.MoveDirection.Magnitude < 0.12) then
                                            guardAsleep = true
                                        elseif distToHome < 12 and os.clock() - tGuardSleep > 1.2 and (not hum or hum.MoveDirection.Magnitude < 0.15) then
                                            guardAsleep = true
                                        end
                                    elseif state and tostring(state):lower():find("sleep") then guardAsleep = true
                                    elseif alert == nil and sleeping == nil and state == nil then
                                        if os.clock() - tGuardSleep > 1.6 then guardAsleep = true end
                                    elseif alert == false then guardAsleep = true
                                    end
                                end
                                if not guardAsleep then
                                    local alertGui = guardModel:FindFirstChild("Alert", true)
                                    if alertGui and alertGui:IsA("BillboardGui") and alertGui.Enabled == false then guardAsleep = true end
                                end
                            else
                                if os.clock() - tGuardSleep > 1.4 then guardAsleep = true end
                            end
                        end)
                        if guardAsleep then break end
                        task.wait(0.14)
                    end
                    task.wait(0.08)
                end
                task.wait(0.08)
                pcall(function()
                    if carryRemote then carryRemote:InvokeServer({ Uid = record.Uid, FirstAreaSlotKey = slotKey }) end
                end)
                pcall(function()
                    if EggState and EggState.CarryFieldEgg then EggState.CarryFieldEgg(record.Uid, slotKey) end
                end)
                task.wait(0.08)
                local prompt2 = nil
                for _, d in ipairs(Workspace:GetDescendants()) do
                    if d:IsA("ProximityPrompt") and d.Name == "CarryAreaEgg" and d.Enabled then
                        local p = d.Parent
                        if p and p:IsA("Attachment") then p = p.Parent end
                        if p then
                            local dist = (p.Position - (findHRP() and findHRP().Position or targetPos)).Magnitude
                            if dist < 16 then
                                local act = (d.ActionText or ""):lower()
                                if not act:find("skip") and not act:find("robux") then
                                    prompt2 = d
                                    break
                                end
                            end
                        end
                    end
                end
                if prompt2 then
                    prompt2.HoldDuration = 0
                    pcall(function() fireproximityprompt(prompt2) end)
                    pcall(function() fireproximityprompt(prompt2, 0) end)
                else
                    for _, d in ipairs(Workspace:GetDescendants()) do
                        if d:IsA("ProximityPrompt") and d.Name == "CarryAreaEgg" and d.Enabled then
                            local p = d.Parent
                            if p and p:IsA("Attachment") then p = p.Parent end
                            if p and (p.Position - (findHRP() and findHRP().Position or targetPos)).Magnitude < 18 then
                                d.HoldDuration = 0                                pcall(function() fireproximityprompt(d) end)
                                task.wait(0.08)
                                if isPlayerCarryingEgg() then break end
                            end
                        end
                    end
                end
                local tPickup2 = os.clock()
                while os.clock() - tPickup2 < 2.2 and not HUB.dead do
                    if isPlayerCarryingEgg() then carried = true break end
                    pcall(function()
                        if EggState and EggState.CarryFieldEgg then EggState.CarryFieldEgg(record.Uid, slotKey) end
                    end)
                    if prompt2 then pcall(function() fireproximityprompt(prompt2) end) end
                    task.wait(0.06)
                end
                if isPlayerCarryingEgg() then carried = true end
                if isPlayerCarryingEgg() then
                    task.wait(0.12)
                    isInstantTP = false
                else
                    task.wait(0.12)
                    for _, d in ipairs(Workspace:GetDescendants()) do
                        if d:IsA("ProximityPrompt") and d.Name == "CarryAreaEgg" and d.Enabled then
                            local p = d.Parent
                            if p and p:IsA("Attachment") then p = p.Parent end
                            if p and (p.Position - (findHRP() and findHRP().Position or targetPos)).Magnitude < 18 then
                                d.HoldDuration = 0
                                pcall(function() fireproximityprompt(d) end)
                            end
                        end
                    end
                    task.wait(0.12)
                    if isPlayerCarryingEgg() then carried = true isInstantTP = false end
                end
            end
        end
    end

    if isInstantTP then
        if not instantFired then
            bypassReturnTP(safeCFrame, 0.35)
            task.spawn(function()
                pcall(restoreCollisions)
                pcall(PlantAllCarriedEggsInPen)
            end)
        end
    else
        if speed > 250 then
            local hrpNow = findHRP()
            local curPos = hrpNow and hrpNow.Position or targetPos
            local toBase = safePlotCenter - curPos
            local distBase = toBase.Magnitude
            if distBase > 45 then
                local stagePos = safePlotCenter - toBase.Unit * 35
                stagePos = Vector3.new(stagePos.X, math.max(stagePos.Y, 70.4), stagePos.Z)
                TravelToDestination(stagePos, speed, false)
                local hrp2 = findHRP()
                if hrp2 then
                    hrp2.AssemblyLinearVelocity = Vector3.zero
                    hrp2.AssemblyAngularVelocity = Vector3.zero
                end
                task.wait(0.35)
            end
            TravelToDestination(safePlotCenter, 240, true)
        else
            TravelToDestination(safePlotCenter, speed, true)
        end
    end

    local tDeliver = os.clock()
    while os.clock() - tDeliver < 1.5 and isPlayerCarryingEgg() and not HUB.dead do
        task.wait(0.08)
    end

    PlantAllCarriedEggsInPen()

    local char = LP.Character
    local h = char and char:FindFirstChild("HumanoidRootPart")
    local hu = char and char:FindFirstChildOfClass("Humanoid")
    if h then
        h.CFrame = CFrame.new(safePlotCenter.X, math.max(safePlotCenter.Y, 70.4), safePlotCenter.Z)
        h.AssemblyLinearVelocity = Vector3.zero
        h.AssemblyAngularVelocity = Vector3.zero
    end
    if hu then
        hu.PlatformStand = false
        hu.AutoRotate = true
        pcall(function() hu:ChangeState(Enum.HumanoidStateType.Running) end)
    end

    return carried or isPlayerCarryingEgg()
end

local function StealBestEggOnce()
    pcall(HatchAllReadyEggs)
    local eggs = GetMatchingFieldEggs(selectedStealAreas, selectedStealRarities, selectedMutationTypes)
    if #eggs == 0 then return false end
    local target = eggs[1]
    return StealSpecificEggRobust(target)
end

local function HatchAllReadyEggs()
    if not EggState or not EggState.ReadOwnedEggs then return 0 end
    local ok, snapshot = pcall(EggState.ReadOwnedEggs, LP.UserId)
    if not ok or not snapshot then return 0 end

    local count = 0
    local records = snapshot.Records or snapshot
    if typeof(records) == "table" then
        for uid, eggData in pairs(records) do
            if typeof(eggData) == "table" then
                local isReady = false
                if EggState.IsReadyToHatch then
                    isReady = EggState.IsReadyToHatch(eggData)
                else
                    isReady = eggData.Placement ~= nil
                end
                if isReady then
                    pcall(function()
                        if EggState.BeginHatch then EggState.BeginHatch(uid) end
                        task.wait(0.05)
                        if EggState.FinishHatch then EggState.FinishHatch(uid) end
                        count = count + 1
                    end)
                end
            end
        end
    end
    return count
end

-- ==============================================================================
-- BASE, HOMESTEAD & REWARDS AUTOMATION LOGIC
-- ==============================================================================
local function UpgradeHomesteadBase()
    local re1 = GetNetRemote("RE/Homestead/AskNearbyPurchase")
    if re1 then pcall(function() re1:FireServer() end) end
    local re2 = GetNetRemote("RE/Homestead/AskBaseTierRaise")
    if re2 then pcall(function() re2:FireServer() end) end
end

local function UpgradeTreadmillTier()
    local rf = GetNetRemote("RF/Treadmill/AskTierRaise")
    if rf then pcall(function() rf:InvokeServer() end) end
end

local function EquipBestPets()
    local rf = GetNetRemote("RF/Haul/WearBest") or GetNetRemote("RF/PenRoster/ConfirmEquipBestBadge")
    if rf then pcall(function() rf:InvokeServer() end) end
end

local function GetMyMonsterPosition()
    local myMonster = Workspace:FindFirstChild("MonsterParasiteMonsters") and Workspace.MonsterParasiteMonsters:FindFirstChild("Monster_" .. LP.UserId)
    if myMonster then
        local pos = (myMonster.PrimaryPart and myMonster.PrimaryPart.Position) or myMonster:GetPivot().Position
        return pos
    end
    local standPad = Workspace:FindFirstChild("Stands") and Workspace.Stands:FindFirstChild("Pads") and Workspace.Stands.Pads:FindFirstChild("Monster")
    if standPad then return standPad.Position end
    return Vector3.new(545.1, 68.0, -413.4)
end

local function ClaimMonsterChests()
    pcall(function()
        local rf1 = GetNetRemote("RF/MonsterParasite/AskChestClaim")
        if rf1 then rf1:InvokeServer() end
        local rf2 = GetNetRemote("RF/MonsterParasite/AskChestTake")
        if rf2 then rf2:InvokeServer() end
    end)
end

local function FeedMonsterParasite()
    local rf = GetNetRemote("RF/MonsterParasite/AskFeed")
    if not rf then return false end
    local hrp = findHRP()
    if not hrp then return false end

    local mPos = GetMyMonsterPosition()
    local dist = (hrp.Position - mPos).Magnitude
    local savedSpot = nil

    if dist > 12 then
        savedSpot = hrp.CFrame
        TravelToDestination(mPos + Vector3.new(0, 1.2, 0), glideSpeed or 200, true)
        task.wait(0.08)
    end

    local ok, res = pcall(function() return rf:InvokeServer() end)

    if savedSpot then
        task.wait(0.1)
        TravelToDestination(savedSpot.Position, glideSpeed or 200, true)
        local h = findHRP()
        if h then h.CFrame = savedSpot end
    end

    return ok and res
end

local function DropHeldEgg()
    local rf = GetNetRemote("RF/EggWorld/AskFieldEggDrop")
    if rf then pcall(function() rf:InvokeServer() end) end
    if EggState and EggState.DropFieldEgg then pcall(EggState.DropFieldEgg) end
end

local function BuyAffordableTrails()
    local rf = GetNetRemote("RF/Trailwear/AskPurchase")
    local TrailsData = RS:FindFirstChild("Data") and RS.Data:FindFirstChild("Trails") and require(RS.Data.Trails)
    local save = nil
    pcall(function() save = SaveModule and SaveModule.Get and SaveModule.Get() end)
    if not rf or not TrailsData or not save then return end

    local myMoney = tonumber(save.Money) or 0
    local inv = save.TrailInventory or {}

    for _, t in pairs(TrailsData.Directory or TrailsData) do
        if type(t) == "table" and t._id and not inv[t._id] then
            local price = tonumber(t.Price) or math.huge
            if myMoney >= price then
                pcall(function() rf:InvokeServer(t._id) end)
                task.wait(0.25)
            end
        end
    end
end

local instantPickupConn = nil
local function SetupInstantPickup(enabled)
    instantPickupEnabled = enabled
    local ProximityPromptService = game:GetService("ProximityPromptService")
    if enabled and not instantPickupConn then
        instantPickupConn = track(ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, player)
            if player == LP and prompt.Name == "CarryAreaEgg" then
                prompt.HoldDuration = 0
            end
        end))
    elseif not enabled and instantPickupConn then
        pcall(function() instantPickupConn:Disconnect() end)
        instantPickupConn = nil
    end
end

local function SetNoKnockback(enabled)
    noKnockbackEnabled = enabled
    if enabled then
        pcall(function()
            local rigSync = GetNetRemote("RE/RigSync/Refresh")
            if rigSync and getconnections then
                for _, conn in ipairs(getconnections(rigSync.OnClientEvent)) do
                    pcall(function() conn:Disconnect() end)
                end
            end
        end)
    end
end

pcall(function() if avoidTrapsEnabled then NeutralizeTraps() end end)
pcall(function() if instantPickupEnabled then SetupInstantPickup(true) end end)
pcall(function() if noKnockbackEnabled then SetNoKnockback(true) end end)

local function SellSelectedPets()
    local re = GetNetRemote("RE/PetSatchel/SellPet")
    if not re or not SaveModule then return end
    local save = nil
    pcall(function() save = SaveModule.Get and SaveModule.Get() end)
    local inv = save and save.Inventory
    if type(inv) ~= "table" then return end

    for uid, petData in pairs(inv) do
        if type(petData) == "table" and not petData.Locked then
            local rName = petData.Rarity or "Common"
            if isRarityAllowed(rName, getSellRarityFilter(selectedSellPetRarities)) then
                pcall(function() re:FireServer(uid) end)
                task.wait(0.08)
            end
        end
    end
end

local function SellSelectedEggs()
    if not SaveModule then return end
    local save = nil
    pcall(function() save = SaveModule.Get and SaveModule.Get() end)
    if not save then return end
    local inv = save.EggInventory
    if type(inv) ~= "table" then return end

    local wear = GetNetRemote("RF/EggWorld/AskWearTool")
    local sell = GetNetRemote("RE/PetSatchel/SellPet")
    if not wear or not sell then return end

    for uid, eggData in pairs(inv) do
        if type(eggData) == "table" and not eggData.Placement and not eggData.Locked then
            local rName = GetEggRarityInfo(eggData)
            if isRarityAllowed(rName, getSellRarityFilter(selectedSellEggRarities)) then
                pcall(function() wear:InvokeServer(uid) end)
                pcall(function() sell:FireServer({ uid }) end)
                task.wait(SELL_REQUEST_DELAY)
            end
        end
    end
end

local function DeleteOwnPetRenders()
    local count = 0
    local function sweep(container)
        if not container then return end
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Model") or child:IsA("BasePart") then
                pcall(function() child:Destroy(); count = count + 1 end)
            end
        end
    end
    sweep(Workspace:FindFirstChild("Pets"))
    sweep(Workspace:FindFirstChild("RenderedPets"))
    return count
end

local function ClaimAllAvailableRewards()
    pcall(function()
        local rf1 = GetNetRemote("RF/AwayEarnings/AskCollect")
        if rf1 then rf1:InvokeServer() end
    end)
    pcall(function()
        local rf2 = GetNetRemote("RF/Codex/AskRedeemAll")
        if rf2 then rf2:InvokeServer() end
    end)
    pcall(function()
        local rf3 = GetNetRemote("RF/GroupPerk/RedeemPerk")
        if rf3 then rf3:InvokeServer() end
    end)
    pcall(ClaimMonsterChests)
end

-- ==============================================================================
-- WORKER LOOPS
-- ==============================================================================
task.spawn(function()
    while not HUB.dead do
        if autoStealEnabled then pcall(StealBestEggOnce) end
        task.wait(stealDelay)
    end
end)

task.spawn(function()
    while not HUB.dead do
        if autoHatchEnabled then pcall(HatchAllReadyEggs) end
        if autoPlantEnabled then pcall(PlantAllCarriedEggsInPen) end
        task.wait(hatchCheckDelay)
    end
end)

task.spawn(function()
    while not HUB.dead do
        if autoUpgradeBase then pcall(UpgradeHomesteadBase) end
        if autoUpgradeTreadmill then pcall(UpgradeTreadmillTier) end
        if autoEquipBestPets then pcall(EquipBestPets) end
        if autoClaimRewards then pcall(ClaimAllAvailableRewards) end
        if autoClaimMonsterChests then pcall(ClaimMonsterChests) end
        if autoFeedMonster then pcall(FeedMonsterParasite) end
        if autoSellPets then pcall(SellSelectedPets) end
        if autoSellEggs then pcall(SellSelectedEggs) end
        task.wait(2.5)
    end
end)

task.spawn(function()
    local batRe = GetNetRemote("RE/BatSwing/Trigger")
    while not HUB.dead do
        if batAuraEnabled and batRe then
            local hrp = findHRP()
            if hrp then
                local foundNearby = false
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LP and p.Character then
                        local oHrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if oHrp and (oHrp.Position - hrp.Position).Magnitude <= batAuraRadius then
                            foundNearby = true
                            break
                        end
                    end
                end
                if foundNearby then pcall(function() batRe:FireServer() end) end
            end
        end
        task.wait(batAuraDelay)
    end
end)

task.spawn(function()
    local debris = Workspace:FindFirstChild("__DEBRIS")
    if debris then
        track(debris.ChildAdded:Connect(function(child)
            if avoidTrapsEnabled and child.Name == "PlayerTrap" then
                task.wait(0.05)
                if child:GetAttribute("Owner") ~= LP.Name then
                    if child:IsA("BasePart") then child.CanTouch = false end
                    for _, c in ipairs(child:GetChildren()) do
                        if c:IsA("BasePart") then c.CanTouch = false end
                    end
                end
            end
        end))
    end

    while not HUB.dead do
        if avoidTrapsEnabled or autoStealEnabled then pcall(NeutralizeTraps) end
        task.wait(1.5)
    end
end)

-- ==============================================================================
-- VISUALS & ESP
-- ==============================================================================
local esp = {
    enabled         = false,
    eggs            = true,
    traps           = false,
    players         = false,
    guards          = false,
    rareEggsOnly    = false,
    showPetIcons    = true,
    maxDistance     = 800,

    eggColor        = Color3.fromRGB(255, 200, 50),
    rareEggColor    = Color3.fromRGB(255, 60, 220),
    trapColor       = Color3.fromRGB(255, 60, 60),
    playerColor     = Color3.fromRGB(100, 220, 100),
    guardColor      = Color3.fromRGB(255, 60, 60),
}

local hasDrawing = type(Drawing) == "table" and type(Drawing.new) == "function"
local trackedEspObjects = {}
local espBillboards = {}
local espContainer = nil

local function getEspContainer()
    if espContainer and espContainer.Parent then return espContainer end
    local p = nil
    pcall(function() p = (gethui and gethui()) end)
    if not p then pcall(function() p = game:GetService("CoreGui") end) end
    if not p then p = LP:FindFirstChild("PlayerGui") or Workspace end

    pcall(function()
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("Folder") and c.Name == "SAE_Esp_Holder" then c:Destroy() end
        end
    end)
    espContainer = Instance.new("Folder")
    espContainer.Name = "SAE_Esp_Holder"
    pcall(function() espContainer.Parent = p end)
    return espContainer
end

local function updateEggBillboard(key, pos, icon)
    local bb = espBillboards[key]
    if not bb or not bb.gui or not bb.gui.Parent then
        local holder = getEspContainer()
        local part = Instance.new("Part")
        part.Name = "EspAnchor"
        part.Size = Vector3.new(1, 1, 1)
        part.Transparency = 1
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.CFrame = CFrame.new(pos)
        part.Parent = holder

        local gui = Instance.new("BillboardGui")
        gui.Name = "EggIconBillboard"
        gui.Adornee = part
        gui.Size = UDim2.fromOffset(28, 28)
        gui.StudsOffset = Vector3.new(-2.2, 1.2, 0)
        gui.AlwaysOnTop = true
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.Parent = part

        local img = Instance.new("ImageLabel")
        img.Name = "PetImage"
        img.Size = UDim2.fromScale(1, 1)
        img.BackgroundTransparency = 1
        img.ScaleType = Enum.ScaleType.Fit
        img.Image = icon or ""
        img.Parent = gui

        bb = { part = part, gui = gui, img = img }
        espBillboards[key] = bb
    else
        bb.part.CFrame = CFrame.new(pos)
        bb.img.Image = icon or ""
        bb.gui.Enabled = (icon ~= nil and icon ~= "")
    end
    return bb
end

local function createDrawingObject()
    if not hasDrawing then return {} end
    local o = {}
    o.name = trackDrawing(Drawing.new("Text"))
    o.name.Size = 13; o.name.Center = true; o.name.Outline = true; o.name.Visible = false

    o.dist = trackDrawing(Drawing.new("Text"))
    o.dist.Size = 11; o.dist.Center = true; o.dist.Outline = true; o.dist.Visible = false

    o.box = trackDrawing(Drawing.new("Square"))
    o.box.Thickness = 1.5; o.box.Filled = false; o.box.Visible = false

    return o
end

track(RunService.RenderStepped:Connect(function()
    if HUB.dead or not esp.enabled then
        for _, obj in pairs(trackedEspObjects) do
            if obj.name then obj.name.Visible = false end
            if obj.dist then obj.dist.Visible = false end
            if obj.box then obj.box.Visible = false end
        end
        for _, bb in pairs(espBillboards) do
            if bb.gui then bb.gui.Enabled = false end
        end
        return
    end

    local hrp = findHRP()
    local myPos = hrp and hrp.Position or Vector3.zero
    local renderItems = {}
    local activeBbKeys = {}

    if esp.eggs and EggState and EggState.ReadFieldEggs then
        local ok, snap = pcall(EggState.ReadFieldEggs)
        if ok and snap and snap.Records then
            for _, egg in ipairs(snap.Records) do
                if egg.State == "Slot" and egg.BoundsCFrame then
                    local pos = egg.BoundsCFrame.Position
                    local dist = (pos - myPos).Magnitude
                    if esp.maxDistance <= 0 or dist <= esp.maxDistance then
                        local muts = egg.Mutations or {}
                        local isRare = #muts > 0
                        if not esp.rareEggsOnly or isRare then
                            local mutText = isRare and (" [" .. table.concat(muts, ",") .. "]") or ""
                            local rName = GetEggRarityInfo(egg)
                            local label = (egg.AssetCategory or "Egg") .. " (" .. rName .. ")" .. mutText
                            local cat = egg.AssetCategory
                            local aInfo = AssetsData and (AssetsData.Directory or AssetsData) and (AssetsData.Directory or AssetsData)[cat]
                            local petIcon = aInfo and (aInfo.Icon or (aInfo.Egg and aInfo.Egg.Icon)) or ""

                            table.insert(renderItems, {
                                Key = egg.Uid,
                                Pos = pos,
                                Name = label,
                                Color = isRare and esp.rareEggColor or esp.eggColor,
                                Dist = dist,
                            })

                            if esp.showPetIcons and petIcon ~= "" then
                                activeBbKeys[egg.Uid] = true
                                updateEggBillboard(egg.Uid, pos, petIcon)
                            end
                        end
                    end
                end
            end
        end
    end

    if esp.traps then
        local debris = Workspace:FindFirstChild("__DEBRIS")
        if debris then
            for _, trap in ipairs(debris:GetChildren()) do
                if trap.Name == "PlayerTrap" and trap:IsA("BasePart") then
                    local pos = trap.Position
                    local dist = (pos - myPos).Magnitude
                    if esp.maxDistance <= 0 or dist <= esp.maxDistance then
                        local owner = trap:GetAttribute("Owner") or "Enemy"
                        table.insert(renderItems, {
                            Key = trap,
                            Pos = pos + Vector3.new(0, 1.5, 0),
                            Name = "[TRAP] @" .. owner,
                            Color = esp.trapColor,
                            Dist = dist,
                        })
                    end
                end
            end
        end
    end

    if esp.players then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                local oHrp = p.Character:FindFirstChild("HumanoidRootPart")
                if oHrp then
                    local dist = (oHrp.Position - myPos).Magnitude
                    if esp.maxDistance <= 0 or dist <= esp.maxDistance then
                        table.insert(renderItems, {
                            Key = p,
                            Pos = oHrp.Position,
                            Name = p.DisplayName .. " (@" .. p.Name .. ")",
                            Color = esp.playerColor,
                            Dist = dist,
                        })
                    end
                end
            end
        end
    end

    for k, bb in pairs(espBillboards) do
        if not activeBbKeys[k] and bb.gui then bb.gui.Enabled = false end
    end

    local cam = GetCamera()
    local activeKeys = {}
    for _, item in ipairs(renderItems) do
        activeKeys[item.Key] = true
        local obj = trackedEspObjects[item.Key]
        if not obj then
            obj = createDrawingObject()
            trackedEspObjects[item.Key] = obj
        end

        local screenPos, onScreen = nil, false
        if cam then screenPos, onScreen = cam:WorldToViewportPoint(item.Pos) end
        if onScreen and hasDrawing and screenPos then
            if obj.name then
                obj.name.Text = item.Name
                obj.name.Position = Vector2.new(screenPos.X, screenPos.Y - 14)
                obj.name.Color = item.Color
                obj.name.Visible = true
            end
            if obj.dist then
                obj.dist.Text = math.floor(item.Dist) .. " studs"
                obj.dist.Position = Vector2.new(screenPos.X, screenPos.Y + 2)
                obj.dist.Color = Color3.fromRGB(220, 220, 220)
                obj.dist.Visible = true
            end
        else
            if obj.name then obj.name.Visible = false end
            if obj.dist then obj.dist.Visible = false end
            if obj.box then obj.box.Visible = false end
        end
    end

    for k, obj in pairs(trackedEspObjects) do
        if not activeKeys[k] then
            if obj.name then obj.name.Visible = false end
            if obj.dist then obj.dist.Visible = false end
            if obj.box then obj.box.Visible = false end
        end
    end
end))

local fullbrightEnabled = false
local defaultAmbient = Lighting.Ambient
local defaultOutdoor = Lighting.OutdoorAmbient
local defaultBrightness = Lighting.Brightness
local defaultClockTime = Lighting.ClockTime

local function SetFullbright(v)
    fullbrightEnabled = v
    if v then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
    else
        Lighting.Ambient = defaultAmbient
        Lighting.OutdoorAmbient = defaultOutdoor
        Lighting.Brightness = defaultBrightness
        Lighting.ClockTime = defaultClockTime
    end
end

-- ==============================================================================
-- MOVEMENT & PLAYER MODIFIERS
-- ==============================================================================
local walkSpeedEnabled = false
local walkSpeedVal     = 24
local jumpPowerEnabled = false
local jumpPowerVal     = 60
local infiniteJump     = false
local flying           = false
local flySpeed         = 60
local antiAFK          = false

local function ApplyWalkSpeed(v)
    walkSpeedVal = v
    local hum = findHum()
    if hum and walkSpeedEnabled then hum.WalkSpeed = v end
end

local function ApplyJumpPower(v)
    jumpPowerVal = v
    local hum = findHum()
    if hum and jumpPowerEnabled then
        hum.UseJumpPower = true
        hum.JumpPower = v
    end
end

track(RunService.Stepped:Connect(function()
    if HUB.dead then return end
    local hum = findHum()
    if hum then
        if walkSpeedEnabled then hum.WalkSpeed = walkSpeedVal end
        if jumpPowerEnabled then hum.UseJumpPower = true; hum.JumpPower = jumpPowerVal end
    end
end))

track(UserInputService.JumpRequest:Connect(function()
    if HUB.dead then return end
    local hum = findHum()
    if hum then
        hum.Jump = true
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end))

local function startFly()
    if flying then return end
    local hrp = findHRP()
    local hum = findHum()
    if not (hrp and hum) then return end
    flying = true
    hrp.Anchored = true

    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1, 1, 1) * 1e5
    bodyGyro.P = 1e5
    bodyGyro.CFrame = hrp.CFrame
    bodyGyro.Parent = hrp

    HUB._fly = {
        hrp = hrp,
        gyro = bodyGyro,
        conn = track(RunService.RenderStepped:Connect(function(dt)
            if not flying or HUB.dead then return end
            local cam = GetCamera()
            if not cam then return end
            local look = cam.CFrame.LookVector
            local right = cam.CFrame.RightVector
            local flatLook = Vector3.new(look.X, 0, look.Z)
            flatLook = flatLook.Magnitude > 0.001 and flatLook.Unit or Vector3.new(0, 0, -1)
            local flatRight = Vector3.new(right.X, 0, right.Z)
            flatRight = flatRight.Magnitude > 0.001 and flatRight.Unit or Vector3.new(1, 0, 0)

            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + flatLook end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - flatLook end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - flatRight end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + flatRight end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end

            if dir.Magnitude > 0 then
                hrp.CFrame = hrp.CFrame + dir.Unit * flySpeed * math.min(dt, 0.1)
            end
            bodyGyro.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + look)
        end))
    }
end

local function stopFly()
    flying = false
    local f = HUB._fly
    if f then
        pcall(function() f.conn:Disconnect() end)
        pcall(function() f.hrp.Anchored = false end)
        pcall(function() f.gyro:Destroy() end)
        HUB._fly = nil
    end
end

local antiAfkConn = nil
local function SetAntiAFK(v)
    antiAFK = v
    if v and not antiAfkConn then
        antiAfkConn = track(LocalPlayer.Idled:Connect(function()
            if antiAFK then
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end
        end))
    elseif not v and antiAfkConn then
        pcall(function() antiAfkConn:Disconnect() end)
        antiAfkConn = nil
    end
end

-- ==============================================================================
-- UI CREATION
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- INFO TAB
-- -----------------------------------------------------------------------------
local InfoGroup = Tabs.Info:AddLeftGroupbox("Account Info", "user")
local LinksGroup = Tabs.Info:AddRightGroupbox("Links", "link")

local executorName = "Unknown"
pcall(function()
    if identifyexecutor then
        executorName = identifyexecutor()
    elseif getexecutorname then
        executorName = getexecutorname()
    end
end)

InfoGroup:AddLabel("Username: " .. LP.Name)
InfoGroup:AddLabel("Display Name: " .. LP.DisplayName)
InfoGroup:AddLabel("User ID: " .. tostring(LP.UserId))
InfoGroup:AddLabel("Executor: " .. tostring(executorName))
InfoGroup:AddLabel('Script Type: <font color="#FF0000">Freemium</font>', false)

LinksGroup:AddButton({
    Text = "Join Discord",
    Func = function()
        setclipboard("https://discord.com/invite/8CVAGERzNy")
        Notify("Discord", "Invite link copied!", "Success")
    end,
})


-- -----------------------------------------------------------------------------
-- EGGS TAB
-- -----------------------------------------------------------------------------
local StealGroup = Tabs.Eggs:AddLeftGroupbox("Auto Steal", "crown")
local HatchGroup = Tabs.Eggs:AddLeftGroupbox("Auto Hatch & Plant", "package")
local EggEspGroup = Tabs.Eggs:AddRightGroupbox("Egg Tracker ESP", "eye")

StealGroup:AddToggle("steal_auto", {
    Text = "Auto Steal Eggs",
    Default = false,
    Tooltip = "Automatically steal matching eggs",
})
Toggles.steal_auto:OnChanged(function()
    autoStealEnabled = Toggles.steal_auto.Value
    if autoStealEnabled then EnsureSavedReturnPosition() end
    Notify("Auto Steal", autoStealEnabled and "Enabled" or "Disabled", autoStealEnabled and "Success" or "Error")
end)

StealGroup:AddDropdown("steal_method", {
    Text = "Steal Movement Method",
    Values = { "Tween Glide", "Fly Glide", "Safe Walk", "Anti Guard" },
    Default = "Tween Glide",
    Multi = false,
})
Options.steal_method:OnChanged(function()
    stealMovementMethod = Options.steal_method.Value
end)

StealGroup:AddToggle("steal_parasite_only", {
    Text = "Parasite / Infested Only",
    Default = false,
})
Toggles.steal_parasite_only:OnChanged(function()
    stealParasiteOnly = Toggles.steal_parasite_only.Value
end)

StealGroup:AddToggle("instant_pickup", {
    Text = "Instant Prompt Pickup",
    Default = true,
})
Toggles.instant_pickup:OnChanged(function()
    SetupInstantPickup(Toggles.instant_pickup.Value)
end)

StealGroup:AddToggle("rare_hunter", {
    Text = "Rare Egg Hunter (Highest Rarity First)",
    Default = true,
})
Toggles.rare_hunter:OnChanged(function()
    rareEggHunter = Toggles.rare_hunter.Value
end)

StealGroup:AddDropdown("steal_rarities", {
    Text = "Filter by Rarity",
    Values = RARITY_NAMES,
    Default = {},
    Multi = true,
})
Options.steal_rarities:OnChanged(function()
    selectedStealRarities = Options.steal_rarities.Value
end)

StealGroup:AddDropdown("steal_areas", {
    Text = "Filter by Area",
    Values = AREA_NAMES,
    Default = {},
    Multi = true,
})
Options.steal_areas:OnChanged(function()
    selectedStealAreas = Options.steal_areas.Value
end)

StealGroup:AddDropdown("steal_muts", {
    Text = "Filter by Mutation",
    Values = MUTATION_FILTERS,
    Default = {},
    Multi = true,
})
Options.steal_muts:OnChanged(function()
    selectedMutationTypes = Options.steal_muts.Value
end)

StealGroup:AddSlider("glide_speed", {
    Text = "Glide / Travel Speed",
    Default = 750,
    Min = 50,
    Max = 750,
    Rounding = 0,
    Suffix = " studs/s",
})
Options.glide_speed:OnChanged(function()
    glideSpeed = tonumber(Options.glide_speed.Value) or 750
end)

StealGroup:AddSlider("steal_gap", {
    Text = "Steal Delay Gap",
    Default = 1.5,
    Min = 0.5,
    Max = 10,
    Rounding = 1,
    Suffix = "s",
})
Options.steal_gap:OnChanged(function()
    stealDelay = Options.steal_gap.Value
end)

StealGroup:AddButton({
    Text = "Steal Best Available Egg Once",
    Func = function()
        local ok = StealBestEggOnce()
        Notify("Steal Egg", ok and "Stealing target egg" or "No matching egg found", ok and "Success" or "Info")
    end,
})

-- Hatch group
HatchGroup:AddToggle("hatch_auto", {
    Text = "Auto Hatch Ready Eggs",
    Default = false,
})
Toggles.hatch_auto:OnChanged(function()
    autoHatchEnabled = Toggles.hatch_auto.Value
end)

HatchGroup:AddToggle("plant_auto", {
    Text = "Auto Place Egg (Base Pen)",
    Default = false,
})
Toggles.plant_auto:OnChanged(function()
    autoPlantEnabled = Toggles.plant_auto.Value
end)

HatchGroup:AddSlider("hatch_gap", {
    Text = "Hatch Check Delay",
    Default = 2.0,
    Min = 0.5,
    Max = 10,
    Rounding = 1,
    Suffix = "s",
})
Options.hatch_gap:OnChanged(function()
    hatchCheckDelay = Options.hatch_gap.Value
end)

HatchGroup:AddButton({
    Text = "Hatch All Ready Eggs Now",
    Func = function()
        local count = HatchAllReadyEggs()
        Notify("Hatch", "Hatched " .. count .. " egg(s)", "Success")
    end,
})

HatchGroup:AddButton({
    Text = "Place Carried Eggs in Pen Now",
    Func = function()
        local count = PlantAllCarriedEggsInPen()
        Notify("Plant Eggs", "Planted " .. count .. " egg(s)", "Success")
    end,
})

-- ESP group
EggEspGroup:AddToggle("esp_eggs_enabled", {
    Text = "Egg ESP Enabled",
    Default = false,
})
Toggles.esp_eggs_enabled:OnChanged(function()
    esp.enabled = Toggles.esp_eggs_enabled.Value
end)

EggEspGroup:AddToggle("esp_pet_icons", {
    Text = "Show 3D Pet Image Badges",
    Default = true,
})
Toggles.esp_pet_icons:OnChanged(function()
    esp.showPetIcons = Toggles.esp_pet_icons.Value
end)

EggEspGroup:AddToggle("esp_traps", {
    Text = "Trap ESP",
    Default = false,
})
Toggles.esp_traps:OnChanged(function()
    esp.traps = Toggles.esp_traps.Value
end)

EggEspGroup:AddToggle("esp_eggs_rare_only", {
    Text = "Show Mutated / Rare Eggs Only",
    Default = false,
})
Toggles.esp_eggs_rare_only:OnChanged(function()
    esp.rareEggsOnly = Toggles.esp_eggs_rare_only.Value
end)

EggEspGroup:AddSlider("esp_max_dist", {
    Text = "Max ESP Distance",
    Default = 800,
    Min = 100,
    Max = 2500,
    Rounding = 0,
    Suffix = " studs",
})
Options.esp_max_dist:OnChanged(function()
    esp.maxDistance = Options.esp_max_dist.Value
end)

-- -----------------------------------------------------------------------------
-- BASE TAB
-- -----------------------------------------------------------------------------
local UpgradesGroup = Tabs.Base:AddLeftGroupbox("Homestead & Treadmill", "trending-up")
local PetsGroup = Tabs.Base:AddLeftGroupbox("Pets & Satchel", "award")
local EventsGroup = Tabs.Base:AddLeftGroupbox("Events & Bosses", "flame")
local SalesGroup = Tabs.Base:AddRightGroupbox("Auto Sell", "shopping-cart")
local RewardsGroup = Tabs.Base:AddRightGroupbox("Claim Rewards", "gift")

UpgradesGroup:AddToggle("up_base_auto", { Text = "Auto Upgrade Base / Plot", Default = false })
Toggles.up_base_auto:OnChanged(function() autoUpgradeBase = Toggles.up_base_auto.Value end)

UpgradesGroup:AddToggle("up_tread_auto", { Text = "Auto Upgrade Treadmill Tier", Default = false })
Toggles.up_tread_auto:OnChanged(function() autoUpgradeTreadmill = Toggles.up_tread_auto.Value end)

UpgradesGroup:AddToggle("auto_buy_trails", { Text = "Auto Buy Speed Trails", Default = false })
Toggles.auto_buy_trails:OnChanged(function() autoBuyTrails = Toggles.auto_buy_trails.Value end)

UpgradesGroup:AddButton({
    Text = "Upgrade Base Now",
    Func = function()
        UpgradeHomesteadBase()
        Notify("Base Upgrade", "Requested base upgrade", "Success")
    end,
})

UpgradesGroup:AddButton({
    Text = "Upgrade Treadmill Now",
    Func = function()
        UpgradeTreadmillTier()
        Notify("Treadmill Upgrade", "Requested treadmill upgrade", "Success")
    end,
})

PetsGroup:AddToggle("equip_best_pets", { Text = "Auto Equip Best Pets", Default = false })
Toggles.equip_best_pets:OnChanged(function() autoEquipBestPets = Toggles.equip_best_pets.Value end)

PetsGroup:AddButton({
    Text = "Equip Best Pets Now",
    Func = function()
        EquipBestPets()
        Notify("Pets", "Equipped best pets", "Success")
    end,
})

EventsGroup:AddToggle("auto_monster_chests", { Text = "Auto Claim Monster Chests", Default = false })
Toggles.auto_monster_chests:OnChanged(function() autoClaimMonsterChests = Toggles.auto_monster_chests.Value end)

EventsGroup:AddToggle("auto_feed_monster", { Text = "Auto Feed Monster Parasite", Default = false })
Toggles.auto_feed_monster:OnChanged(function() autoFeedMonster = Toggles.auto_feed_monster.Value end)

EventsGroup:AddButton({
    Text = "Claim Monster Chest Now",
    Func = function()
        ClaimMonsterChests()
        Notify("Monster Event", "Claimed monster chest", "Success")
    end,
})

EventsGroup:AddButton({
    Text = "Feed Monster Parasite Now",
    Func = function()
        FeedMonsterParasite()
        Notify("Monster Event", "Fed monster parasite", "Success")
    end,
})

SalesGroup:AddToggle("auto_sell_pets", { Text = "Auto Sell Low-Tier Pets", Default = false })
Toggles.auto_sell_pets:OnChanged(function() autoSellPets = Toggles.auto_sell_pets.Value end)

SalesGroup:AddDropdown("sell_pet_rarities", {
    Text = "Filter Pet Sell Rarities",
    Values = RARITY_NAMES,
    Default = {},
    Multi = true,
})
Options.sell_pet_rarities:OnChanged(function()
    selectedSellPetRarities = Options.sell_pet_rarities.Value
end)

SalesGroup:AddToggle("auto_sell_eggs", { Text = "Auto Sell Low-Tier Eggs", Default = false })
Toggles.auto_sell_eggs:OnChanged(function() autoSellEggs = Toggles.auto_sell_eggs.Value end)

SalesGroup:AddDropdown("sell_egg_rarities", {
    Text = "Filter Egg Sell Rarities",
    Values = RARITY_NAMES,
    Default = {},
    Multi = true,
})
Options.sell_egg_rarities:OnChanged(function()
    selectedSellEggRarities = Options.sell_egg_rarities.Value
end)

SalesGroup:AddButton({
    Text = "Sell Selected Pets Now",
    Func = function()
        SellSelectedPets()
        Notify("Sales", "Sold matching pets", "Success")
    end,
})

SalesGroup:AddButton({
    Text = "Sell Selected Eggs Now",
    Func = function()
        SellSelectedEggs()
        Notify("Sales", "Sold matching eggs", "Success")
    end,
})

RewardsGroup:AddToggle("claim_auto_rewards", { Text = "Auto Claim Away Earnings & Codex", Default = false })
Toggles.claim_auto_rewards:OnChanged(function() autoClaimRewards = Toggles.claim_auto_rewards.Value end)

RewardsGroup:AddButton({
    Text = "Claim All Rewards Now",
    Func = function()
        ClaimAllAvailableRewards()
        Notify("Rewards", "Claimed all rewards", "Success")
    end,
})

-- -----------------------------------------------------------------------------
-- COMBAT TAB
-- -----------------------------------------------------------------------------
local BatGroup = Tabs.Combat:AddLeftGroupbox("Bat & Slap Aura", "swords")
local GuardGroup = Tabs.Combat:AddRightGroupbox("Defense & Guards", "shield")

BatGroup:AddToggle("bat_aura_enabled", { Text = "Bat / Slap Aura", Default = false })
Toggles.bat_aura_enabled:OnChanged(function()
    batAuraEnabled = Toggles.bat_aura_enabled.Value
end)

BatGroup:AddSlider("bat_radius", {
    Text = "Aura Radius",
    Default = 20,
    Min = 5,
    Max = 50,
    Rounding = 0,
    Suffix = " studs",
})
Options.bat_radius:OnChanged(function()
    batAuraRadius = Options.bat_radius.Value
end)

BatGroup:AddSlider("bat_delay", {
    Text = "Swing Delay",
    Default = 0.2,
    Min = 0.05,
    Max = 1.0,
    Rounding = 2,
    Suffix = "s",
})
Options.bat_delay:OnChanged(function()
    batAuraDelay = Options.bat_delay.Value
end)

BatGroup:AddButton({
    Text = "Swing Bat Once (Manual)",
    Func = function()
        local re = GetNetRemote("RE/BatSwing/Trigger")
        if re then re:FireServer() end
        Notify("Bat", "Triggered bat swing", "Info")
    end,
})

GuardGroup:AddToggle("avoid_traps", { Text = "Anti-Trap (Full Immunity)", Default = true })
Toggles.avoid_traps:OnChanged(function()
    avoidTrapsEnabled = Toggles.avoid_traps.Value
    if avoidTrapsEnabled then pcall(NeutralizeTraps) end
end)

GuardGroup:AddToggle("no_knockback", { Text = "No Knockback / Ragdoll Immunity", Default = true })
Toggles.no_knockback:OnChanged(function()
    SetNoKnockback(Toggles.no_knockback.Value)
end)

GuardGroup:AddToggle("anti_ragdoll", { Text = "Anti-Ragdoll (Quick Standup)", Default = true })
Toggles.anti_ragdoll:OnChanged(function()
    antiRagdollEnabled = Toggles.anti_ragdoll.Value
end)

track(RunService.Heartbeat:Connect(function()
    if HUB.dead or not antiRagdollEnabled then return end
    local hum = findHum()
    if hum and hum:GetState() == Enum.HumanoidStateType.Physics then
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end))

-- -----------------------------------------------------------------------------
-- PLAYER TAB
-- -----------------------------------------------------------------------------
local MoveGroup = Tabs.Player:AddLeftGroupbox("Movement", "move")
local AreaTpGroup = Tabs.Player:AddLeftGroupbox("Area Travel", "map-pin")
local PlotTpGroup = Tabs.Player:AddLeftGroupbox("Plot Travel", "home")
local PlayerTpGroup = Tabs.Player:AddRightGroupbox("Player Travel", "user")
local VisualsGroup = Tabs.Player:AddRightGroupbox("Visuals & Performance", "eye")

MoveGroup:AddToggle("speed_enabled", { Text = "Enable WalkSpeed", Default = false })
Toggles.speed_enabled:OnChanged(function()
    walkSpeedEnabled = Toggles.speed_enabled.Value
    if not walkSpeedEnabled then
        local hum = findHum()
        if hum then hum.WalkSpeed = 16 end
    end
end)

MoveGroup:AddSlider("speed_val", {
    Text = "WalkSpeed Value",
    Default = 24,
    Min = 16,
    Max = 10000,
    Rounding = 0,
    Suffix = " studs/s",
})
Options.speed_val:OnChanged(function()
    ApplyWalkSpeed(Options.speed_val.Value)
end)

MoveGroup:AddToggle("jump_enabled", { Text = "Enable JumpPower", Default = false })
Toggles.jump_enabled:OnChanged(function()
    jumpPowerEnabled = Toggles.jump_enabled.Value
    if not jumpPowerEnabled then
        local hum = findHum()
        if hum then hum.JumpPower = 50 end
    end
end)

MoveGroup:AddSlider("jump_val", {
    Text = "JumpPower Value",
    Default = 60,
    Min = 50,
    Max = 300,
    Rounding = 0,
})
Options.jump_val:OnChanged(function()
    ApplyJumpPower(Options.jump_val.Value)
end)

MoveGroup:AddToggle("inf_jump", { Text = "Infinite Jump", Default = false })
Toggles.inf_jump:OnChanged(function()
    infiniteJump = Toggles.inf_jump.Value
end)

MoveGroup:AddToggle("fly_enabled", { Text = "Smooth Fly (WASD + Space/Shift)", Default = false })
Toggles.fly_enabled:OnChanged(function()
    if Toggles.fly_enabled.Value then startFly() else stopFly() end
end)

MoveGroup:AddSlider("fly_speed", {
    Text = "Fly Speed",
    Default = 60,
    Min = 20,
    Max = 250,
    Rounding = 0,
    Suffix = " studs/s",
})
Options.fly_speed:OnChanged(function()
    flySpeed = Options.fly_speed.Value
end)

MoveGroup:AddToggle("anti_afk", { Text = "Anti-AFK", Default = false })
Toggles.anti_afk:OnChanged(function()
    SetAntiAFK(Toggles.anti_afk.Value)
end)

-- Area TP
local areaKeys = {}
for k in pairs(AREA_COORDINATES) do table.insert(areaKeys, k) end
table.sort(areaKeys)

local selectedAreaTp = "Base / Plot"

AreaTpGroup:AddDropdown("tele_area", {
    Text = "Select Area",
    Values = areaKeys,
    Default = "Base / Plot",
    Multi = false,
})
Options.tele_area:OnChanged(function()
    selectedAreaTp = Options.tele_area.Value
end)

AreaTpGroup:AddButton({
    Text = "Travel to Selected Area",
    Func = function()
        local pos = AREA_COORDINATES[selectedAreaTp]
        if selectedAreaTp == "Base / Plot" then
            pos = GetLocalPlotCenter()
        end
        if pos then
            Notify("Travel", "Traveling to " .. selectedAreaTp, "Info")
            TravelRoadPath(pos, glideSpeed or 200)
            Notify("Travel", "Arrived at " .. selectedAreaTp, "Success")
        else
            Notify("Travel", "Area position not found", "Error")
        end
    end,
})

-- Plot TP
local plotOptions = { "Plot 1", "Plot 2", "Plot 3", "Plot 4", "Plot 5", "Plot 6", "Plot 7", "My Plot" }
local selectedPlotNum = "My Plot"

PlotTpGroup:AddDropdown("tele_plot", {
    Text = "Select Plot",
    Values = plotOptions,
    Default = "My Plot",
    Multi = false,
})
Options.tele_plot:OnChanged(function()
    selectedPlotNum = Options.tele_plot.Value
end)

PlotTpGroup:AddButton({
    Text = "Travel to Plot",
    Func = function()
        local slotNum = selectedPlotNum == "My Plot" and GetLocalSlot() or tonumber(selectedPlotNum:match("%d+")) or 1
        local plot = Workspace.Plots and Workspace.Plots:FindFirstChild(tostring(slotNum))
        local targetPos = plot and (plot:FindFirstChild("CenterPoint") and plot.CenterPoint.Position or plot:GetPivot().Position)
        if targetPos then
            TravelRoadPath(targetPos + Vector3.new(0, 2, 0), glideSpeed or 200)
            Notify("Plot", "Arrived at Plot " .. tostring(slotNum), "Success")
        else
            Notify("Plot", "Plot not found", "Error")
        end
    end,
})

-- Player TP
local selectedPlayerName = nil
local function GetPlayerList()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then table.insert(names, p.Name) end
    end
    table.sort(names)
    if #names == 0 then names = { "(no other players)" } end
    return names
end

PlayerTpGroup:AddDropdown("tele_plr", {
    Text = "Select Player",
    Values = GetPlayerList(),
    Default = nil,
    Multi = false,
})
Options.tele_plr:OnChanged(function()
    selectedPlayerName = Options.tele_plr.Value
end)

PlayerTpGroup:AddButton({
    Text = "Refresh Player List",
    Func = function()
        Options.tele_plr:SetValues(GetPlayerList())
        Notify("Players", "Refreshed player list", "Info")
    end,
})

PlayerTpGroup:AddButton({
    Text = "Travel to Player",
    Func = function()
        if not selectedPlayerName then return end
        local targetPlr = Players:FindFirstChild(selectedPlayerName)
        local tHrp = targetPlr and targetPlr.Character and targetPlr.Character:FindFirstChild("HumanoidRootPart")
        if tHrp then
            TravelRoadPath(tHrp.Position + Vector3.new(0, 2, 0), glideSpeed or 200)
            Notify("Player", "Arrived at " .. selectedPlayerName, "Success")
        else
            Notify("Player", "Player unavailable", "Error")
        end
    end,
})

-- Visuals
VisualsGroup:AddToggle("fullbright", { Text = "Fullbright", Default = false })
Toggles.fullbright:OnChanged(function()
    SetFullbright(Toggles.fullbright.Value)
end)

VisualsGroup:AddButton({
    Text = "Delete Own Pet Renders (FPS Boost)",
    Func = function()
        local count = DeleteOwnPetRenders()
        Notify("Performance", "Removed " .. count .. " pet model(s)", "Success")
    end,
})

-- -----------------------------------------------------------------------------
-- CONFIGS TAB
-- -----------------------------------------------------------------------------
local ConfigsGroup = Tabs.Configs:AddLeftGroupbox("Quick Configs", "zap")

-- -----------------------------------------------------------------------------
-- SETTINGS TAB
-- -----------------------------------------------------------------------------
local SettingsGroup = Tabs.Settings:AddLeftGroupbox("Settings", "settings")

SettingsGroup:AddLabel("Menu toggle"):AddKeyPicker("MenuKeybind", {
    Default = "RightControl",
    NoUI = true,
    Text = "Menu keybind"
})
Library.ToggleKeybind = Options.MenuKeybind

-- ============ THEME + SAVE MANAGERS ============
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:SetFolder("StealAnEgg")
SaveManager:SetFolder("StealAnEgg")

ThemeManager:SetDefaultTheme({
    FontColor       = Color3.fromRGB(225, 225, 225),
    MainColor       = Color3.fromRGB(28, 28, 28),
    AccentColor     = Color3.fromRGB(100, 100, 255),
    BackgroundColor = Color3.fromRGB(20, 20, 20),
    OutlineColor    = Color3.fromRGB(50, 50, 50),
    FontFace        = Font.fromName("Gotham", Enum.FontWeight.Medium),
})

SaveManager:BuildConfigSection(Tabs.Configs)
ThemeManager:ApplyToTab(Tabs.Configs)
SaveManager:ApplyToTab(Tabs.Configs)

ThemeManager:LoadDefault()
SaveManager:LoadAutoloadConfig()

-- ==============================================================================
-- HUB CLEANUP & UNLOAD HANDLER
-- ==============================================================================
HUB.Unload = function()
    HUB.dead = true

    for _, c in ipairs(HUB.conns) do pcall(function() c:Disconnect() end) end
    HUB.conns = {}

    for _, d in ipairs(HUB.drawings) do pcall(function() d:Remove() end) end
    HUB.drawings = {}

    for _, h in ipairs(HUB.highlights) do pcall(function() h:Destroy() end) end
    HUB.highlights = {}

    stopFly()
    SetFullbright(false)

    local hum = findHum()
    if hum then
        hum.PlatformStand = false
        hum.WalkSpeed = 16
        hum.JumpPower = 50
    end

    pcall(function() Library:Unload() end)
    _G.ObsidianStealAnEgg = nil
end

Library:OnUnload(function()
    if HUB.Unload then pcall(HUB.Unload) end
end)

Notify("Steal An Egg", "Obsidian script loaded successfully!", "Success", 3.5)
