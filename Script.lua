warn("[v47] === СКРИПТ ЗАПУЩЕН ===")
if _G.NPCKillTesterPro and _G.NPCKillTesterPro.Unload then
    _G.NPCKillTesterPro.Unload()
    task.wait(0.3)
end
_G.NPCKillTesterPro = {}
warn("[v46] шаг 1: _G инициализирован ✅")
local function safeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, r = pcall(fn, ...)
    if ok then return r end
    return nil
end
local _hookmm = rawget(getfenv(), "hookmetamethod")
local _hookfn = rawget(getfenv(), "hookfunction")
local _getconn = rawget(getfenv(), "getconnections")
local _getrmt = rawget(getfenv(), "getrawmetatable")
local _setro = rawget(getfenv(), "setreadonly")
local _newccl = rawget(getfenv(), "newcclosure")
local _getncm = rawget(getfenv(), "getnamecallmethod")
local _shp = rawget(getfenv(), "sethiddenproperty")
local _fti = rawget(getfenv(), "firetouchinterest")
local _fpp = rawget(getfenv(), "fireproximityprompt")
local _fcd = rawget(getfenv(), "fireclickdetector")
local _gethui = rawget(getfenv(), "gethui")
local _identify = rawget(getfenv(), "identifyexecutor")
warn("[v46] шаг 2: executor globals cached ✅ (hookmm=" .. tostring(type(_hookmm) == "function") .. ", hookfn=" .. tostring(type(_hookfn) == "function") .. ", fti=" .. tostring(type(_fti) == "function") .. ")")
if _identify then warn("[v46] executor: " .. tostring(safeCall(_identify))) end
firetouchinterest = _fti
fireproximityprompt = _fpp
fireclickdetector = _fcd
sethiddenproperty = _shp
gethui = _gethui
getconnections = _getconn
hookmetamethod = _hookmm
hookfunction = _hookfn
getrawmetatable = _getrmt
setreadonly = _setro
newcclosure = _newccl
getnamecallmethod = _getncm
warn("[v46] шаг 3: safe globals set ✅")
local rs = game:GetService("RunService")
local ws = game:GetService("Workspace")
local plrs = game:GetService("Players")
local rep = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local VIM = game:GetService("VirtualInputManager")
local PS = game:GetService("PhysicsService")
local Deb = game:GetService("Debris")
local lp = plrs.LocalPlayer
local mouse = lp:GetMouse()
local cam = ws.CurrentCamera
local selectedNPCs = {}
local currentNPC = nil
local connections = {}
local highlights = {}
local rollbackGuards = {}
local DebounceMap = {}
local function debounce(id, obj, cd)
    local k = tostring(id).."_"..tostring(obj)
    local now = tick()
    if DebounceMap[k] and (now - DebounceMap[k]) < cd then return false end
    DebounceMap[k] = now
    return true
end
local PartsCache = {}
local function getCached(obj)
    local c = PartsCache[obj]
    if c and (tick() - c.t) < 5 then return c end
    c = {parts={},motors={},atts={},bones={},welds={},t=tick()}
    pcall(function()
        for _,d in ipairs(obj:GetDescendants()) do
            if d:IsA("BasePart") then table.insert(c.parts, d)
            elseif d:IsA("Motor6D") then table.insert(c.motors, d); table.insert(c.welds, d)
            elseif d:IsA("Weld") or d:IsA("ManualWeld") then table.insert(c.welds, d)
            elseif d:IsA("Attachment") then table.insert(c.atts, d)
            elseif d:IsA("Bone") then table.insert(c.bones, d) end
        end
    end)
    PartsCache[obj] = c
    return c
end
local RateLim = { tokens = 30, max = 30, refill = 15 }
task.spawn(function()
    while true do task.wait(1); RateLim.tokens = math.min(RateLim.max, RateLim.tokens + RateLim.refill) end
end)
local function canRun() if RateLim.tokens > 0 then RateLim.tokens = RateLim.tokens - 1; return true end; return false end
local CastEnabled = {
    GoldenGrail = true,
    Weapons = true,
    Events = true,
    Touch = true,
    CustomRigs = true,
    FEClassic = true,
    MathStats = true,
    PlayerInputSim = true,
    BossSpecial = true,
    DestroyerServer = false,
}
local MethodEnabled = {}
local CombatSettings = { DamageAmount = 50000, HyperSpeed = false }
local DeepData = {
    CombatRemotes = {},
    DamageRemotes = {},
    WeaponRemotes = {},
    BossRemotes = {},
    Bindables = {},
    BossModels = {},
}
local RecordedCalls = {}
local RemoteMutation = { hooked = {}, lastCall = nil }
local StolenEventCache = { hookedRemotes = {}, stolen = {} }
local MethodRegistry = {}
local function reg(id, cast, name, desc, fn, defEn)
    MethodEnabled[id] = defEn ~= false
    table.insert(MethodRegistry, {id=id, cast=cast, name=name, desc=desc, fn=fn})
end
local function safeLower(s) return (type(s)=="string") and string.lower(s) or "" end
local function indexObject(obj)
    if not obj then return end
    pcall(function()
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local nm = safeLower(obj.Name)
            local fnm = obj.Parent and safeLower(obj.Parent.Name) or ""
            local honey = nm:find("ban") or nm:find("kick") or nm:find("anticheat") or nm:find("ac_") or nm:find("log") or nm:find("report") or nm:find("detect") or nm:find("security") or nm:find("flag") or fnm:find("anticheat") or fnm:find("bansystem")
            if honey then return end
            local isCombat = nm:find("attack") or nm:find("damage") or nm:find("hit") or nm:find("combat") or nm:find("kill") or nm:find("strike") or nm:find("swing") or nm:find("slash") or nm:find("shoot") or nm:find("fire") or nm:find("cast") or nm:find("skill") or nm:find("ability") or nm:find("weapon") or nm:find("attackevent") or nm:find("hitevent") or nm:find("damageevent") or fnm:find("combat") or fnm:find("weapon")
            local isDamage = nm:find("damage") or nm:find("dealdamage") or nm:find("takedamage") or nm:find("dmg") or nm:find("hurt") or nm:find("inflict")
            local isBoss = nm:find("boss") or nm:find("raid") or nm:find("dungeon") or nm:find("miniboss") or fnm:find("boss")
            if isCombat and not table.find(DeepData.CombatRemotes, obj) then table.insert(DeepData.CombatRemotes, obj) end
            if isDamage and not table.find(DeepData.DamageRemotes, obj) then table.insert(DeepData.DamageRemotes, obj) end
            if isBoss and not table.find(DeepData.BossRemotes, obj) then table.insert(DeepData.BossRemotes, obj) end
        end
        if obj:IsA("Tool") then
            for _,r in ipairs(obj:GetDescendants()) do
                if (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) and not table.find(DeepData.WeaponRemotes, r) then
                    table.insert(DeepData.WeaponRemotes, r)
                end
            end
        end
        if obj:IsA("BindableEvent") or obj:IsA("BindableFunction") then
            local nm = safeLower(obj.Name)
            if nm:find("die") or nm:find("dead") or nm:find("kill") or nm:find("damage") or nm:find("death") or nm:find("defeat") then
                if not table.find(DeepData.Bindables, obj) then table.insert(DeepData.Bindables, obj) end
            end
        end
    end)
end
local function scanForBosses()
    DeepData.BossModels = {}
    for _,m in ipairs(ws:GetDescendants()) do
        if m:IsA("Model") and m ~= lp.Character then
            pcall(function()
                local nm = safeLower(m.Name)
                if nm:find("boss") or nm:find("killer") or nm:find("thanos") or nm:find("raid") or m:GetAttribute("Boss") or m:GetAttribute("IsBoss") then
                    if not table.find(DeepData.BossModels, m) then table.insert(DeepData.BossModels, m) end
                end
            end)
        end
    end
end
local function runAnalysis()
    DeepData.CombatRemotes = {}
    DeepData.DamageRemotes = {}
    DeepData.WeaponRemotes = {}
    DeepData.BossRemotes = {}
    DeepData.Bindables = {}
    for _,o in ipairs(rep:GetDescendants()) do indexObject(o) end
    for _,o in ipairs(ws:GetDescendants()) do indexObject(o) end
    for _,p in ipairs(plrs:GetPlayers()) do
        local bp = p:FindFirstChild("Backpack")
        if bp then for _,o in ipairs(bp:GetDescendants()) do indexObject(o) end end
    end
    scanForBosses()
    print(string.format("[🤖 v43 ANALYZER] Combat:%d | Damage:%d | Weapon:%d | Boss:%d | Bindable:%d | BossModels:%d",
        #DeepData.CombatRemotes, #DeepData.DamageRemotes, #DeepData.WeaponRemotes, #DeepData.BossRemotes, #DeepData.Bindables, #DeepData.BossModels))
end
ws.DescendantAdded:Connect(indexObject)
rep.DescendantAdded:Connect(indexObject)
local AK = { active = false, installed = false, hooks = {} }
function AK:Install()
    if self.installed then return end
    self.installed = true
    local has_hookmm = type(hookmetamethod) == "function"
    local has_hookfn = type(hookfunction) == "function"
    local has_getconn = type(getconnections) == "function"
    local has_getrmt = type(getrawmetatable) == "function"
    local has_setro = type(setreadonly) == "function"
    local has_newccl = type(newcclosure) == "function"
    print("[🛡️ AK v43] Executor capabilities: hookmm=", has_hookmm, " hookfn=", has_hookfn, " getconn=", has_getconn, " getrmt=", has_getrmt)
    if has_hookfn then
        pcall(function()
            local orig
            orig = hookfunction(lp.Kick, function(...)
                if AK.active then
                    print("[🛡️ L1 hookfunction] Kick заблокирован!")
                    return
                end
                return orig(...)
            end)
            print("[🛡️ L1] hookfunction на Kick УСТАНОВЛЕН")
        end)
    end
    if has_hookmm then
        pcall(function()
            local old
            old = hookmetamethod(game, "__namecall", function(self, ...)
                local m = ""
                if getnamecallmethod then pcall(function() m = getnamecallmethod() end) end
                if AK.active and (m == "Kick" or m == "kick") then
                    if typeof(self) == "Instance" and (self == lp or self:IsA("Player")) then
                        print("[🛡️ L2 __namecall] Kick заблокирован!")
                        return
                    end
                end
                return old(self, ...)
            end)
            print("[🛡️ L2] hookmetamethod __namecall УСТАНОВЛЕН")
        end)
    end
    if has_getrmt and has_setro then
        pcall(function()
            local mt = getrawmetatable(lp)
            setreadonly(mt, false)
            local oldIndex = mt.__index
            local newIndex = function(s, k)
                if AK.active and k == "Kick" and (s == lp or (typeof(s)=="Instance" and s:IsA("Player"))) then
                    return function() print("[🛡️ L3 __index] Kick заблокирован!") end
                end
                if type(oldIndex) == "function" then return oldIndex(s, k) end
                return oldIndex[k]
            end
            mt.__index = has_newccl and newcclosure(newIndex) or newIndex
            setreadonly(mt, true)
            print("[🛡️ L3] metatable __index УСТАНОВЛЕН")
        end)
    end
    pcall(function()
        local count = 0
        for _,r in ipairs(rep:GetDescendants()) do
            if r:IsA("RemoteEvent") then
                local nm = safeLower(r.Name)
                local fnm = r.Parent and safeLower(r.Parent.Name) or ""
                if nm:find("kick") or nm:find("ban") or nm:find("anticheat") or nm:find("punish") or nm:find("detect") or fnm:find("anticheat") then
                    if has_getconn then
                        pcall(function()
                            local conns = getconnections(r.OnClientEvent)
                            for _, c in ipairs(conns) do pcall(function() c:Disable() end) end
                            count = count + #conns
                        end)
                    end
                    table.insert(AK.hooks, r.OnClientEvent:Connect(function()
                        if AK.active then print("[🛡️ L4] Kick-remote event пойман:", r.Name) end
                    end))
                end
            end
        end
        print("[🛡️ L4] Отключено kick-connections:", count)
    end)
    local function patchChar(c)
        if not c then return end
        local h = c:WaitForChild("Humanoid", 5)
        if h then
            pcall(function()
                h.BreakJointsOnDeath = false
                h.MaxHealth = math.huge
                h.Health = math.huge
                local con = h.HealthChanged:Connect(function(nh)
                    if AK.active and nh < h.MaxHealth * 0.8 then
                        pcall(function() h.Health = h.MaxHealth end)
                    end
                end)
                table.insert(AK.hooks, con)
            end)
        end
    end
    patchChar(lp.Character)
    connections["ak_char"] = lp.CharacterAdded:Connect(patchChar)
    task.spawn(function()
        while AK.active or AK.installed do
            pcall(function()
                if AK.active then
                    local c = lp.Character
                    if c then
                        local h = c:FindFirstChildOfClass("Humanoid")
                        if h and h.Health < h.MaxHealth * 0.7 then h.Health = h.MaxHealth end
                        if not c:FindFirstChildOfClass("ForceField") then
                            local ff = Instance.new("ForceField")
                            ff.Visible = false
                            ff.Parent = c
                            Deb:AddItem(ff, 4)
                        end
                    end
                end
            end)
            task.wait(0.5)
        end
    end)
    print("[🛡️ ANTI-KICK PRO v43] ВСЕ 5 СЛОЁВ УСТАНОВЛЕНЫ!")
end
function AK:Toggle(state)
    self.active = state
    if state and not self.installed then self:Install() end
    print("[🛡️ AK]", state and "🟢 АКТИВЕН — Kick заблокирован!" or "🔴 OFF")
end
local function getRoot(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        return obj.PrimaryPart
            or obj:FindFirstChild("HumanoidRootPart")
            or obj:FindFirstChild("Torso")
            or obj:FindFirstChild("UpperTorso")
            or obj:FindFirstChild("Root")
            or obj:FindFirstChild("Body")
            or obj:FindFirstChild("Main")
            or obj:FindFirstChild("Head")
            or obj:FindFirstChildOfClass("BasePart")
    end
    return nil
end
local function isNPC(m)
    if not m or not m:IsA("Model") then return false end
    if m == lp.Character then return false end
    if plrs:GetPlayerFromCharacter(m) then return false end
    local pc = 0
    for _,c in ipairs(m:GetChildren()) do if c:IsA("BasePart") then pc = pc+1 end end
    if pc > 400 then return false end
    if m:FindFirstChildOfClass("Humanoid") or m:FindFirstChildOfClass("AnimationController") then return true end
    if m:FindFirstChildOfClass("Bone", true) then return true end
    if m:FindFirstChild("Health", true) or m:GetAttribute("Health") or m:GetAttribute("Boss") or m:GetAttribute("HP") then return true end
    for _,d in ipairs(m:GetDescendants()) do if d:IsA("Motor6D") or d:IsA("BallSocketConstraint") then return true end end
    return false
end
local function getAllNPCs()
    local raw = {}
    for _,o in ipairs(ws:GetDescendants()) do
        if o:IsA("Model") and o ~= lp.Character and not plrs:GetPlayerFromCharacter(o) then
            if isNPC(o) then table.insert(raw, o) end
        end
    end
    local fin = {}
    for _,c in ipairs(raw) do
        local child = false
        for _,o in ipairs(raw) do if c ~= o and o:IsDescendantOf(c) then child = true; break end end
        if not child then table.insert(fin, c) end
    end
    return fin
end
local function analyze(obj)
    local r = getRoot(obj); if not r then return false, nil, nil, nil end
    local h = obj:FindFirstChildOfClass("Humanoid")
    local nm = safeLower(obj.Name)
    local isBoss = nm:find("boss") or nm:find("killer") or nm:find("raid") or obj:GetAttribute("Boss")
    local et, hp = "NPC", "?"
    if h then
        et = isBoss and "👹Boss" or "🚶Hum"
        hp = math.floor(h.Health).."/"..math.floor(h.MaxHealth)
    else
        et = isBoss and "👹BossRig" or "🦾Rig"
    end
    return true, et, hp, r
end
local function checkOwn(p)
    if not p or not p:IsA("BasePart") then return "-" end
    if p.Anchored then return "⚓" end
    local ok, o = pcall(function() return p:IsNetworkOwner() end)
    return (ok and o) and "✅" or "🌐"
end
local function getTargets()
    local t = {}
    for o,_ in pairs(selectedNPCs) do if o and o.Parent then table.insert(t, o) else selectedNPCs[o] = nil end end
    if #t == 0 and currentNPC and currentNPC.Parent then table.insert(t, currentNPC) end
    return t
end
local function claimFE(obj)
    if not debounce("claimFE", obj, 1.0) then return end
    pcall(function()
        if sethiddenproperty then sethiddenproperty(lp, "SimulationRadius", 1e10) end
        local c = getCached(obj)
        for _,p in ipairs(c.parts) do
            if not p.Anchored then pcall(function() p:SetNetworkOwner(lp) end) end
        end
    end)
end
local function m_1(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h.Health=0; h:TakeDamage(999999) end) end end
reg(1, "FEClassic", "1. Simple HP=0", "Humanoid.Health=0", m_1)
local function m_2(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Dead); h.PlatformStand=true end) end end
reg(2, "FEClassic", "2. Ragdoll Dead", "ChangeState(Dead)", m_2)
local function m_3(o)
    claimFE(o)
    if not debounce(3, o, 1) then return end
    task.spawn(function()
        for i=1,6 do
            if not o.Parent then break end
            pcall(function() if o.BreakJoints then o:BreakJoints() end end)
            for _,v in ipairs(getCached(o).welds) do pcall(function() v:Destroy() end) end
            task.wait(0.08)
        end
    end)
end
reg(3, "FEClassic", "3. Break Joints Loop", "BreakJoints x6", m_3)
local function m_5(o) claimFE(o); for _,p in ipairs(getCached(o).parts) do if p.Name=="Head" or p.Name=="Torso" then pcall(function() for _,w in ipairs(p:GetChildren()) do if w:IsA("Motor6D") or w:IsA("Weld") then w:Destroy() end end; p.AssemblyLinearVelocity=Vector3.new(0,30000,0) end) end end end
reg(5, "FEClassic", "5. Decapitate", "Отрыв Head/Torso", m_5)
local function m_6(o) claimFE(o); local r=getRoot(o); if not r then return end; pcall(function() local e=Instance.new("Explosion"); e.Position=r.Position; e.BlastRadius=35; e.BlastPressure=0; e.ExplosionType=Enum.ExplosionType.NoCraters; e.Parent=ws end) end
reg(6, "FEClassic", "6. Safe Explosion", "Explosion NoCraters", m_6)
local function m_92(o)
    local h=o:FindFirstChildOfClass("Humanoid"); local r=getRoot(o)
    if not h or not r then return end
    if not debounce(92, o, 5) then return end
    task.spawn(function()
        local s = Instance.new("Seat")
        s.Transparency=1; s.CanCollide=false; s.CFrame=r.CFrame; s.Parent=ws
        pcall(function() s:Sit(h) end)
        task.wait(0.1)
        pcall(function() s.CFrame=CFrame.new(r.Position.X, 2000, r.Position.Z); s.Anchored=true; if o.BreakJoints then o:BreakJoints() end end)
        Deb:AddItem(s, 8)
    end)
end
reg(92, "FEClassic", "92. Seat Sky Freeze", "Seat → Y=2000", m_92)
local function m_117(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); if not h then return end; pcall(function() for _,s in pairs(Enum.HumanoidStateType:GetEnumItems()) do if s~=Enum.HumanoidStateType.Dead then pcall(function() h:SetStateEnabled(s,false) end) end end; h:ChangeState(Enum.HumanoidStateType.Dead); h.MaxHealth=0; h.Health=0 end) end
reg(117, "FEClassic", "117. State Flood", "Все death states", m_117)
local function m_119(o)
    claimFE(o)
    if not debounce(119, o, 2) then return end
    pcall(function()
        for _,ff in ipairs(o:GetDescendants()) do if ff:IsA("ForceField") then ff:Destroy() end end
        local r = getRoot(o)
        if r then
            for i=1,3 do
                local e=Instance.new("Explosion")
                e.Position=r.Position; e.BlastRadius=50; e.BlastPressure=0
                e.DestroyJointRadiusPercent=1
                e.ExplosionType=Enum.ExplosionType.NoCraters
                e.Parent=ws
            end
        end
        local h=o:FindFirstChildOfClass("Humanoid")
        if h then h:TakeDamage(math.huge); h.Health=0 end
    end)
end
reg(119, "FEClassic", "119. FF Death Trap", "3 Explosion DestroyJoint=1", m_119)
local function m_121(o) claimFE(o); pcall(function() local h=o:FindFirstChildOfClass("Humanoid"); if h then h.RequiresNeck=true end; local hd=o:FindFirstChild("Head"); if hd then for _,j in ipairs(hd:GetChildren()) do if j:IsA("Motor6D") or j:IsA("Weld") then pcall(function() j.Part0=nil; j.Part1=nil end) end end end; if h then h:ChangeState(Enum.HumanoidStateType.Dead); h.Health=0 end end) end
reg(121, "FEClassic", "121. Head Decapitate", "Разрыв Head-Neck", m_121)
local function m_123(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); pcall(function() if h then h:ChangeState(Enum.HumanoidStateType.Ragdoll); h.PlatformStand=true end; for _,j in ipairs(getCached(o).motors) do pcall(function() j.Part0=nil; j.Part1=nil end) end; if h then h.Health=0 end end) end
reg(123, "FEClassic", "123. Ragdoll Suffocate", "Ragdoll + Motor6D nil", m_123)
local function m_125(o)
    local r = getRoot(o); if not r then return end
    if not debounce(125, o, 3) then return end
    task.spawn(function()
        for i=1,6 do
            if not o.Parent then break end
            pcall(function()
                local a = (i/6)*math.pi*2
                local off = Vector3.new(math.cos(a)*3, 0, math.sin(a)*3)
                local e = Instance.new("Explosion")
                e.Position = r.Position + off
                e.BlastRadius = 15; e.BlastPressure = 0
                e.DestroyJointRadiusPercent = 1
                e.ExplosionType = Enum.ExplosionType.NoCraters
                e.Parent = ws
            end)
            task.wait(0.08)
        end
    end)
end
reg(125, "FEClassic", "125. Explosion Ring 6x", "6 Explosion кольцом", m_125)
local function m_137(o)
    claimFE(o)
    if not debounce(137, o, 2) then return end
    task.spawn(function()
        local mts = getCached(o).motors
        for tick=1,10 do
            if not o.Parent then break end
            for i,m in ipairs(mts) do
                pcall(function() m.DesiredAngle = math.sin(tick*0.5+i)*1e6; m.MaxVelocity = math.huge end)
            end
            task.wait(0.08)
        end
    end)
end
reg(137, "FEClassic", "137. Joint Velocity Osc", "Motor6D осцилляция", m_137)
local function m_146(o) pcall(function() for _,d in ipairs(DeepData.Bindables) do if d and d.Parent then pcall(function() if d:IsA("BindableEvent") then d:Fire(o); d:Fire() end end) end end end) end
reg(146, "FEClassic", "146. Death Signal Fire", "Fire все Died bindables", m_146)
local function m_150(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); if not h then return end; task.spawn(function() pcall(function() h.Health=0; h:ChangeState(Enum.HumanoidStateType.Dead); task.wait(0.05); local hd=o:FindFirstChild("Head"); if hd then local n=hd:FindFirstChildOfClass("Motor6D"); if n then pcall(function() n:Destroy() end) end end; h:TakeDamage(math.huge) end) end) end
reg(150, "FEClassic", "150. Death Cycle Sim", "Эмуляция death cycle", m_150)
local function m_156(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); if not h then return end; pcall(function() local d=Instance.new("HumanoidDescription"); d.HealthScale=0; d.HeightScale=0.01; d.WidthScale=0.01; d.DepthScale=0.01; h:ApplyDescription(d); task.wait(0.1); h.Health=0 end) end
reg(156, "FEClassic", "156. HumanoidDesc Kill", "ApplyDescription scale=0", m_156)
local function m_169(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); if not h then return end; if not debounce(169, o, 4) then return end; task.spawn(function() pcall(function() local op=h.Parent; h.Parent=nil; task.wait(); for i=1,10 do pcall(function() h.Health=0; h:TakeDamage(math.huge) end) end; task.wait(); h.Parent=op; h:ChangeState(Enum.HumanoidStateType.Dead); h.Health=0 end) end) end
reg(169, "FEClassic", "169. Humanoid Parent Flip", "Parent=nil→урон→возврат", m_169)
local function m_173(o)
    local h = o:FindFirstChildOfClass("Humanoid"); if not h then return end
    if not debounce(173, o, 4) then return end
    pcall(function()
        if getconnections then
            local cs = getconnections(h.Died)
            print("[173] Died connections:", #cs)
            for _,c in ipairs(cs) do pcall(function() if c.Fire then c:Fire() elseif c.Function then c.Function() end end) end
            local cs2 = getconnections(h.HealthChanged)
            for _,c in ipairs(cs2) do pcall(function() if c.Fire then c:Fire(0) end end) end
        end
        h.Health = 0
    end)
end
reg(173, "FEClassic", "173. Died Manual Fire", "getconnections(Died)+вызов", m_173)
local function m_18(o)
    if #DeepData.CombatRemotes == 0 then runAnalysis() end
    if not debounce(18, o, 1) then return end
    task.spawn(function()
        for _,r in ipairs(DeepData.CombatRemotes) do
            pcall(function()
                if r:IsA("RemoteEvent") then
                    r:FireServer(o)
                    r:FireServer(o, 999999)
                elseif r:IsA("RemoteFunction") then
                    task.spawn(function() r:InvokeServer(o) end)
                end
            end)
        end
    end)
end
reg(18, "Events", "18. Combat Remote Fire", "Combat remotes → FireServer", m_18)
local function m_20(o) for _,d in ipairs(DeepData.Bindables) do pcall(function() if d:IsA("BindableEvent") then d:Fire() end end) end end
reg(20, "Events", "20. Bindable Trigger", "Fire все die/damage bindables", m_20)
local function m_21(o) local r=getRoot(o); local h=o:FindFirstChildOfClass("Humanoid"); for _,it in ipairs({o,r,h}) do if it then pcall(function() it:SetAttribute("Dead",true); it:SetAttribute("Health",0) end) end end end
reg(21, "Events", "21. Attribute Tag", "SetAttribute Dead=true", m_21)
local function m_106(o)
    if not debounce(106, o, 1) then return end
    local ids = {}
    pcall(function() for a,v in pairs(o:GetAttributes()) do if safeLower(a):find("id") then table.insert(ids, v) end end end)
    table.insert(ids, o); table.insert(ids, o.Name)
    local r = getRoot(o); if r then table.insert(ids, r) end
    task.spawn(function()
        for _,rem in ipairs(DeepData.CombatRemotes) do
            for _,id in ipairs(ids) do
                pcall(function()
                    if rem:IsA("RemoteEvent") then
                        rem:FireServer(id, 999999)
                        rem:FireServer({Target=id, Damage=999999})
                    end
                end)
            end
        end
    end)
end
reg(106, "Events", "106. Boss-ID Router", "Все ID → все combat remotes", m_106)
local function m_139(o)
    if #DeepData.CombatRemotes == 0 then runAnalysis() end
    if not debounce(139, o, 2) then return end
    local r = getRoot(o)
    local fmts = { {o},{o,999999},{o.Name},{"Attack",o},{"Damage",o,999999},{r,999999},{{Target=o,Damage=999999}},{lp,o,999999} }
    task.spawn(function()
        for _,rem in ipairs(DeepData.CombatRemotes) do
            for _,f in ipairs(fmts) do
                pcall(function() if rem:IsA("RemoteEvent") then rem:FireServer(unpack(f)) end end)
            end
            task.wait(0.03)
        end
    end)
end
reg(139, "Events", "139. Remote Fuzz 8fmt", "8 форматов на combat remotes", m_139)
local function m_149(o)
    if not debounce(149, o, 8) then return end
    task.spawn(function()
        print("[149] Запись 2сек — АТАКУЙ БОССА!")
        local rec = {}
        for _,rem in ipairs(DeepData.CombatRemotes) do
            if rem:IsA("RemoteEvent") then
                pcall(function()
                    if rawset then
                        local orig = rem.FireServer
                        rawset(rem, "FireServer", function(s, ...)
                            table.insert(rec, {r=s, a={...}})
                            return orig(s, ...)
                        end)
                        table.insert(RecordedCalls, {r=rem, orig=orig})
                    end
                end)
            end
        end
        task.wait(2)
        for _,x in ipairs(RecordedCalls) do pcall(function() rawset(x.r, "FireServer", nil) end) end
        RecordedCalls = {}
        print("[149] Записано:", #rec, "— повтор 15x")
        for i=1,15 do
            if not o.Parent then break end
            for _,r in ipairs(rec) do pcall(function() r.r:FireServer(unpack(r.a)) end) end
            task.wait(0.06)
        end
    end)
end
reg(149, "Events", "149. Remote Replay", "Запись 2с → повтор 15x", m_149)
local function m_158(o)
    if not debounce(158, o, 8) then return end
    print("[158] Хук на 2 сек — АТАКУЙ!")
    task.spawn(function()
        for _,rem in ipairs(DeepData.CombatRemotes) do
            if rem:IsA("RemoteEvent") and not RemoteMutation.hooked[rem] then
                pcall(function()
                    if rawset then
                        local orig = rem.FireServer
                        rawset(rem, "FireServer", function(self, ...)
                            RemoteMutation.lastCall = {rem=self, args={...}}
                            return orig(self, ...)
                        end)
                        RemoteMutation.hooked[rem] = orig
                    end
                end)
            end
        end
        task.wait(2)
        for rem,_ in pairs(RemoteMutation.hooked) do pcall(function() rawset(rem, "FireServer", nil) end) end
        RemoteMutation.hooked = {}
        if RemoteMutation.lastCall then
            local rc = RemoteMutation.lastCall
            print("[158] Мутируем и повторяем 20x")
            for i=1,20 do
                if not o.Parent then break end
                pcall(function()
                    local mut = {}
                    for j,a in ipairs(rc.args) do
                        if j==2 and type(a)=="number" then mut[j]=999999 else mut[j]=a end
                    end
                    rc.rem:FireServer(unpack(mut))
                end)
                task.wait(0.05)
            end
        end
    end)
end
reg(158, "Events", "158. Arg Mutation Replay", "Хук+мутация remote", m_158)
local function m_163(o)
    if not debounce(163, o, 8) then return end
    print("[163] Крадём OnClientEvent 3 сек — ЖДИ АТАКИ ДРУГИХ!")
    task.spawn(function()
        for _,rem in ipairs(rep:GetDescendants()) do
            if rem:IsA("RemoteEvent") and not StolenEventCache.hookedRemotes[rem] then
                pcall(function()
                    local c = rem.OnClientEvent:Connect(function(...)
                        table.insert(StolenEventCache.stolen, {rem=rem, args={...}})
                    end)
                    StolenEventCache.hookedRemotes[rem] = c
                end)
            end
        end
        task.wait(3)
        for _,c in pairs(StolenEventCache.hookedRemotes) do pcall(function() c:Disconnect() end) end
        StolenEventCache.hookedRemotes = {}
        print("[163] Украдено:", #StolenEventCache.stolen)
        for _,ev in ipairs(StolenEventCache.stolen) do pcall(function() ev.rem:FireServer(unpack(ev.args)) end) end
        StolenEventCache.stolen = {}
    end)
end
reg(163, "Events", "163. Event Steal Replay", "Красть OnClientEvent 3с", m_163)
local function m_166(o)
    if not debounce(166, o, 5) then return end
    task.spawn(function()
        local rfs = {}
        for _,rem in ipairs(DeepData.CombatRemotes) do if rem:IsA("RemoteFunction") then table.insert(rfs, rem) end end
        if #rfs == 0 then return end
        for i=1,40 do
            task.spawn(function() pcall(function() rfs[math.random(1,#rfs)]:InvokeServer(o, 999999) end) end)
        end
        task.wait(0.2)
        local h = o:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:TakeDamage(math.huge); h.Health = 0 end) end
    end)
end
reg(166, "Events", "166. Invoke Recursion 40x", "40 InvokeServer параллельно", m_166)
local function m_17(o)
    local c = lp.Character; if not c then return end
    local t = c:FindFirstChildOfClass("Tool") or lp.Backpack:FindFirstChildOfClass("Tool"); if not t then return end
    if t.Parent ~= c then t.Parent = c end
    if not debounce(17, o, 1) then return end
    local h = t:FindFirstChild("Handle"); local r = getRoot(o)
    task.spawn(function()
        for i=1,3 do
            if not o.Parent then break end
            pcall(function() t:Activate() end)
            if h and r and firetouchinterest then
                pcall(function()
                    h.Size = Vector3.new(35, 35, 35)
                    h.Massless = true; h.CanCollide = false
                    firetouchinterest(h, r, 0)
                    firetouchinterest(h, r, 1)
                end)
            end
            task.wait(0.15)
        end
        if h then pcall(function() h.Size = Vector3.new(1, 4, 1) end) end
    end)
end
reg(17, "Weapons", "17. Weapon Overdrive", "Tool:Activate x3 + hitbox 35", m_17)
local function m_19(o)
    if #DeepData.WeaponRemotes == 0 then runAnalysis() end
    if not debounce(19, o, 1) then return end
    for _,r in ipairs(DeepData.WeaponRemotes) do
        pcall(function() if r:IsA("RemoteEvent") then r:FireServer(o, 999999) end end)
    end
end
reg(19, "Weapons", "19. Weapon Remote Hijack", "Все Tool remotes → FireServer", m_19)
local function m_25(o) for _,v in ipairs(getCached(o).parts) do local nm=safeLower(v.Name); if nm:find("hitbox") or nm:find("weapon") then pcall(function() v:Destroy() end) end end end
reg(25, "Weapons", "25. Disarm Hitbox", "Destroy hitbox/weapon parts", m_25)
local function m_89(o) claimFE(o); for _,v in ipairs(getCached(o).welds) do if v.Part1 and safeLower(v.Part1.Name):find("weapon") then pcall(function() v.Part0=nil; v.Part1=nil end) end end end
reg(89, "Weapons", "89. Weld Detach Weapon", "Отрыв weapon welds", m_89)
local function m_37(o)
    if not firetouchinterest then return end
    if not debounce(37, o, 1) then return end
    local c = lp.Character; if not c then return end
    local t = c:FindFirstChildOfClass("Tool") or lp.Backpack:FindFirstChildOfClass("Tool"); if not t then return end
    if t.Parent ~= c then t.Parent = c end
    local tp = {}; for _,p in ipairs(t:GetDescendants()) do if p:IsA("BasePart") then table.insert(tp, p) end end
    local np = getCached(o).parts
    if #tp == 0 or #np == 0 then return end
    task.spawn(function()
        for i=1,2 do
            if not o.Parent then break end
            pcall(function() t:Activate() end)
            local total = math.min(20, #tp * #np)
            for j=1,total do
                pcall(function()
                    local a = tp[((j-1) % #tp) + 1]
                    local b = np[((j-1) % #np) + 1]
                    firetouchinterest(a, b, 0)
                    firetouchinterest(a, b, 1)
                end)
            end
            task.wait(0.15)
        end
    end)
end
reg(37, "Weapons", "37. Matrix Touch (20 pairs)", "Tool×NPC max 20 pairs (было M×N)", m_37)
local function m_155(o)
    local c = lp.Character; if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid"); if not h then return end
    local ot = c:FindFirstChildOfClass("Tool") or lp.Backpack:FindFirstChildOfClass("Tool"); if not ot then return end
    if not debounce(155, o, 5) then return end
    task.spawn(function()
        local cls = {}
        for i=1,3 do
            pcall(function()
                local cl = ot:Clone()
                cl.Parent = lp.Backpack
                Deb:AddItem(cl, 3)
                table.insert(cls, cl)
            end)
        end
        task.wait(0.1)
        local r = getRoot(o)
        for _,cl in ipairs(cls) do
            pcall(function()
                h:EquipTool(cl)
                cl:Activate()
                local hd = cl:FindFirstChild("Handle")
                if hd and r and firetouchinterest then
                    firetouchinterest(hd, r, 0); firetouchinterest(hd, r, 1)
                end
            end)
        end
    end)
end
reg(155, "Weapons", "155. Tool Clone x3", "3 клона (было 20!)", m_155)
local function m_145(o)
    local c = lp.Character; if not c then return end
    local t = c:FindFirstChildOfClass("Tool") or lp.Backpack:FindFirstChildOfClass("Tool"); if not t then return end
    if t.Parent ~= c then t.Parent = c end
    local h = t:FindFirstChild("Handle"); if not h then return end
    local r = getRoot(o); if not r then return end
    if not debounce(145, o, 3) then return end
    task.spawn(function()
        local oS = h.Size
        pcall(function()
            local mR = c:FindFirstChild("HumanoidRootPart")
            if mR then
                local d = (r.Position - mR.Position).Magnitude + 20
                h.Size = Vector3.new(5, 5, d)
                h.Massless = true; h.CanCollide = false
                h.CFrame = CFrame.new(mR.Position, r.Position) * CFrame.new(0, 0, -d/2)
            end
            t:Activate()
            if firetouchinterest then firetouchinterest(h, r, 0); firetouchinterest(h, r, 1) end
        end)
        task.wait(0.3)
        pcall(function() h.Size = oS end)
    end)
end
reg(145, "Weapons", "145. Handle Morph (1 shot)", "Handle → NPC 1 раз", m_145)
local function m_174(o)
    local c = lp.Character; if not c then return end
    local t = c:FindFirstChildOfClass("Tool") or lp.Backpack:FindFirstChildOfClass("Tool"); if not t then return end
    if t.Parent ~= c then t.Parent = c end
    local r = getRoot(o); if not r then return end
    if not debounce(174, o, 3) then return end
    task.spawn(function()
        local og = t.Grip
        pcall(function()
            local myR = c:FindFirstChild("HumanoidRootPart")
            if myR then
                local dist = (r.Position - myR.Position).Magnitude
                t.Grip = CFrame.new(0, 0, -dist)
            end
            for i=1,3 do
                pcall(function() t:Activate() end)
                local h = t:FindFirstChild("Handle")
                if h and firetouchinterest then firetouchinterest(h, r, 0); firetouchinterest(h, r, 1) end
                task.wait(0.15)
            end
        end)
        pcall(function() t.Grip = og end)
    end)
end
reg(174, "Weapons", "174. Grip Overshoot", "Grip CFrame -distance", m_174)
local function m_43(o)
    if not firetouchinterest then return end
    local r = getRoot(o); if not r then return end
    if not debounce(43, o, 2) then return end
    task.spawn(function()
        local at = {}
        for _,d in ipairs(ws:GetDescendants()) do
            if d:IsA("TouchTransmitter") and d.Parent and d.Parent:IsA("BasePart") and d.Parent ~= r then
                table.insert(at, d.Parent)
                if #at >= 30 then break end
            end
        end
        for _,t in ipairs(at) do
            pcall(function() firetouchinterest(r, t, 0); firetouchinterest(r, t, 1) end)
        end
    end)
end
reg(43, "Touch", "43. Touch Matrix (30 max)", "Max 30 TouchTransmitters", m_43)
local function m_88(o)
    if not firetouchinterest then return end
    local c = lp.Character; local r = getRoot(o); if not c or not r then return end
    if not debounce(88, o, 1) then return end
    for _,p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then pcall(function() firetouchinterest(p, r, 0); firetouchinterest(p, r, 1) end) end
    end
end
reg(88, "Touch", "88. Multi-Node Touch", "Части игрока → NPC root", m_88)
local function m_134(o)
    if not firetouchinterest then return end
    if not debounce(134, o, 2) then return end
    local c = lp.Character; if not c then return end
    local mp = {}; for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then table.insert(mp, p) end end
    local np = getCached(o).parts
    if #mp == 0 or #np == 0 then return end
    task.spawn(function()
        for i=1,40 do
            pcall(function()
                local a = mp[math.random(1, #mp)]; local b = np[math.random(1, #np)]
                if a and b then firetouchinterest(a, b, 0); firetouchinterest(a, b, 1) end
            end)
        end
    end)
end
reg(134, "Touch", "134. Touched Bomb 40x", "40 случайных Touched (было 200)", m_134)
local function m_7(o) claimFE(o); for _,v in ipairs(o:GetDescendants()) do if v:IsA("WeldConstraint") or v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") or v:IsA("AlignPosition") or v:IsA("SpringConstraint") then pcall(function() v:Destroy() end) end end end
reg(7, "CustomRigs", "7. Constraint Shatter", "Уничтожение Constraint", m_7)
local function m_8(o) claimFE(o); for _,v in ipairs(getCached(o).bones) do pcall(function() v.Transform=CFrame.new(math.random(-50,50),math.random(-50,50),math.random(-50,50)) end) end end
reg(8, "CustomRigs", "8. Bone Shatter", "Bones случайный CFrame", m_8)
local function m_9(o)
    claimFE(o)
    if not debounce(9, o, 1) then return end
    for i,p in ipairs(getCached(o).parts) do
        pcall(function() p.AssemblyLinearVelocity = Vector3.new(math.sin(i*99)*50000, math.cos(i*77)*50000, math.sin(i*33)*50000) end)
    end
end
reg(9, "CustomRigs", "9. Kinetic Body Tear", "Parts × разные velocity", m_9)
local function m_94(o) local t=o:FindFirstChildOfClass("Humanoid") or o:FindFirstChildOfClass("AnimationController"); if not t then return end; pcall(function() for _,tr in ipairs(t:GetPlayingAnimationTracks()) do tr:Stop(0) end end) end
reg(94, "CustomRigs", "94. Animation Lock", "Stop все anim tracks", m_94)
local function m_95(o) claimFE(o); for _,p in ipairs(getCached(o).parts) do pcall(function() p.RootPriority=-127; p.Massless=true end) end end
reg(95, "CustomRigs", "95. RootPriority Zero", "RootPriority=-127", m_95)
local function m_124(o)
    claimFE(o)
    if not debounce(124, o, 1) then return end
    task.spawn(function()
        for i,p in ipairs(getCached(o).parts) do
            pcall(function()
                p.CanCollide=true; p.Massless=true
                local d=Vector3.new(math.sin(i*0.7)*3000, math.abs(math.cos(i*0.3))*4000, math.cos(i*1.1)*3000)
                p.AssemblyLinearVelocity=d
            end)
        end
    end)
end
reg(124, "CustomRigs", "124. Velocity Shredder", "Разрыв через velocity (1 wave)", m_124)
local function m_127(o)
    claimFE(o)
    if not debounce(127, o, 2) then return end
    task.spawn(function()
        local mts = getCached(o).welds
        for tick=1,8 do
            if not o.Parent then break end
            for i,m in ipairs(mts) do
                pcall(function() local t=tick*0.1+i*0.37; m.C0 = m.C0 * CFrame.new(math.sin(t)*300, math.cos(t*1.3)*300, math.sin(t*0.7)*300) end)
            end
            task.wait(0.1)
        end
    end)
end
reg(127, "CustomRigs", "127. CFrame Loop Crusher", "Motor6D CFrame 8 tick", m_127)
local function m_128(o)
    claimFE(o)
    local t = o:FindFirstChildOfClass("Humanoid") or o:FindFirstChildOfClass("AnimationController"); if not t then return end
    if not debounce(128, o, 5) then return end
    task.spawn(function()
        local a = t:FindFirstChildOfClass("Animator")
        if not a then a = Instance.new("Animator"); a.Parent = t end
        for i=1,30 do
            if not o.Parent then break end
            pcall(function()
                local an = Instance.new("Animation")
                an.AnimationId = "rbxassetid://0"
                local tr = a:LoadAnimation(an)
                tr:Play()
            end)
        end
        task.wait(0.15)
        local h = o:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:TakeDamage(math.huge); h.Health = 0 end) end
    end)
end
reg(128, "CustomRigs", "128. Anim Overload 30x", "30 tracks (было 500!)", m_128)
local function m_129(o)
    local r=getRoot(o); if not r then return end
    if not debounce(129, o, 3) then return end
    task.spawn(function()
        for i=1,3 do
            if not o.Parent then break end
            pcall(function()
                local s = Instance.new("Sound")
                s.SoundId = "rbxassetid://9046196336"
                s.Volume = 10; s.PlaybackSpeed = math.huge; s.Pitch = 20
                s.Parent = r; s:Play()
                Deb:AddItem(s, 0.5)
            end)
            task.wait(0.15)
        end
    end)
end
reg(129, "CustomRigs", "129. Sound Freq Weapon", "Sound PlaybackSpeed=huge", m_129)
local function m_130(o)
    claimFE(o)
    if not debounce(130, o, 2) then return end
    task.spawn(function()
        local ats = getCached(o).atts
        for tick=1,8 do
            if not o.Parent then break end
            for i,at in ipairs(ats) do
                pcall(function() local t=tick*0.15+i*0.5; at.CFrame = CFrame.new(math.sin(t)*100, math.cos(t)*100, math.sin(t*2)*100) end)
            end
            task.wait(0.1)
        end
    end)
end
reg(130, "CustomRigs", "130. Attachment Chaos", "Attachments орбиты", m_130)
local function m_131(o) claimFE(o); if not debounce(131, o, 3) then return end; pcall(function() local gn="V"..tostring(math.random(1000,9999)); pcall(function() PS:RegisterCollisionGroup(gn) end); pcall(function() PS:CollisionGroupSetCollidable(gn,"Default",false) end); for _,p in ipairs(getCached(o).parts) do pcall(function() p.CollisionGroup=gn; p.CanCollide=false; p.Massless=true end) end; local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.FallingDown); h:TakeDamage(math.huge) end) end end) end
reg(131, "CustomRigs", "131. CollisionGroup Iso", "Свой CollisionGroup", m_131)
local function m_132(o)
    if not debounce(132, o, 3) then return end
    task.spawn(function()
        local ps = {}; for _,p in ipairs(getCached(o).parts) do if not p.Anchored then table.insert(ps, p) end end
        for wave=1,4 do
            if not o.Parent then break end
            for _,p in ipairs(ps) do
                pcall(function() if wave%2==0 then p:SetNetworkOwner(lp) else p:SetNetworkOwnershipAuto() end end)
            end
            task.wait(0.1)
        end
        local h = o:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:TakeDamage(math.huge); h.Health = 0 end) end
    end)
end
reg(132, "CustomRigs", "132. NetOwner Ping-Pong 4x", "4 переключения (было 10)", m_132)
local function m_133(o)
    claimFE(o)
    if not debounce(133, o, 3) then return end
    task.spawn(function()
        for _,p in ipairs(getCached(o).parts) do
            pcall(function()
                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Velocity = Vector3.new((math.random()-0.5)*300, math.random()*400, (math.random()-0.5)*300)
                bv.Parent = p
                Deb:AddItem(bv, 0.8)
            end)
        end
        task.wait(0.5)
        local h = o:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:TakeDamage(math.huge); h.Health = 0 end) end
    end)
end
reg(133, "CustomRigs", "133. BodyForce Push", "BodyVelocity 0.8s", m_133)
local function m_135(o) claimFE(o); pcall(function() for _,p in ipairs(getCached(o).parts) do pcall(function() p.Size=Vector3.new(0.01,0.01,0.01); p.Massless=true end) end; local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:TakeDamage(math.huge); h.Health=0 end) end end) end
reg(135, "CustomRigs", "135. Mesh Resize 0.01", "Parts → 1см", m_135)
local function m_140(o) claimFE(o); pcall(function() for _,d in ipairs(o:GetDescendants()) do if d:IsA("WrapLayer") or d:IsA("WrapTarget") then pcall(function() d:Destroy() end) end; if d:IsA("MeshPart") then pcall(function() d.HasSkinnedMesh=false; d.Size=Vector3.new(0.01,0.01,0.01) end) end; if d:IsA("Bone") then pcall(function() d.Position=Vector3.new(math.random(-1e6,1e6),math.random(-1e6,1e6),math.random(-1e6,1e6)) end) end end; local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:TakeDamage(math.huge) end) end end) end
reg(140, "CustomRigs", "⭐140. SkinnedMesh Annihilate", "MOST POWERFUL!", m_140)
local function m_144(o) claimFE(o); pcall(function() for _,d in ipairs(o:GetDescendants()) do if d:IsA("ControllerManager") then pcall(function() d.BaseMoveSpeed=0; d.BaseTurnSpeed=0 end) end end; local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Ragdoll); h.Health=0 end) end end) end
reg(144, "CustomRigs", "144. CtrlManager Hijack", "ControllerManager=0", m_144)
local function m_147(o) claimFE(o); pcall(function() for _,d in ipairs(o:GetDescendants()) do if d:IsA("SpecialMesh") then pcall(function() d.MeshId=""; d.Scale=Vector3.new(0,0,0) end) elseif d:IsA("MeshPart") then pcall(function() d.MeshId=""; d.Size=Vector3.new(0.01,0.01,0.01) end) end end; local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:TakeDamage(math.huge) end) end end) end
reg(147, "CustomRigs", "147. MeshId Corruption", "MeshId=''", m_147)
local function m_151(o) claimFE(o); pcall(function() for _,d in ipairs(getCached(o).parts) do if d:IsA("Part") then pcall(function() d.Shape=Enum.PartType.Ball end) end end; local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Physics); h:TakeDamage(math.huge) end) end end) end
reg(151, "CustomRigs", "151. Part → Ball", "Shape=Ball", m_151)
local function m_154(o) claimFE(o); pcall(function() for _,d in ipairs(getCached(o).parts) do local nm=safeLower(d.Name); if nm:find("hitbox") or nm:find("weapon") or nm:find("attack") or nm:find("claw") or nm:find("blade") then pcall(function() d.CanQuery=false; d.CanTouch=false; d.CanCollide=false; d.Transparency=1 end) end end; local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:TakeDamage(math.huge); h.Health=0 end) end end) end
reg(154, "CustomRigs", "154. CanQuery Disable", "Вырубить hitboxes", m_154)
local function m_159(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); if not h then return end; if not debounce(159, o, 3) then return end; pcall(function() local ct=h.RigType; h.RigType=(ct==Enum.HumanoidRigType.R15) and Enum.HumanoidRigType.R6 or Enum.HumanoidRigType.R15; task.wait(0.05); h.RigType=ct; task.wait(0.05); h.RigType=(ct==Enum.HumanoidRigType.R15) and Enum.HumanoidRigType.R6 or Enum.HumanoidRigType.R15; h:TakeDamage(math.huge); h.Health=0 end) end
reg(159, "CustomRigs", "159. Rig Type Coercion", "R6/R15 mismatch", m_159)
local function m_162(o) claimFE(o); local r=getRoot(o); if not r then return end; if not debounce(162, o, 3) then return end; task.spawn(function() pcall(function() local at=r:FindFirstChildOfClass("Attachment") or Instance.new("Attachment", r); local ap=Instance.new("AlignPosition"); ap.Attachment0=at; ap.Mode=Enum.PositionAlignmentMode.OneAttachment; ap.MaxForce=math.huge; ap.MaxVelocity=math.huge; ap.Responsiveness=200; ap.Position=Vector3.new(r.Position.X,-1000,r.Position.Z); ap.Parent=r; Deb:AddItem(ap,3); local h=o:FindFirstChildOfClass("Humanoid"); if h then h:ChangeState(Enum.HumanoidStateType.FallingDown); h:TakeDamage(math.huge) end end) end) end
reg(162, "CustomRigs", "162. Physics Pipeline Hijack", "AlignPosition math.huge", m_162)
local function m_168(o)
    claimFE(o)
    local t = o:FindFirstChildOfClass("Humanoid") or o:FindFirstChildOfClass("AnimationController")
    if not t then return end
    if not debounce(168, o, 5) then return end
    task.spawn(function()
        pcall(function()
            for _,a in ipairs(t:GetChildren()) do if a:IsA("Animator") then a:Destroy() end end
            task.wait()
            local an = Instance.new("Animator"); an.Parent = t
            for i=1,20 do
                pcall(function()
                    local a = Instance.new("Animation")
                    a.AnimationId = "rbxassetid://" .. tostring(math.random(1, 999999999))
                    local tr = an:LoadAnimation(a)
                    tr:Play()
                end)
            end
            task.wait(0.1)
            local h = o:FindFirstChildOfClass("Humanoid")
            if h then h:TakeDamage(math.huge); h.Health = 0 end
        end)
    end)
end
reg(168, "CustomRigs", "168. Animator Eval Poison", "Свой Animator + 20 tracks", m_168)
local function m_171(o)
    claimFE(o)
    if not debounce(171, o, 3) then return end
    local r = getRoot(o); if not r then return end
    task.spawn(function()
        for tick=1,15 do
            if not o.Parent then break end
            pcall(function()
                local a = tick*0.5
                r.AssemblyLinearVelocity = Vector3.new(math.sin(a)*5e5, math.cos(a)*5e5, math.sin(a*2)*5e5)
            end)
            rs.Heartbeat:Wait()
        end
        local h = o:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Physics); h.Health = 0 end) end
    end)
end
reg(171, "CustomRigs", "171. Velocity Knockback", "Осц. velocity 15 tick", m_171)
local function m_175(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); if not h then return end; if not debounce(175, o, 4) then return end; task.spawn(function() pcall(function() local ats=getCached(o).atts; for _,at in ipairs(ats) do pcall(function() at.CFrame=CFrame.new(math.random(-1e5,1e5),math.random(-1e5,1e5),math.random(-1e5,1e5)) end) end; task.wait(); pcall(function() h:BuildRigFromAttachments() end); task.wait(0.1); h:TakeDamage(math.huge); h.Health=0 end) end) end
reg(175, "CustomRigs", "175. BuildRig Exploit", "Испорченный BuildRigFromAttachments", m_175)
local function m_4(o) claimFE(o); for _,v in ipairs(o:GetDescendants()) do if v:IsA("NumberValue") or v:IsA("IntValue") then local nm=safeLower(v.Name); if nm:find("hp") or nm:find("health") or nm:find("shield") then pcall(function() v.Value=0 end) end end end; for a,_ in pairs(o:GetAttributes()) do local nm=safeLower(a); if nm:find("hp") or nm:find("health") then pcall(function() o:SetAttribute(a,0) end) end end end
reg(4, "MathStats", "4. Value/Attr Zero", "HP values → 0", m_4)
local function m_11(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); if h then if not debounce(11, o, 1) then return end; task.spawn(function() for i=1,5 do if not o.Parent then break end; pcall(function() h:TakeDamage(math.huge); h.Health=0 end); task.wait(0.1) end end) end end
reg(11, "MathStats", "11. TakeDamage Loop x5", "TakeDamage(huge) x5", m_11)
local function m_12(o) for _,v in ipairs(o:GetDescendants()) do if v:IsA("NumberValue") then local nm=safeLower(v.Name); if nm:find("hp") or nm:find("health") then pcall(function() v.Value=0/0 end) end end end end
reg(12, "MathStats", "12. NaN Crash", "HP = NaN", m_12)
local function m_13(o) for _,v in ipairs(o:GetDescendants()) do if v:IsA("NumberValue") then local nm=safeLower(v.Name); if nm:find("hp") or nm:find("damage") then pcall(function() v.Value=1e308 end) end end end end
reg(13, "MathStats", "13. Double Overflow", "HP = 1e308", m_13)
local function m_14(o) for _,v in ipairs(o:GetDescendants()) do if v:IsA("NumberValue") or v:IsA("IntValue") then local nm=safeLower(v.Name); if nm:find("hp") or nm:find("health") then pcall(function() v.Value=-999999 end) end end end end
reg(14, "MathStats", "14. Negative HP", "HP = -999999", m_14)
local function m_15(o) for _,ff in ipairs(o:GetDescendants()) do if ff:IsA("ForceField") then pcall(function() ff:Destroy() end) end end; for _,v in ipairs(o:GetDescendants()) do if v:IsA("NumberValue") or v:IsA("BoolValue") then local nm=safeLower(v.Name); if nm:find("shield") or nm:find("god") then pcall(function() if v:IsA("BoolValue") then v.Value=false else v.Value=0 end end) end end end end
reg(15, "MathStats", "15. Strip Shields", "ForceField+shield=0", m_15)
local function m_16(o) local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h.MaxHealth=1; h.Health=0 end) end end
reg(16, "MathStats", "16. MaxHealth=1", "MaxHealth=1", m_16)
local function m_91(o) local r=getRoot(o); local h=o:FindFirstChildOfClass("Humanoid"); for _,it in ipairs({o,r,h}) do if it then for _,a in ipairs({"Shield","Armor","GodMode","Invulnerable"}) do pcall(function() it:SetAttribute(a,0) end) end end end end
reg(91, "MathStats", "91. Shield Vaporizer", "Shield attrs = 0", m_91)
local function m_96(o) pcall(function() for _,t in ipairs({"Dead","Killed","KillBrick","Lava","Deadly","Death"}) do pcall(function() CS:AddTag(o, t) end) end end) end
reg(96, "MathStats", "96. Universal Death Tag", "Все death-теги", m_96)
local function m_118(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); if not debounce(118, o, 1) then return end; task.spawn(function() for i=1,10 do if not o.Parent then break end; pcall(function() if h then h.MaxHealth=0; h.Health=0; h:TakeDamage(math.huge) end end); task.wait(0.08) end end) end
reg(118, "MathStats", "118. Health Clamp x10", "MaxHealth=0 loop", m_118)
local function m_120(o) pcall(function() for _,p in ipairs(getCached(o).parts) do pcall(function() p.BrickColor=BrickColor.new("Medium stone grey") end) end; for _,a in ipairs({"Team","TeamColor","Faction","Enemy"}) do pcall(function() o:SetAttribute(a,"Neutral") end) end; local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:TakeDamage(math.huge); h.Health=0 end) end end) end
reg(120, "MathStats", "120. Neutral Team", "Team → Neutral", m_120)
local function m_122(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); if not h then return end; if not debounce(122, o, 2) then return end; task.spawn(function() for wave=1,2 do if not o.Parent then break end; for i=1,30 do pcall(function() h:TakeDamage(1e9) end) end; pcall(function() h.Health=0 end); task.wait(0.08) end end) end
reg(122, "MathStats", "122. Massive TakeDamage", "30×TakeDamage(1e9) x2", m_122)
local function m_136(o) pcall(function() for _,v in ipairs(o:GetDescendants()) do pcall(function() if v:IsA("NumberValue") or v:IsA("IntValue") then v.Value=0 elseif v:IsA("BoolValue") then v.Value=false end end) end; for a,vl in pairs(o:GetAttributes()) do pcall(function() if type(vl)=="number" then o:SetAttribute(a,0) elseif type(vl)=="boolean" then o:SetAttribute(a,false) end end) end end) end
reg(136, "MathStats", "136. Cascade Purge", "Обнуление Values/Attributes", m_136)
local function m_138(o) claimFE(o); pcall(function() for _,v in ipairs(o:GetDescendants()) do if v:IsA("NumberValue") or v:IsA("IntValue") then local nm=safeLower(v.Name); if nm:find("regen") or nm:find("heal") then pcall(function() v.Value=-1e6 end) end end end; local h=o:FindFirstChildOfClass("Humanoid"); if h then local c; c=h.HealthChanged:Connect(function(nh) if nh>0 then pcall(function() h.Health=0 end) end end); task.delay(8,function() if c then c:Disconnect() end end) end end) end
reg(138, "MathStats", "138. Regen Inversion", "Regen=-1e6+auto-kill", m_138)
local function m_143(o) pcall(function() for _,v in ipairs(o:GetDescendants()) do if v:IsA("NumberValue") or v:IsA("IntValue") then local nm=safeLower(v.Name); if nm:find("defense") or nm:find("armor") or nm:find("resist") then pcall(function() v.Value=0 end) elseif nm:find("multi") then pcall(function() v.Value=1000 end) end end end end) end
reg(143, "MathStats", "143. Defense Hijack", "Armor=0, Multi=1000", m_143)
local function m_148(o) pcall(function() for _,st in ipairs({"Poison","Burn","Bleed","Frozen","Cursed"}) do o:SetAttribute(st,true); o:SetAttribute(st.."Stacks",999); o:SetAttribute(st.."Damage",999999) end; local h=o:FindFirstChildOfClass("Humanoid"); if h and debounce(148, o, 3) then task.spawn(function() for i=1,10 do if not o.Parent then break end; pcall(function() h:TakeDamage(50000) end); task.wait(0.2) end end) end end) end
reg(148, "MathStats", "148. Status Effect Inject", "Poison/Burn+DoT loop", m_148)
local function m_153(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); if not h then return end; if not debounce(153, o, 2) then return end; task.spawn(function() local m=h.MaxHealth; for step=1,8 do if not o.Parent then break end; pcall(function() m=m*0.5; h.MaxHealth=math.max(1,m); h.Health=math.min(h.Health,h.MaxHealth); if step>=6 then h.MaxHealth=0; h.Health=0 end end); task.wait(0.12) end end) end
reg(153, "MathStats", "153. MaxHealth Ladder", "MaxHealth ×0.5", m_153)
local function m_167(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); if not h then return end; pcall(function() h.HealthDisplayDistance=-1; h.NameDisplayDistance=-1; h.HealthDisplayType=Enum.HumanoidHealthDisplayType.AlwaysOff; for i=1,3 do h.Health=-math.huge; h:TakeDamage(math.huge) end end) end
reg(167, "MathStats", "167. HealthDisplay Corrupt", "HealthDisplayDist=-1", m_167)
local function m_86(o) local h=o:FindFirstChildOfClass("Humanoid"); if not h then return end; local d=CombatSettings.DamageAmount; pcall(function() h:TakeDamage(d); if d>=999999 then h.Health=0 end end) end
reg(86, "GoldenGrail", "86. Golden Grail", "TakeDamage настраиваемый", m_86)
local function m_87(o) local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:TakeDamage(999999); h.Health=0 end) end; if not debounce(87, o, 1) then return end; task.spawn(function() for _,r in ipairs(DeepData.CombatRemotes) do pcall(function() if r:IsA("RemoteEvent") then r:FireServer(o, 999999) end end) end end) end
reg(87, "GoldenGrail", "87. Grail Composite", "TakeDamage+эхо remotes", m_87)
local function m_141(o) local h=o:FindFirstChildOfClass("Humanoid"); if not h then return end; if not debounce(141, o, 2) then return end; task.spawn(function() for w=1,4 do if not o.Parent then break end; local d=CombatSettings.DamageAmount*w; pcall(function() h:TakeDamage(d); if w>=3 then h.Health=0 end end); task.wait(0.15) end end) end
reg(141, "GoldenGrail", "141. Grail Wave Stack", "4 нарастающих волн", m_141)
local function m_152(o) local h=o:FindFirstChildOfClass("Humanoid"); if not h then return end; if not debounce(152, o, 2) then return end; task.spawn(function() local d=CombatSettings.DamageAmount; for i=1,100 do pcall(function() h:TakeDamage(d) end) end; pcall(function() h.Health=0 end) end) end
reg(152, "GoldenGrail", "152. Grail Shotgun 100x", "100×TakeDamage за кадр (было 200)", m_152)
local function m_93(o)
    if not debounce(93, o, 3) then return end
    local count = 0
    for _,d in ipairs(ws:GetDescendants()) do
        if d:IsA("ProximityPrompt") then pcall(function() if fireproximityprompt then fireproximityprompt(d) end end); count = count + 1
        elseif d:IsA("ClickDetector") then pcall(function() if fireclickdetector then fireclickdetector(d) end end); count = count + 1 end
        if count > 50 then break end
    end
end
reg(93, "PlayerInputSim", "93. PP/Click Overload", "Max 50 PP+ClickDetector", m_93)
local function m_98(o)
    local c = lp.Character; if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid"); if not h then return end
    if not debounce(98, o, 2) then return end
    task.spawn(function()
        local tools = {}
        for _,t in ipairs(c:GetChildren()) do if t:IsA("Tool") then table.insert(tools, t) end end
        for _,t in ipairs(lp.Backpack:GetChildren()) do if t:IsA("Tool") then table.insert(tools, t) end end
        for _,t in ipairs(tools) do
            if not o.Parent then break end
            pcall(function() h:EquipTool(t) end)
            task.wait(0.1)
            for i=1,3 do pcall(function() t:Activate() end); task.wait(0.15) end
        end
    end)
end
reg(98, "PlayerInputSim", "98. Tool Activate Legit", "Cycle Equip+Activate 3x", m_98)
local function m_99(o) local keys={Enum.KeyCode.Q,Enum.KeyCode.E,Enum.KeyCode.R,Enum.KeyCode.F,Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,Enum.KeyCode.Four}; task.spawn(function() for _,k in ipairs(keys) do pcall(function() VIM:SendKeyEvent(true,k,false,game); task.wait(0.05); VIM:SendKeyEvent(false,k,false,game) end); task.wait(0.1) end end) end
reg(99, "PlayerInputSim", "99. Ability Keys", "Q/E/R/F/1-4", m_99)
local function m_102(o) local c=lp.Character; if not c then return end; local mH=c:FindFirstChildOfClass("Humanoid"); if not mH then return end; task.spawn(function() for i=1,6 do pcall(function() if mH.Health<mH.MaxHealth*0.5 then mH.Health=mH.MaxHealth end; if not c:FindFirstChildOfClass("ForceField") then local ff=Instance.new("ForceField"); ff.Visible=false; ff.Parent=c; Deb:AddItem(ff,3) end end); task.wait(0.5) end end); pcall(function() mH.BreakJointsOnDeath=false end) end
reg(102, "PlayerInputSim", "102. Self-Kick Prevent (Base)", "Base защита игрока", m_102)
local function m_103(o) local c=lp.Character; if not c then return end; local h=c:FindFirstChildOfClass("Humanoid"); for _,t in ipairs(lp.Backpack:GetChildren()) do if t:IsA("Tool") then pcall(function() h:EquipTool(t) end); task.wait(0.05) end end end
reg(103, "PlayerInputSim", "103. Auto-Equip All", "Взять все Tools", m_103)
local function m_142(o) if not fireproximityprompt then return end; if not debounce(142, o, 2) then return end; task.spawn(function() for wave=1,2 do if not o.Parent then break end; for _,pp in ipairs(o:GetDescendants()) do if pp:IsA("ProximityPrompt") then pcall(function() fireproximityprompt(pp) end) end end; task.wait(0.2) end end) end
reg(142, "PlayerInputSim", "142. PP Abuse", "Триггер PP на боссе", m_142)
local function m_170(o)
    if not debounce(170, o, 5) then return end
    local h = o:FindFirstChildOfClass("Humanoid"); if not h then return end
    local os = cam.CameraSubject
    task.spawn(function()
        pcall(function()
            cam.CameraSubject = h
            task.wait(0.1)
            for _,r in ipairs(DeepData.CombatRemotes) do
                pcall(function() if r:IsA("RemoteEvent") then r:FireServer(o, 999999) end end)
            end
            h:TakeDamage(math.huge); h.Health = 0
            task.wait(0.5)
            cam.CameraSubject = os
        end)
    end)
end
reg(170, "PlayerInputSim", "170. Camera Subject Hijack", "cam.CameraSubject=boss.Hum", m_170)
local function m_172(o)
    if not fireproximityprompt then return end
    if not debounce(172, o, 3) then return end
    task.spawn(function()
        local pps = {}
        for _,d in ipairs(o:GetDescendants()) do if d:IsA("ProximityPrompt") then table.insert(pps, d) end end
        if #pps == 0 then return end
        for wave=1,3 do
            for _,p in ipairs(pps) do
                for i=1,3 do pcall(function() fireproximityprompt(p) end) end
            end
            task.wait(0.1)
        end
    end)
end
reg(172, "PlayerInputSim", "172. PP Recursive 27x", "3x3 PP fire (было 500)", m_172)
local function m_10(o) claimFE(o); local r=getRoot(o); if not r then return end; pcall(function() r.AssemblyAngularVelocity=Vector3.new(1e6,1e6,1e6) end) end
reg(10, "DestroyerServer", "10. Angular Spin", "AssemblyAngular 1e6", m_10, false)
local function m_29(o) claimFE(o); local r=getRoot(o); if not r then return end; pcall(function() r.CanCollide=false; r.CFrame=r.CFrame+Vector3.new(0,50,0); r.AssemblyLinearVelocity=Vector3.new(1e9,1e9,-1e9) end) end
reg(29, "DestroyerServer", "29. Supersonic Launch", "Отстрел 10^9", m_29, false)
local function m_41(o) claimFE(o); for _,v in ipairs(getCached(o).welds) do pcall(function() v.C0=CFrame.new(0,-5000,0); v.C1=CFrame.new(10000,10000,10000) end) end end
reg(41, "DestroyerServer", "41. Motor Crush", "C0/C1 крайние", m_41, false)
local function m_157(o) if not debounce(157, o, 3) then return end; task.spawn(function() local parts=getCached(o).parts; for _,p in ipairs(parts) do pcall(function() if not p.Anchored then p:SetNetworkOwner(lp) end end) end; task.wait(0.05); rs.Heartbeat:Wait(); local r=getRoot(o); if r then for i=1,5 do pcall(function() r.AssemblyLinearVelocity=Vector3.new(math.random(-1e5,1e5),1e5,math.random(-1e5,1e5)) end) end end; local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:TakeDamage(math.huge); h.Health=0 end) end end) end
reg(157, "BossSpecial", "157. Server-Auth Bypass", "Ownership queue exploit", m_157)
local function m_160(o)
    if not debounce(160, o, 8) then return end
    local myChar = lp.Character
    local myCF = myChar and myChar:FindFirstChild("HumanoidRootPart") and myChar.HumanoidRootPart.CFrame
    task.spawn(function()
        pcall(function()
            lp.Character = o
            task.wait()
            local h = o:FindFirstChildOfClass("Humanoid")
            if h then h.Health = 0; h:TakeDamage(math.huge); if o.BreakJoints then o:BreakJoints() end end
            task.wait(0.1)
            lp.Character = myChar
            if myChar and myChar:FindFirstChild("HumanoidRootPart") and myCF then myChar.HumanoidRootPart.CFrame = myCF end
        end)
    end)
end
reg(160, "BossSpecial", "160. Character Mirror", "lp.Character=boss 1 кадр", m_160)
local function m_161(o)
    if not debounce(161, o, 5) then return end
    task.spawn(function()
        local hs = string.rep("A", 30000)
        for _,rem in ipairs(DeepData.CombatRemotes) do
            if rem:IsA("RemoteEvent") then
                pcall(function() rem:FireServer(o, hs); rem:FireServer(o, 999999, hs) end)
            end
        end
        task.wait(0.2)
        local h = o:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:TakeDamage(math.huge); h.Health = 0 end) end
    end)
end
reg(161, "BossSpecial", "161. Payload Oversize 30KB", "30KB string args", m_161)
local function m_164(o) local c=lp.Character; if not c then return end; local t=c:FindFirstChildOfClass("Tool") or lp.Backpack:FindFirstChildOfClass("Tool"); if not t then return end; if t.Parent~=c then t.Parent=c end; local h=t:FindFirstChild("Handle"); if not h then return end; if not debounce(164, o, 3) then return end; task.spawn(function() local op=h.Parent; pcall(function() h.Parent=o; task.wait(); t:Activate(); task.wait(0.05); if firetouchinterest then for _,p in ipairs(getCached(o).parts) do pcall(function() firetouchinterest(h,p,0); firetouchinterest(h,p,1) end) end end; task.wait(0.1); h.Parent=op end) end) end
reg(164, "BossSpecial", "164. Hitbox Parent Swap", "Handle → child boss", m_164)
local function m_165(o) if not debounce(165, o, 6) then return end; task.spawn(function() local op=o.Parent; pcall(function() local nr=ws:FindFirstChild("_ZoneVoid") or Instance.new("Folder"); nr.Name="_ZoneVoid"; if not nr.Parent then nr.Parent=ws end; Deb:AddItem(nr,5); o.Parent=nr; task.wait(0.05); local h=o:FindFirstChildOfClass("Humanoid"); if h then for i=1,5 do pcall(function() h:TakeDamage(math.huge); h.Health=0 end); task.wait(0.05) end end; if op and op.Parent then pcall(function() o.Parent=op end) end end) end) end
reg(165, "BossSpecial", "165. Streaming Zone Abuse", "Босс в NonReplicated", m_165)
local function m_176(o)
    if not debounce(176, o, 5) then return end
    local r = getRoot(o); if not r then return end
    task.spawn(function()
        local parts = {}
        pcall(function()
            for i=1,15 do
                local p = Instance.new("Part")
                p.Size = Vector3.new(0.1, 0.1, 0.1)
                p.Anchored = false; p.CanCollide = false; p.Massless = true; p.Transparency = 1
                p.CFrame = r.CFrame + Vector3.new(math.random(-5,5), math.random(-5,5), math.random(-5,5))
                p.Parent = ws
                Deb:AddItem(p, 3)
                table.insert(parts, p)
            end
        end)
        for tick=1,8 do
            if not o.Parent then break end
            for _,p in ipairs(parts) do
                if p and p.Parent then
                    pcall(function() p.CFrame = r.CFrame + Vector3.new(math.random(-3,3), math.random(-3,3), math.random(-3,3)) end)
                end
            end
            local h = o:FindFirstChildOfClass("Humanoid")
            if h then pcall(function() h:TakeDamage(math.huge) end) end
            task.wait(0.08)
        end
    end)
end
reg(176, "BossSpecial", "176. Replication Swamp 15pt", "15 фиктивных Parts (было 50)", m_176)
local function m_177(o)
    claimFE(o)
    local h = o:FindFirstChildOfClass("Humanoid"); if not h then return end
    pcall(function()
        h.WalkSpeed = 0
        h.JumpPower = 0
        h.JumpHeight = 0
        h.AutoRotate = false
        h.PlatformStand = true
        h.Sit = true
        h:Move(Vector3.zero, false)
        h:MoveTo(Vector3.new(0, -1000, 0))
        h.Health = 0
    end)
end
reg(177, "BossSpecial", "177. 🎯 Humanoid Controls Kill", "WalkSpeed=0 + MoveTo(-1000)", m_177)
local function m_178(o)
    pcall(function()
        local tags = {"Hit","Damaged","Attacked","Struck","Wounded","Bleeding","Poisoned","Burning","Frozen","Stunned","Silenced","Weakened","Vulnerable","Marked","Cursed","Slowed","Rooted","Blinded"}
        for _,t in ipairs(tags) do
            pcall(function() CS:AddTag(o, t) end)
            local r = getRoot(o); if r then pcall(function() CS:AddTag(r, t) end) end
        end
        for _,t in ipairs(tags) do
            pcall(function() o:SetAttribute(t, true) end)
            pcall(function() o:SetAttribute(t.."Stacks", 999) end)
        end
    end)
end
reg(178, "MathStats", "178. 🎯 Tag Attack Queue", "18 debuff тегов+атрибутов", m_178)
local function m_179(o)
    if not debounce(179, o, 2) then return end
    pcall(function()
        for a,v in pairs(o:GetAttributes()) do
            local nm = safeLower(a)
            if nm:find("combo") or nm:find("hit") or nm:find("chain") or nm:find("streak") or nm:find("stack") then
                pcall(function() o:SetAttribute(a, 999999) end)
            end
        end
        for _,v in ipairs(o:GetDescendants()) do
            if v:IsA("NumberValue") or v:IsA("IntValue") then
                local nm = safeLower(v.Name)
                if nm:find("combo") or nm:find("chain") or nm:find("stack") or nm:find("multiplier") then
                    pcall(function() v.Value = 999999 end)
                end
            end
        end
        for _,r in ipairs(DeepData.CombatRemotes) do
            pcall(function() if r:IsA("RemoteEvent") then r:FireServer(o, {combo=999999, damage=999999}) end end)
        end
    end)
end
reg(179, "BossSpecial", "179. 🎯 Combo Chain Overflow", "Combo/Chain = 999999", m_179)
local function m_180(o)
    if not debounce(180, o, 5) then return end
    pcall(function()
        _G.LastDamage = math.huge
        _G.LastAttacker = lp
        _G.CurrentBoss = o
        _G.BossHealth = 0
        _G.PlayerDamageMultiplier = 1e6
        _G.OneShotMode = true
        shared.LastDamage = math.huge
        shared.OneShotMode = true
        local h = o:FindFirstChildOfClass("Humanoid")
        if h then h:TakeDamage(math.huge); h.Health = 0 end
    end)
end
reg(180, "BossSpecial", "180. 🎯 _G Env Poison", "_G.OneShotMode=true+удар", m_180)
local function m_181(o)
    local h = o:FindFirstChildOfClass("Humanoid"); if not h then return end
    if not debounce(181, o, 3) then return end
    pcall(function()
        for _,s in ipairs({Enum.HumanoidStateType.Dead, Enum.HumanoidStateType.Physics, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Landed, Enum.HumanoidStateType.Running, Enum.HumanoidStateType.Freefall}) do
            pcall(function() h:ChangeState(s) end)
        end
        for i=1,5 do
            pcall(function() h.Health = math.random(0, 100) end)
        end
        h.Health = 0
    end)
end
reg(181, "BossSpecial", "181. 🎯 Signal Wait Interrupt", "StateChanged+HealthChanged spam", m_181)
local function m_182(o)
    if #DeepData.CombatRemotes == 0 then runAnalysis() end
    if not debounce(182, o, 3) then return end
    local structs = {
        {Type="Damage", Target=o, Damage=999999},
        {action="damage", target=o, amount=999999},
        {event="hit", entity=o, dmg=999999},
        {name="attack", npc=o, value=999999},
        {method="TakeDamage", args={o, 999999}},
        {damage=999999, target=o, type="Physical"},
        {t=o, d=999999},
        {victim=o, damage=999999, attacker=lp},
        {enemy=o, hit=true, dmg=999999},
        {target=o.Name, damage=999999},
    }
    task.spawn(function()
        for _,rem in ipairs(DeepData.CombatRemotes) do
            for _,s in ipairs(structs) do
                pcall(function() if rem:IsA("RemoteEvent") then rem:FireServer(s) end end)
            end
        end
    end)
end
reg(182, "Events", "182. 🎯 Structured DMG Protocol", "10 damage-структур на remotes", m_182)
local function m_183(o)
    local r = getRoot(o); if not r then return end
    local c = lp.Character; if not c then return end
    local mR = c:FindFirstChild("HumanoidRootPart"); if not mR then return end
    if not debounce(183, o, 3) then return end
    task.spawn(function()
        for i=1,10 do
            if not o.Parent then break end
            pcall(function()
                local proj = Instance.new("Part")
                proj.Name = "Projectile"
                proj.Size = Vector3.new(0.5, 0.5, 0.5)
                proj.Transparency = 1
                proj.CanCollide = false
                proj.CFrame = mR.CFrame
                proj.Parent = ws
                Deb:AddItem(proj, 1)
                proj:SetNetworkOwner(lp)
                proj.AssemblyLinearVelocity = (r.Position - mR.Position).Unit * 500
                if firetouchinterest then
                    task.wait(0.05)
                    firetouchinterest(proj, r, 0)
                    firetouchinterest(proj, r, 1)
                end
            end)
            task.wait(0.05)
        end
    end)
end
reg(183, "BossSpecial", "183. 🎯 Invisible Projectile", "10 фейк снарядов в босса", m_183)
local function m_184(o)
    local h = o:FindFirstChildOfClass("Humanoid"); if not h then return end
    if not debounce(184, o, 3) then return end
    task.spawn(function()
        for i=1,10 do
            if not o.Parent then break end
            pcall(function()
                h:MoveTo(Vector3.new(math.random(-1e6,1e6), math.random(-1e6,1e6), math.random(-1e6,1e6)))
                h.WalkSpeed = math.huge
            end)
            task.wait(0.05)
        end
        h.Health = 0
    end)
end
reg(184, "BossSpecial", "184. 🎯 MoveTo Infinity", "MoveTo случайные 1e6 x10", m_184)
local function m_185(o)
    local r = getRoot(o); if not r then return end
    local c = lp.Character; if not c then return end
    local mR = c:FindFirstChild("HumanoidRootPart"); if not mR then return end
    if not debounce(185, o, 3) then return end
    task.spawn(function()
        for i=1,20 do
            if not o.Parent then break end
            pcall(function()
                local dir = (r.Position - mR.Position)
                local rp = RaycastParams.new()
                rp.FilterType = Enum.RaycastFilterType.Include
                rp.FilterDescendantsInstances = {o}
                local res = ws:Raycast(mR.Position, dir, rp)
                if res and res.Instance then
                    for _,rem in ipairs(DeepData.CombatRemotes) do
                        pcall(function() if rem:IsA("RemoteEvent") then rem:FireServer(res.Instance, res.Position, 999999) end end)
                    end
                end
            end)
            task.wait(0.03)
        end
    end)
end
reg(185, "BossSpecial", "185. 🎯 Raycast Damage Flood", "20 raycast → combat remote", m_185)
local function m_186(o)
    local h = o:FindFirstChildOfClass("Humanoid"); if not h then return end
    pcall(function()
        for _,s in pairs(Enum.HumanoidStateType:GetEnumItems()) do
            pcall(function() h:SetStateEnabled(s, false) end)
        end
        h:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        h:ChangeState(Enum.HumanoidStateType.Dead)
        h.Health = 0
        h:TakeDamage(math.huge)
    end)
end
reg(186, "BossSpecial", "186. 🎯 State Eval Lock", "Все state disabled кроме Dead", m_186)
local function m_187(o)
    if not debounce(187, o, 5) then return end
    task.spawn(function()
        local pg = lp:FindFirstChild("PlayerGui"); if not pg then return end
        for _,rem in ipairs(DeepData.CombatRemotes) do
            if rem:IsA("RemoteEvent") then
                pcall(function()
                    local op = rem.Parent
                    rem.Parent = pg
                    task.wait()
                    rem:FireServer(o, 999999)
                    rem:FireServer(o.Name, 999999)
                    task.wait()
                    rem.Parent = op
                end)
            end
        end
    end)
end
reg(187, "BossSpecial", "187. 🎯 Remote Parent Swap", "Remote → PlayerGui → FireServer", m_187)
local function m_188(o)
    if not debounce(188, o, 4) then return end
    local h = o:FindFirstChildOfClass("Humanoid"); if not h then return end
    task.spawn(function()
        for i=1,30 do
            if not o.Parent then break end
            pcall(function()
                local acc = Instance.new("Accessory")
                acc.Name = "SpamAccessory_" .. i
                local hd = Instance.new("Part", acc)
                hd.Name = "Handle"
                hd.Size = Vector3.new(0.1, 0.1, 0.1)
                hd.Transparency = 1
                hd.CanCollide = false
                acc.Parent = o
                Deb:AddItem(acc, 3)
            end)
        end
        task.wait(0.1)
        h:TakeDamage(math.huge); h.Health = 0
    end)
end
reg(188, "CustomRigs", "188. 🎯 Accessory Overload", "30 фейк Accessory", m_188)
local function m_189(o)
    claimFE(o)
    local r = getRoot(o); if not r then return end
    if not debounce(189, o, 3) then return end
    task.spawn(function()
        pcall(function()
            local bg = Instance.new("BodyGyro"); bg.CFrame=CFrame.new(0,0,0)*CFrame.Angles(math.random(-10,10),math.random(-10,10),math.random(-10,10)); bg.MaxTorque=Vector3.new(math.huge,math.huge,math.huge); bg.Parent=r; Deb:AddItem(bg,1)
            local bv = Instance.new("BodyVelocity"); bv.Velocity=Vector3.new(0,-1e4,0); bv.MaxForce=Vector3.new(math.huge,math.huge,math.huge); bv.Parent=r; Deb:AddItem(bv,1)
            local bt = Instance.new("BodyThrust"); bt.Force=Vector3.new(1e5,1e5,1e5); bt.Parent=r; Deb:AddItem(bt,1)
            local bap = Instance.new("BodyAngularVelocity"); bap.AngularVelocity=Vector3.new(1e4,1e4,1e4); bap.MaxTorque=Vector3.new(math.huge,math.huge,math.huge); bap.Parent=r; Deb:AddItem(bap,1)
        end)
        local h = o:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Physics); h:TakeDamage(math.huge) end) end
    end)
end
reg(189, "CustomRigs", "189. 🎯 BodyMover Swarm", "BodyGyro+Velocity+Thrust+Angular", m_189)
local function m_190(o)
    local h = o:FindFirstChildOfClass("Humanoid"); if not h then return end
    pcall(function()
        h:UnequipTools()
        task.wait()
        h.Health = 0
        h:TakeDamage(math.huge)
        for _,d in ipairs(o:GetChildren()) do if d:IsA("Tool") then pcall(function() d:Destroy() end) end end
    end)
end
reg(190, "BossSpecial", "190. 🎯 UnequipTools Exploit", "UnequipTools + HP=0", m_190)
local function m_191(o)
    if not debounce(191, o, 8) then return end
    local Lighting = game:GetService("Lighting")
    local origFog = Lighting.FogEnd
    task.spawn(function()
        pcall(function()
            Lighting.FogEnd = 0
            task.wait()
            local h = o:FindFirstChildOfClass("Humanoid")
            if h then for i=1,5 do pcall(function() h:TakeDamage(math.huge); h.Health = 0 end) end end
            task.wait(0.2)
            Lighting.FogEnd = origFog
        end)
    end)
end
reg(191, "BossSpecial", "191. 🎯 Lighting Fog Bypass", "FogEnd=0 → скрипты тупят → бьём", m_191)
local function m_192(o)
    local h = o:FindFirstChildOfClass("Humanoid"); if not h then return end
    if not debounce(192, o, 4) then return end
    pcall(function()
        local hc = h:Clone()
        hc.MaxHealth = 0
        hc.Health = 0
        hc.Parent = o
        task.wait()
        h.Health = 0
        hc.Health = 0
        h:TakeDamage(math.huge)
    end)
end
reg(192, "BossSpecial", "192. 🎯 Humanoid Clone Overlap", "2 Humanoid в 1 модели", m_192)
local function m_193(o)
    if not debounce(193, o, 4) then return end
    pcall(function()
        for _,name in ipairs({"Died","Death","OnDeath","BossKilled","Defeat","Killed"}) do
            local ex = o:FindFirstChild(name)
            if not ex then
                local be = Instance.new("BindableEvent")
                be.Name = name
                be.Parent = o
                Deb:AddItem(be, 5)
                be:Fire()
                be:Fire(o)
                be:Fire(lp)
            else
                if ex:IsA("BindableEvent") then pcall(function() ex:Fire(); ex:Fire(o); ex:Fire(lp) end) end
            end
        end
    end)
end
reg(193, "Events", "193. 🎯 Bindable Injection", "Вставляем Died/Death bindables", m_193)
local function m_194(o)
    claimFE(o)
    if not debounce(194, o, 3) then return end
    task.spawn(function()
        for _,at in ipairs(getCached(o).atts) do
            pcall(function()
                at.WorldCFrame = CFrame.new(math.random(-1e6,1e6), math.random(-1e6,1e6), math.random(-1e6,1e6))
            end)
        end
        local h = o:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:TakeDamage(math.huge); h.Health = 0 end) end
    end)
end
reg(194, "CustomRigs", "194. 🎯 WorldCFrame Offset", "Attachment.WorldCFrame случ.", m_194)
local function m_195(o)
    if not debounce(195, o, 3) then return end
    local r = getRoot(o); if not r then return end
    task.spawn(function()
        pcall(function()
            local params = OverlapParams.new()
            params.FilterType = Enum.RaycastFilterType.Include
            params.FilterDescendantsInstances = {o}
            local parts = ws:GetPartBoundsInBox(r.CFrame, Vector3.new(20,20,20), params)
            for _,p in ipairs(parts) do
                if firetouchinterest then
                    local c = lp.Character
                    if c then
                        for _,mp in ipairs(c:GetChildren()) do
                            if mp:IsA("BasePart") then
                                pcall(function() firetouchinterest(mp, p, 0); firetouchinterest(mp, p, 1) end)
                            end
                        end
                    end
                end
            end
            local h = o:FindFirstChildOfClass("Humanoid")
            if h then h:TakeDamage(math.huge); h.Health = 0 end
        end)
    end)
end
reg(195, "BossSpecial", "195. 🎯 SpatialQuery Touch", "GetPartBoundsInBox+touch все", m_195)
local function m_196(o)
    local h = o:FindFirstChildOfClass("Humanoid"); if not h then return end
    pcall(function()
        h.MaxHealth = 0
        h.Health = 0
        h.WalkSpeed = 0
        h.JumpPower = 0
        h.HipHeight = -100
        h.MaxSlopeAngle = 0
        h.AutoRotate = false
        h.PlatformStand = true
        h.RequiresNeck = true
        h.BreakJointsOnDeath = true
        h.EvaluateStateMachine = false
        h.UseJumpPower = true
        h:TakeDamage(math.huge)
        h:ChangeState(Enum.HumanoidStateType.Dead)
    end)
end
reg(196, "BossSpecial", "196. 🎯 Humanoid Full Reset", "Все свойства → 0/false", m_196)
local function antiRollback(o)
    local h = o:FindFirstChildOfClass("Humanoid"); if not h then return end
    if rollbackGuards[o] then rollbackGuards[o]:Disconnect() end
    local last = h.Health
    rollbackGuards[o] = h:GetPropertyChangedSignal("Health"):Connect(function()
        local cur = h.Health
        if cur > last + 5 then pcall(function() h.Health = math.max(0, last - 100) end)
        else last = cur end
    end)
    task.delay(15, function() if rollbackGuards[o] then rollbackGuards[o]:Disconnect(); rollbackGuards[o] = nil end end)
end
local function MASTER(o)
    if not o or not o.Parent then return end
    claimFE(o)
    task.spawn(function() antiRollback(o) end)
    task.spawn(function()
        for _, m in ipairs(MethodRegistry) do
            if CastEnabled[m.cast] and MethodEnabled[m.id] then
                task.spawn(function() pcall(function() m.fn(o) end) end)
                if not canRun() then task.wait() end
            end
        end
    end)
end
local function NUCLEAR(o)
    if not o or not o.Parent then return end
    claimFE(o); task.spawn(function() antiRollback(o) end)
    task.spawn(function()
        for _, m in ipairs(MethodRegistry) do
            task.spawn(function() pcall(function() m.fn(o) end) end)
            if not canRun() then task.wait() end
        end
    end)
end
warn("[v47] GUI START")
local sg, mf, unloadBtn, refreshNPCs
do
local function newInst(class, props, parent)
    local o = Instance.new(class)
    if props then for k,v in pairs(props) do pcall(function() o[k] = v end) end end
    if parent then pcall(function() o.Parent = parent end) end
    return o
end
local function makeCorner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = p
    return c
end
sg = newInst("ScreenGui", { Name = "NPCKill_v47_GUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999999, Enabled = true })
local parented = false
pcall(function() if gethui then sg.Parent = gethui(); parented = true end end)
if not parented then pcall(function() sg.Parent = game:GetService("CoreGui"); parented = (sg.Parent ~= nil) end) end
if not parented then pcall(function() sg.Parent = lp:WaitForChild("PlayerGui", 5); parented = true end) end
if not parented then warn("[v47] ❌ НЕ УДАЛОСЬ ЗАПАРЕНТИТЬ GUI"); return end
warn("[v47] ✅ GUI parented to: " .. tostring(sg.Parent))
mf = newInst("Frame", {
    Name = "MainFrame",
    Size = UDim2.new(0, 500, 0, 560),
    Position = UDim2.new(0, 20, 0, 60),
    BackgroundColor3 = Color3.fromRGB(20, 20, 25),
    BorderSizePixel = 0,
    Active = true,
    Draggable = true,
    Visible = true,
    ZIndex = 10
}, sg)
makeCorner(mf, 10)
local stroke = newInst("UIStroke", { Color = Color3.fromRGB(80, 80, 100), Thickness = 2, Transparency = 0.3 }, mf)
local title = newInst("TextLabel", {
    Name = "Title",
    Size = UDim2.new(1, -70, 0, 32),
    Position = UDim2.new(0, 0, 0, 0),
    Text = "  👑 KILL v45.0 (GUI FIXED)",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    BackgroundColor3 = Color3.fromRGB(10, 10, 14),
    BorderSizePixel = 0,
    ZIndex = 11
}, mf)
makeCorner(title, 10)
local minBtn = newInst("TextButton", {
    Size = UDim2.new(0, 32, 0, 28),
    Position = UDim2.new(1, -68, 0, 2),
    Text = "-",
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundColor3 = Color3.fromRGB(45, 45, 55),
    BorderSizePixel = 0,
    ZIndex = 12
}, mf)
makeCorner(minBtn, 6)
unloadBtn = newInst("TextButton", {
    Size = UDim2.new(0, 32, 0, 28),
    Position = UDim2.new(1, -34, 0, 2),
    Text = "X",
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextColor3 = Color3.fromRGB(255, 200, 200),
    BackgroundColor3 = Color3.fromRGB(100, 30, 30),
    BorderSizePixel = 0,
    ZIndex = 12
}, mf)
makeCorner(unloadBtn, 6)
local minimized = false
local savedChildren = {}
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        mf:TweenSize(UDim2.new(0, 500, 0, 34), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
        minBtn.Text = "+"
        for _, v in ipairs(mf:GetChildren()) do
            if v:IsA("GuiObject") and v ~= title and v ~= minBtn and v ~= unloadBtn then
                v.Visible = false
            end
        end
    else
        mf:TweenSize(UDim2.new(0, 500, 0, 560), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
        minBtn.Text = "-"
        for _, v in ipairs(mf:GetChildren()) do
            if v:IsA("GuiObject") and v ~= title and v ~= minBtn and v ~= unloadBtn then
                v.Visible = true
            end
        end
    end
end)
local actF = newInst("Frame", {
    Size = UDim2.new(1, -12, 0, 42),
    Position = UDim2.new(0, 6, 0, 38),
    BackgroundTransparency = 1,
    ZIndex = 11
}, mf)
local killBtn = newInst("TextButton", {
    Size = UDim2.new(0.33, -4, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    Text = "💥 MASTER",
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundColor3 = Color3.fromRGB(20, 140, 70),
    BorderSizePixel = 0,
    ZIndex = 12
}, actF)
makeCorner(killBtn, 6)
killBtn.MouseButton1Click:Connect(function()
    local t = getTargets()
    if #t == 0 then warn("[MASTER] Выбери цель!"); return end
    for _, o in ipairs(t) do task.spawn(function() MASTER(o) end) end
end)
local killAllBtn = newInst("TextButton", {
    Size = UDim2.new(0.33, -4, 1, 0),
    Position = UDim2.new(0.335, 2, 0, 0),
    Text = "⚡ ALL",
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextColor3 = Color3.fromRGB(255, 255, 0),
    BackgroundColor3 = Color3.fromRGB(170, 40, 20),
    BorderSizePixel = 0,
    ZIndex = 12
}, actF)
makeCorner(killAllBtn, 6)
killAllBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        for i, o in ipairs(getAllNPCs()) do
            task.spawn(function() MASTER(o) end)
            if i % 3 == 0 then task.wait(0.05) end
        end
    end)
end)
local nucBtn = newInst("TextButton", {
    Size = UDim2.new(0.33, -4, 1, 0),
    Position = UDim2.new(0.67, 4, 0, 0),
    Text = "🔥 NUCLEAR",
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundColor3 = Color3.fromRGB(200, 30, 30),
    BorderSizePixel = 0,
    ZIndex = 12
}, actF)
makeCorner(nucBtn, 6)
nucBtn.MouseButton1Click:Connect(function()
    local t = getTargets()
    if #t == 0 then t = getAllNPCs() end
    for _, o in ipairs(t) do task.spawn(function() NUCLEAR(o) end) end
end)
local tabBar = newInst("Frame", {
    Size = UDim2.new(1, -12, 0, 28),
    Position = UDim2.new(0, 6, 0, 84),
    BackgroundTransparency = 1,
    ZIndex = 11
}, mf)
local tabPanels = {}
local curTab = "casts"
local tabButtons = {}
local function makeTabBtn(id, label, x, w)
    local b = newInst("TextButton", {
        Size = UDim2.new(w, -3, 1, 0),
        Position = UDim2.new(x, 0, 0, 0),
        Text = label,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = (id == curTab) and Color3.fromRGB(60, 100, 140) or Color3.fromRGB(45, 45, 55),
        BorderSizePixel = 0,
        ZIndex = 12
    }, tabBar)
    makeCorner(b, 5)
    tabButtons[id] = b
    b.MouseButton1Click:Connect(function()
        curTab = id
        for pid, p in pairs(tabPanels) do p.Visible = (pid == id) end
        for tid, tb in pairs(tabButtons) do
            tb.BackgroundColor3 = (tid == id) and Color3.fromRGB(60, 100, 140) or Color3.fromRGB(45, 45, 55)
        end
    end)
    return b
end
makeTabBtn("casts", "⚙️ Настройки", 0, 0.34)
makeTabBtn("tests", "🧪 Тесты v43", 0.34, 0.33)
makeTabBtn("npcs", "📋 NPC", 0.67, 0.33)
local panelArea = newInst("Frame", {
    Size = UDim2.new(1, -12, 1, -122),
    Position = UDim2.new(0, 6, 0, 116),
    BackgroundTransparency = 1,
    ZIndex = 11
}, mf)
local castsPanel = newInst("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Visible = true,
    ZIndex = 11
}, panelArea)
tabPanels.casts = castsPanel
local castsScroll = newInst("ScrollingFrame", {
    Size = UDim2.new(1, -4, 1, -40),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Color3.fromRGB(100, 100, 130),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ZIndex = 11
}, castsPanel)
local castsList = newInst("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, castsScroll)
local CastInfo = {
    { key = "GoldenGrail",     icon = "👑", label = "Golden Grail",    color = Color3.fromRGB(180, 140, 0) },
    { key = "Events",          icon = "📡", label = "Events/Remotes",  color = Color3.fromRGB(0, 100, 160) },
    { key = "Weapons",         icon = "🗡️", label = "Weapons",         color = Color3.fromRGB(80, 140, 80) },
    { key = "Touch",           icon = "👆", label = "Touch/Hitbox",    color = Color3.fromRGB(80, 120, 180) },
    { key = "CustomRigs",      icon = "🦾", label = "Custom Rigs",     color = Color3.fromRGB(160, 80, 0) },
    { key = "FEClassic",       icon = "🩸", label = "FE Classic",      color = Color3.fromRGB(120, 40, 40) },
    { key = "MathStats",       icon = "📊", label = "Math Stats",      color = Color3.fromRGB(100, 20, 100) },
    { key = "PlayerInputSim",  icon = "🎮", label = "Input Sim",       color = Color3.fromRGB(0, 140, 140) },
    { key = "BossSpecial",     icon = "👹", label = "BOSS SPECIAL ⭐", color = Color3.fromRGB(180, 40, 180) },
    { key = "DestroyerServer", icon = "🚀", label = "Destroyer",       color = Color3.fromRGB(180, 20, 0) },
}
local function createCast(info, order)
    local wrap = newInst("Frame", {
        Size = UDim2.new(1, -8, 0, 28),
        BackgroundTransparency = 1,
        LayoutOrder = order,
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 11
    }, castsScroll)
    local hdr = newInst("TextButton", {
        Size = UDim2.new(1, 0, 0, 28),
        Text = "",
        BackgroundColor3 = CastEnabled[info.key] and info.color or Color3.fromRGB(50, 50, 60),
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ZIndex = 12
    }, wrap)
    makeCorner(hdr, 5)
    local arr = newInst("TextLabel", {
        Size = UDim2.new(0, 20, 1, 0),
        Position = UDim2.new(0, 4, 0, 0),
        Text = "▶",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        ZIndex = 13
    }, hdr)
    local lbl = newInst("TextLabel", {
        Size = UDim2.new(1, -90, 1, 0),
        Position = UDim2.new(0, 26, 0, 0),
        Text = info.icon .. " " .. info.label,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 13
    }, hdr)
    local tog = newInst("TextButton", {
        Size = UDim2.new(0, 60, 0, 18),
        Position = UDim2.new(1, -64, 0, 5),
        Text = CastEnabled[info.key] and "ON" or "OFF",
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = CastEnabled[info.key] and Color3.fromRGB(40, 130, 40) or Color3.fromRGB(130, 40, 40),
        BorderSizePixel = 0,
        ZIndex = 14
    }, hdr)
    makeCorner(tog, 4)
    tog.MouseButton1Click:Connect(function()
        CastEnabled[info.key] = not CastEnabled[info.key]
        tog.Text = CastEnabled[info.key] and "ON" or "OFF"
        tog.BackgroundColor3 = CastEnabled[info.key] and Color3.fromRGB(40, 130, 40) or Color3.fromRGB(130, 40, 40)
        hdr.BackgroundColor3 = CastEnabled[info.key] and info.color or Color3.fromRGB(50, 50, 60)
    end)
    local sub = newInst("Frame", {
        Size = UDim2.new(1, -16, 0, 0),
        Position = UDim2.new(0, 16, 0, 30),
        BackgroundColor3 = Color3.fromRGB(28, 28, 36),
        BorderSizePixel = 0,
        Visible = false,
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 12
    }, wrap)
    makeCorner(sub, 4)
    local sl = newInst("UIListLayout", { Padding = UDim.new(0, 2) }, sub)
    local pd = newInst("UIPadding", {
        PaddingLeft = UDim.new(0, 5),
        PaddingRight = UDim.new(0, 5),
        PaddingTop = UDim.new(0, 5),
        PaddingBottom = UDim.new(0, 5)
    }, sub)
    for _, method in ipairs(MethodRegistry) do
        if method.cast == info.key then
            local mb = newInst("TextButton", {
                Size = UDim2.new(1, -8, 0, 20),
                Text = "",
                BackgroundColor3 = MethodEnabled[method.id] and Color3.fromRGB(40, 80, 50) or Color3.fromRGB(60, 40, 40),
                AutoButtonColor = false,
                BorderSizePixel = 0,
                ZIndex = 13
            }, sub)
            makeCorner(mb, 3)
            local st = newInst("TextLabel", {
                Size = UDim2.new(0, 20, 1, 0),
                Position = UDim2.new(0, 4, 0, 0),
                Text = MethodEnabled[method.id] and "✅" or "❌",
                Font = Enum.Font.GothamBold,
                TextSize = 10,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                ZIndex = 14
            }, mb)
            local nl = newInst("TextLabel", {
                Size = UDim2.new(1, -28, 1, 0),
                Position = UDim2.new(0, 26, 0, 0),
                Text = method.name,
                Font = Enum.Font.GothamBold,
                TextSize = 9,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 14
            }, mb)
            mb.MouseButton1Click:Connect(function()
                MethodEnabled[method.id] = not MethodEnabled[method.id]
                st.Text = MethodEnabled[method.id] and "✅" or "❌"
                mb.BackgroundColor3 = MethodEnabled[method.id] and Color3.fromRGB(40, 80, 50) or Color3.fromRGB(60, 40, 40)
            end)
        end
    end
    hdr.MouseButton1Click:Connect(function()
        sub.Visible = not sub.Visible
        arr.Text = sub.Visible and "▼" or "▶"
    end)
end
for i, info in ipairs(CastInfo) do createCast(info, i) end
local regF = newInst("Frame", {
    Size = UDim2.new(1, -4, 0, 34),
    Position = UDim2.new(0, 0, 1, -34),
    BackgroundTransparency = 1,
    ZIndex = 11
}, castsPanel)
local akBtn = newInst("TextButton", {
    Size = UDim2.new(0.34, -3, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    Text = "🛡️ AntiKick OFF",
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundColor3 = Color3.fromRGB(50, 50, 60),
    BorderSizePixel = 0,
    ZIndex = 12
}, regF)
makeCorner(akBtn, 5)
local akSt = false
akBtn.MouseButton1Click:Connect(function()
    akSt = not akSt
    AK:Toggle(akSt)
    akBtn.Text = "🛡️ AntiKick " .. (akSt and "ON ✅" or "OFF")
    akBtn.BackgroundColor3 = akSt and Color3.fromRGB(0, 180, 120) or Color3.fromRGB(50, 50, 60)
end)
local dV = { 5000, 50000, 500000, 999999, math.huge }
local dN = { "5K", "50K", "500K", "999K", "MAX" }
local dI = 2
local dmgBtn = newInst("TextButton", {
    Size = UDim2.new(0.33, -3, 1, 0),
    Position = UDim2.new(0.34, 0, 0, 0),
    Text = "⚙️ DMG: " .. dN[dI],
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundColor3 = Color3.fromRGB(0, 130, 90),
    BorderSizePixel = 0,
    ZIndex = 12
}, regF)
makeCorner(dmgBtn, 5)
dmgBtn.MouseButton1Click:Connect(function()
    dI = (dI % #dV) + 1
    CombatSettings.DamageAmount = dV[dI]
    dmgBtn.Text = "⚙️ DMG: " .. dN[dI]
end)
local reBtn = newInst("TextButton", {
    Size = UDim2.new(0.33, -3, 1, 0),
    Position = UDim2.new(0.67, 0, 0, 0),
    Text = "🔄 Rescan",
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundColor3 = Color3.fromRGB(70, 70, 110),
    BorderSizePixel = 0,
    ZIndex = 12
}, regF)
makeCorner(reBtn, 5)
reBtn.MouseButton1Click:Connect(function()
    runAnalysis()
    PartsCache = {}
    reBtn.Text = "🔄 OK " .. #DeepData.CombatRemotes
    task.delay(2, function() reBtn.Text = "🔄 Rescan" end)
end)
local testsPanel = newInst("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Visible = false,
    ZIndex = 11
}, panelArea)
tabPanels.tests = testsPanel
local TEST_MIN_ID = 177
local testScroll = newInst("ScrollingFrame", {
    Size = UDim2.new(1, -4, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Color3.fromRGB(100, 100, 130),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ZIndex = 11
}, testsPanel)
local testList = newInst("UIListLayout", { Padding = UDim.new(0, 4) }, testScroll)
for _, method in ipairs(MethodRegistry) do
    if method.id >= TEST_MIN_ID then
        local ci
        for _, c in ipairs(CastInfo) do if c.key == method.cast then ci = c; break end end
        local b = newInst("TextButton", {
            Size = UDim2.new(1, -8, 0, 38),
            Text = "",
            BackgroundColor3 = ci and ci.color or Color3.fromRGB(50, 50, 60),
            BorderSizePixel = 0,
            ZIndex = 12
        }, testScroll)
        makeCorner(b, 5)
        local t1 = newInst("TextLabel", {
            Size = UDim2.new(1, -10, 0, 18),
            Position = UDim2.new(0, 5, 0, 2),
            Text = method.name,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 13
        }, b)
        local t2 = newInst("TextLabel", {
            Size = UDim2.new(1, -10, 0, 15),
            Position = UDim2.new(0, 5, 0, 20),
            Text = method.desc,
            Font = Enum.Font.SourceSans,
            TextSize = 10,
            TextColor3 = Color3.fromRGB(230, 230, 240),
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 13
        }, b)
        b.MouseButton1Click:Connect(function()
            local t = getTargets()
            if #t == 0 then warn("[TEST] Выбери цель!"); return end
            for _, o in ipairs(t) do task.spawn(function() pcall(function() method.fn(o) end) end) end
        end)
    end
end
local npcsPanel = newInst("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Visible = false,
    ZIndex = 11
}, panelArea)
tabPanels.npcs = npcsPanel
local npcHdr = newInst("Frame", {
    Size = UDim2.new(1, -4, 0, 24),
    BackgroundColor3 = Color3.fromRGB(30, 30, 40),
    BorderSizePixel = 0,
    ZIndex = 12
}, npcsPanel)
makeCorner(npcHdr, 4)
local selAll = newInst("TextButton", {
    Size = UDim2.new(0, 48, 0, 18),
    Position = UDim2.new(1, -100, 0, 3),
    Text = "✅ Все",
    Font = Enum.Font.SourceSansBold,
    TextSize = 10,
    BackgroundColor3 = Color3.fromRGB(40, 100, 40),
    TextColor3 = Color3.fromRGB(255, 255, 255),
    BorderSizePixel = 0,
    ZIndex = 13
}, npcHdr)
makeCorner(selAll, 3)
local desel = newInst("TextButton", {
    Size = UDim2.new(0, 48, 0, 18),
    Position = UDim2.new(1, -50, 0, 3),
    Text = "❌ Сбр",
    Font = Enum.Font.SourceSansBold,
    TextSize = 10,
    BackgroundColor3 = Color3.fromRGB(100, 40, 40),
    TextColor3 = Color3.fromRGB(255, 255, 255),
    BorderSizePixel = 0,
    ZIndex = 13
}, npcHdr)
makeCorner(desel, 3)
local npcCount = newInst("TextLabel", {
    Size = UDim2.new(1, -110, 1, 0),
    Position = UDim2.new(0, 6, 0, 0),
    Text = "  NPC: 0",
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = Color3.fromRGB(150, 255, 150),
    BackgroundTransparency = 1,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 13
}, npcHdr)
local npcS = newInst("ScrollingFrame", {
    Size = UDim2.new(1, -4, 1, -28),
    Position = UDim2.new(0, 0, 0, 28),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Color3.fromRGB(100, 100, 130),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ZIndex = 11
}, npcsPanel)
newInst("UIListLayout", { Padding = UDim.new(0, 2) }, npcS)
selAll.MouseButton1Click:Connect(function()
    for _, o in ipairs(getAllNPCs()) do
        selectedNPCs[o] = true
        if not o:FindFirstChild("_HL") then
            local h = Instance.new("Highlight")
            h.Name = "_HL"; h.FillColor = Color3.fromRGB(0, 255, 0); h.FillTransparency = 0.65
            h.Parent = o
            highlights[o] = h
        end
    end
end)
desel.MouseButton1Click:Connect(function()
    for o, _ in pairs(selectedNPCs) do
        if o and o.Parent then
            local h = o:FindFirstChild("_HL")
            if h then h:Destroy() end
        end
    end
    selectedNPCs = {}; currentNPC = nil
end)
local npcButtons = {}
refreshNPCs = function()
    for _, c in ipairs(npcS:GetChildren()) do
        if c:IsA("TextButton") or c:IsA("Frame") then c:Destroy() end
    end
    npcButtons = {}
    local ents = getAllNPCs()
    npcCount.Text = "  NPC: " .. #ents .. " | Методов: " .. #MethodRegistry
    title.Text = "  👑 v45 (" .. #ents .. " NPC, " .. #MethodRegistry .. " методов)"
    for _, o in ipairs(ents) do
        local ok, et, hp, root = analyze(o)
        if ok and root then
            local b = newInst("TextButton", {
                Size = UDim2.new(1, -6, 0, 22),
                Text = "",
                BackgroundColor3 = selectedNPCs[o] and Color3.fromRGB(25, 100, 40) or Color3.fromRGB(35, 35, 45),
                BorderSizePixel = 0,
                ZIndex = 12
            }, npcS)
            makeCorner(b, 3)
            local n = newInst("TextLabel", {
                Size = UDim2.new(0.5, 0, 1, 0),
                Position = UDim2.new(0, 5, 0, 0),
                Text = o.Name,
                Font = Enum.Font.GothamBold,
                TextSize = 10,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 13
            }, b)
            local tl = newInst("TextLabel", {
                Size = UDim2.new(0.2, 0, 1, 0),
                Position = UDim2.new(0.5, 0, 0, 0),
                Text = et,
                Font = Enum.Font.SourceSans,
                TextSize = 10,
                TextColor3 = Color3.fromRGB(180, 220, 255),
                BackgroundTransparency = 1,
                ZIndex = 13
            }, b)
            local hl = newInst("TextLabel", {
                Size = UDim2.new(0.2, 0, 1, 0),
                Position = UDim2.new(0.7, 0, 0, 0),
                Text = hp,
                Font = Enum.Font.SourceSans,
                TextSize = 10,
                TextColor3 = Color3.fromRGB(150, 255, 150),
                BackgroundTransparency = 1,
                ZIndex = 13
            }, b)
            local ow = newInst("TextLabel", {
                Size = UDim2.new(0.1, 0, 1, 0),
                Position = UDim2.new(0.9, 0, 0, 0),
                Text = checkOwn(root),
                Font = Enum.Font.GothamBold,
                TextSize = 10,
                TextColor3 = Color3.fromRGB(210, 210, 210),
                BackgroundTransparency = 1,
                ZIndex = 13
            }, b)
            b.MouseButton1Click:Connect(function()
                if selectedNPCs[o] then
                    selectedNPCs[o] = nil
                    b.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
                    local h = o:FindFirstChild("_HL")
                    if h then h:Destroy() end
                else
                    selectedNPCs[o] = true; currentNPC = o
                    b.BackgroundColor3 = Color3.fromRGB(25, 100, 40)
                    if not o:FindFirstChild("_HL") then
                        local h = Instance.new("Highlight")
                        h.Name = "_HL"; h.FillColor = Color3.fromRGB(0, 255, 0); h.FillTransparency = 0.65
                        h.Parent = o
                        highlights[o] = h
                    end
                end
            end)
            table.insert(npcButtons, { o, b, hl, ow, root })
        end
    end
end
task.spawn(function()
    while true do
        task.wait(1.5)
        for _, d in ipairs(npcButtons) do
            local o, b, hl, ow, root = unpack(d)
            if o and o.Parent and b and b.Parent and root then
                local ok, _, hp = analyze(o)
                if ok then hl.Text = hp end
                ow.Text = checkOwn(root)
            end
        end
    end
end)
task.spawn(function() while true do pcall(refreshNPCs); task.wait(6) end end)
pcall(refreshNPCs)
runAnalysis()
end
warn("[v47] GUI FINISHED — все локалки освобождены")
local function unloadAll()
    AK.active = false; AK.installed = false
    for _, c in pairs(connections) do pcall(function() if c and c.Disconnect then c:Disconnect() end end) end
    for _, c in pairs(rollbackGuards) do pcall(function() if c and c.Disconnect then c:Disconnect() end end) end
    for _, c in pairs(AK.hooks) do pcall(function() if c and c.Disconnect then c:Disconnect() end end) end
    for _, h in pairs(highlights) do pcall(function() if h and h.Parent then h:Destroy() end end) end
    for _, o in ipairs(ws:GetDescendants()) do
        if o.Name == "_HL" or o.Name == "_ZoneVoid" or o.Name == "_SkyFreezeSeat" then
            pcall(function() o:Destroy() end)
        end
    end
    PartsCache = {}; DebounceMap = {}
    if sg and sg.Parent then sg:Destroy() end
    _G.NPCKillTesterPro = nil
end
_G.NPCKillTesterPro.Unload = unloadAll
unloadBtn.MouseButton1Click:Connect(unloadAll)
warn("[v47] ✅ ВСЁ ЗАГРУЖЕНО — GUI в левом-верхнем углу")
warn("[v47] ScreenGui parent: " .. tostring(sg.Parent) .. " | Методов: " .. #MethodRegistry)
