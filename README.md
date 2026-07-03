-- ============================================================================
-- NPC KILL TESTER PRO v42.0 — 10 БОЛЬШЕ МЕТОДОВ ДЛЯ ПРОВЕРКИ (№167-176)
--
-- 📦 ЧТО СДЕЛАНО В v42.0:
--   ✅ Добавлены 10 новых методов №167-176 с продвинутыми векторами
--   ✅ В тестах теперь ВСЕ непроверенные (id>=157): 20 методов
--   ✅ Оптимизация из v41 сохранена (throttling, кэши, компактный GUI)
--
-- 🎯 НОВЫЕ 10 (v42):
--   167. 🎯 HealthDisplay Corrupt   — эксплойт HealthDisplayDistance=-1
--   168. 🎯 Animator Eval Poison    — свой Animator + 50 невалидных tracks
--   169. 🎯 Humanoid Parent Flip    — Humanoid.Parent=nil на 1 кадр
--   170. 🎯 Camera Subject Hijack   — cam.CameraSubject=boss.Humanoid
--   171. 🎯 Velocity Knockback OF   — осцилляция velocity через Heartbeat
--   172. 🎯 PP Recursive 500x       — 500 fireproximityprompt пачками
--   173. 🎯 Died Manual Fire        — getconnections(Died)+ручной вызов
--   174. 🎯 Tool Grip Overshoot     — Grip CFrame -distance до NPC
--   175. 🎯 BuildRig Exploit        — испорченный BuildRigFromAttachments
--   176. 🎯 Replication Swamp 50pt  — 50 фиктивных Parts→перегруз
--
-- ============================================================================
-- 📦 ЧТО БЫЛО В v41.0:
-- NPC KILL TESTER PRO v41.0 — OPTIMIZED + COMPACT UI + ADVANCED BOSS-PIERCE
--
-- 🚀 ОПТИМИЗАЦИЯ (без потери силы):
--   ✅ Убраны tight-loops (task.wait(0.01)) → все ≥ 0.04
--   ✅ Кэш parts/motors/attachments (не GetDescendants в цикле)
--   ✅ Throttling: тяжёлые методы не чаще 1 раз за 0.5с
--   ✅ Batching: MASTER группирует методы по «дешёвости» и параллелит
--   ✅ Таблица NPC обновляется 1 раз/сек вместо 2 раз/сек
--   ✅ Highlight создаётся один раз, переиспользуется
--   ✅ Убраны excessive prints (только критичные)
--
-- 📱 КОМПАКТНЫЙ GUI:
--   Было: 820×920 (~80% экрана)
--   Стало: 480×540 (~35% экрана) + горизонтальные вкладки
--
-- 🎯 10 НОВЫХ МЕТОДОВ С ПРОДВИНУТЫМ ПОДХОДОМ (№157-166):
--   157. 🎯 SERVER-AUTHORITY BYPASS — эксплойт FilteringEnabled через
--        физику при NetworkOwnership + микропулинг ownership queue
--   158. 🎯 REMOTE ARGUMENT MUTATION — не тупой fuzzing, а ПОДСМАТРИВАЕМ
--        как игра сама шлёт remote и мутируем реальный аргумент
--   159. 🎯 HUMANOID SUBTYPE COERCION — принудительная смена HumanoidType
--        на R6 когда босс R15 → полный сбой rig и анимаций
--   160. 🎯 CHARACTER PROPERTY MIRROR — временно ставим босса как
--        LocalPlayer.Character (сервер обрабатывает нас как босса)
--   161. 🎯 REMOTE PAYLOAD OVERSIZE — 100000-байтная строка в args
--        → сервер должен парсить = таймаут ivar handler
--   162. 🎯 PHYSICS PIPELINE HIJACK — AlignPosition+AlignOrient на HRP
--        c бесконечной силой → сервер не может валидировать поз.
--   163. 🎯 EVENT REPLAY WITHOUT INPUT — крадём сигнатуру последнего
--        боевого события у ДРУГОГО игрока и файрим как своё
--   164. 🎯 HITBOX PARENT SWAP — временно ставим наш Handle как child
--        босса → урон читается как self-damage боссом
--   165. 🎯 STREAMING ZONE ABUSE — если игра юзает StreamingEnabled,
--        forсим boss в NonReplicated zone → сервер думает что несуществует
--   166. 🎯 REMOTE INVOKE RECURSION — RemoteFunction:InvokeServer
--        внутри InvokeServer x100 → переполнение handler stack
-- ============================================================================

if _G.NPCKillTesterPro and _G.NPCKillTesterPro.Unload then
    _G.NPCKillTesterPro.Unload()
    task.wait(0.3)
end

_G.NPCKillTesterPro = {}

local rs = game:GetService("RunService")
local ws = game:GetService("Workspace")
local plrs = game:GetService("Players")
local rep = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local PhysicsService = game:GetService("PhysicsService")
local lp = plrs.LocalPlayer
local mouse = lp:GetMouse()
local cam = ws.CurrentCamera

local selectedNPCs = {}
local currentNPC = nil
local connections = {}
local highlights = {}
local rollbackGuards = {}

-- 🚀 ОПТИМИЗАЦИЯ: throttle-cache для тяжёлых методов
local ThrottleCache = {}  -- [methodId..objName] = lastTime
local function throttled(id, obj, cooldown)
    local key = tostring(id) .. "_" .. tostring(obj)
    local now = tick()
    if ThrottleCache[key] and (now - ThrottleCache[key]) < cooldown then return false end
    ThrottleCache[key] = now
    return true
end

-- 🚀 ОПТИМИЗАЦИЯ: кэш parts/motors для NPC (обновляется 1 раз в 5 сек)
local PartsCache = {}  -- [obj] = {parts={}, motors={}, atts={}, bones={}, lastUpdate=t}
local function getCached(obj)
    local c = PartsCache[obj]
    if c and (tick() - c.lastUpdate) < 5 then return c end
    c = {parts={}, motors={}, atts={}, bones={}, welds={}, lastUpdate=tick()}
    for _,d in ipairs(obj:GetDescendants()) do
        if d:IsA("BasePart") then table.insert(c.parts, d)
        elseif d:IsA("Motor6D") then table.insert(c.motors, d); table.insert(c.welds, d)
        elseif d:IsA("Weld") then table.insert(c.welds, d)
        elseif d:IsA("Attachment") then table.insert(c.atts, d)
        elseif d:IsA("Bone") then table.insert(c.bones, d) end
    end
    PartsCache[obj] = c
    return c
end

local CastEnabled = {
    GoldenGrail = true, RemotesWeapons = true, CustomRigs = true,
    FEClassic = true, MathStats = true, DestroyerServer = false, PlayerInputSim = true,
}
local MethodEnabled = {}
local CombatSettings = { DamageAmount = 50000, HyperSpeed = false }
local DeepAnalysisData = { CombatRemotes = {}, WeaponRemotes = {}, AbilityRemotes = {} }
local RecordedRemoteCalls = {}  -- для №158, №163

local MethodRegistry = {}
local function registerMethod(id, cast, name, desc, fn, defaultEnabled)
    MethodEnabled[id] = defaultEnabled ~= false
    table.insert(MethodRegistry, {id=id, cast=cast, name=name, desc=desc, fn=fn})
end

-- ==================== АНАЛИЗАТОР (оптимизирован) ====================
local function indexObject(obj)
    if not obj then return end
    pcall(function()
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local nm = string.lower(obj.Name)
            local fnm = obj.Parent and string.lower(obj.Parent.Name) or ""
            if not (string.find(nm,"ban") or string.find(nm,"kick") or string.find(nm,"anticheat") or string.find(nm,"log") or string.find(nm,"report") or string.find(nm,"detect") or string.find(fnm,"anticheat")) then
                if string.find(nm,"attack") or string.find(nm,"damage") or string.find(nm,"hit") or string.find(nm,"combat") or string.find(nm,"kill") or string.find(nm,"strike") or string.find(fnm,"remote") then
                    if not table.find(DeepAnalysisData.CombatRemotes, obj) then table.insert(DeepAnalysisData.CombatRemotes, obj) end
                end
            end
        end
        if obj:IsA("Tool") then
            for _,rem in ipairs(obj:GetDescendants()) do
                if (rem:IsA("RemoteEvent") or rem:IsA("RemoteFunction")) and not table.find(DeepAnalysisData.WeaponRemotes, rem) then
                    table.insert(DeepAnalysisData.WeaponRemotes, rem)
                end
            end
        end
    end)
end
local function runFullAnalysis()
    DeepAnalysisData = { CombatRemotes = {}, WeaponRemotes = {}, AbilityRemotes = {} }
    for _,o in ipairs(rep:GetDescendants()) do indexObject(o) end
    for _,o in ipairs(ws:GetDescendants()) do indexObject(o) end
    for _,p in ipairs(plrs:GetPlayers()) do local bp = p:FindFirstChild("Backpack"); if bp then for _,o in ipairs(bp:GetDescendants()) do indexObject(o) end end end
    print("[🤖 v41 ANALYZER] Combat:", #DeepAnalysisData.CombatRemotes, "| Weapon:", #DeepAnalysisData.WeaponRemotes)
end
ws.DescendantAdded:Connect(indexObject); rep.DescendantAdded:Connect(indexObject)

-- ==================== БАЗОВЫЕ УТИЛИТЫ ====================
local function getRootPart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso") or obj:FindFirstChild("UpperTorso") or obj:FindFirstChild("Root") or obj:FindFirstChild("Body") or obj:FindFirstChild("Main") or obj:FindFirstChild("Hitbox") or obj:FindFirstChild("Head") or obj:FindFirstChildOfClass("BasePart")
    end
    return nil
end

local function isNPC(model)
    if not model or not model:IsA("Model") then return false end
    if model == lp.Character then return false end
    if plrs:GetPlayerFromCharacter(model) ~= nil then return false end
    local pc = 0
    for _, c in ipairs(model:GetChildren()) do if c:IsA("BasePart") then pc = pc + 1 end end
    if pc > 350 then return false end
    if model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController") then return true end
    if model:FindFirstChildOfClass("Bone", true) then return true end
    if model:FindFirstChild("Health", true) or model:GetAttribute("Health") or model:GetAttribute("Boss") then return true end
    for _, d in ipairs(model:GetDescendants()) do if d:IsA("Motor6D") or d:IsA("BallSocketConstraint") then return true end end
    return false
end

local function getAllNPCs()
    local raw = {}
    for _, obj in ipairs(ws:GetDescendants()) do
        if obj:IsA("Model") and obj ~= lp.Character and not plrs:GetPlayerFromCharacter(obj) then
            if isNPC(obj) then table.insert(raw, obj) end
        end
    end
    local final = {}
    for _, c in ipairs(raw) do
        local isChild = false
        for _, o in ipairs(raw) do if c ~= o and o:IsDescendantOf(c) then isChild = true; break end end
        if not isChild then table.insert(final, c) end
    end
    return final
end

local function analyzeEntity(obj)
    local root = getRootPart(obj); if not root then return false, nil, nil, nil end
    local hum = obj:FindFirstChildOfClass("Humanoid")
    local valHP = obj:FindFirstChild("Health", true)
    local attrHP = obj:GetAttribute("Health") or obj:GetAttribute("HP")
    local nm = string.lower(obj.Name)
    local isBoss = string.find(nm,"boss") or string.find(nm,"killer")
    local et, hp = "NPC", "N/A"
    if hum then
        et = isBoss and "👑Boss" or "🚶Hum"
        hp = math.floor(hum.Health).."/"..math.floor(hum.MaxHealth)
    elseif valHP then et = "🦾Custom"; hp = tostring(valHP.Value)
    elseif attrHP then et = "📊Attr"; hp = tostring(attrHP)
    else et = "🦾Rig"; hp = "?" end
    return true, et, hp, root
end

local function checkOwner(p)
    if not p or not p:IsA("BasePart") then return "-" end
    if p.Anchored then return "⚓" end
    local ok, o = pcall(function() return p:IsNetworkOwner() end)
    return (ok and o) and "✅" or "🌐"
end

local function getTargets()
    local t = {}
    for obj,_ in pairs(selectedNPCs) do if obj and obj.Parent then table.insert(t, obj) else selectedNPCs[obj]=nil end end
    if #t == 0 and currentNPC and currentNPC.Parent then table.insert(t, currentNPC) end
    return t
end

local function claimFE(obj)
    if not throttled("claimFE", obj, 0.5) then return end
    pcall(function()
        if sethiddenproperty then sethiddenproperty(lp, "SimulationRadius", 1e10) end
        local c = getCached(obj)
        for _,p in ipairs(c.parts) do
            if not p.Anchored then pcall(function() p:SetNetworkOwner(lp) end) end
        end
    end)
end

-- ==================== 🛡️ ANTI-KICK PRO ====================
local AntiKickPro = { installed = false, active = false, hooks = {} }
function AntiKickPro:Install()
    if self.installed then return end
    self.installed = true; self.active = true
    pcall(function() if hookmetamethod then local old; old = hookmetamethod(game, "__namecall", function(s, ...) local m = getnamecallmethod and getnamecallmethod() or ""; if (m=="Kick" or m=="kick") and (s==lp or (typeof(s)=="Instance" and s:IsA("Player"))) then if AntiKickPro.active then return nil end end; return old(s, ...) end) end end)
    pcall(function() local mt = getrawmetatable and getrawmetatable(lp) or nil; if mt and setreadonly then setreadonly(mt, false); local o = mt.__index; mt.__index = newcclosure and newcclosure(function(s, k) if k=="Kick" and s==lp and AntiKickPro.active then return function() end end; return o(s, k) end) or function(s, k) if k=="Kick" and s==lp and AntiKickPro.active then return function() end end; return o(s, k) end; setreadonly(mt, true) end end)
    pcall(function() for _,r in ipairs(rep:GetDescendants()) do if r:IsA("RemoteEvent") then local nm = string.lower(r.Name); if string.find(nm,"kick") or string.find(nm,"ban") or string.find(nm,"anticheat") then table.insert(AntiKickPro.hooks, r.OnClientEvent:Connect(function() end)) end end end end)
    pcall(function() local function px(c) if not c then return end; local h = c:WaitForChild("Humanoid", 5); if h then pcall(function() h.BreakJointsOnDeath=false; h.MaxHealth=math.huge; h.Health=math.huge; table.insert(AntiKickPro.hooks, h.HealthChanged:Connect(function(nh) if AntiKickPro.active and nh < h.MaxHealth*0.5 then pcall(function() h.Health=h.MaxHealth end) end end)) end) end end; px(lp.Character); connections["akChar"] = lp.CharacterAdded:Connect(px) end)
    task.spawn(function() while AntiKickPro.active do pcall(function() local c=lp.Character; if c then local h=c:FindFirstChildOfClass("Humanoid"); if h and h.Health<h.MaxHealth*0.7 then h.Health=h.MaxHealth end; if not c:FindFirstChildOfClass("ForceField") then local ff=Instance.new("ForceField"); ff.Visible=false; ff.Parent=c; game:GetService("Debris"):AddItem(ff,5) end end end); task.wait(0.5) end end)
    print("[🛡️ Anti-Kick PRO] Все 5 слоёв установлены!")
end
function AntiKickPro:Toggle(s) self.active = s; if s and not self.installed then self:Install() end end

-- ==================== БОЕВЫЕ МЕТОДЫ (компактные, оптимизированные) ====================

-- 🩸 FE CLASSIC
local function m_1(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h.Health=0; h:TakeDamage(999999) end) end end
registerMethod(1, "FEClassic", "1. Simple HP=0", "Humanoid.Health=0", m_1)
local function m_2(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Dead); h.PlatformStand=true end) end end
registerMethod(2, "FEClassic", "2. Ragdoll Dead", "ChangeState(Dead)", m_2)
local function m_3(o) claimFE(o); if not throttled(3, o, 0.5) then return end; task.spawn(function() for i=1,10 do if not o.Parent then break end; pcall(function() if o.BreakJoints then o:BreakJoints() end end); local c=getCached(o); for _,v in ipairs(c.welds) do pcall(function() v:Destroy() end) end; task.wait(0.05) end end) end
registerMethod(3, "FEClassic", "3. Break Joints Loop", "BreakJoints x10 (throttled)", m_3)
local function m_5(o) claimFE(o); for _,p in ipairs(getCached(o).parts) do if p.Name=="Head" or p.Name=="Torso" then pcall(function() for _,w in ipairs(p:GetChildren()) do if w:IsA("Motor6D") or w:IsA("Weld") then w:Destroy() end end; p.AssemblyLinearVelocity=Vector3.new(0,50000,0) end) end end end
registerMethod(5, "FEClassic", "5. Decapitate", "Отрыв Head/Torso", m_5)
local function m_6(o) claimFE(o); local r=getRootPart(o); if not r then return end; pcall(function() local e=Instance.new("Explosion"); e.Position=r.Position; e.BlastRadius=35; e.BlastPressure=0; e.ExplosionType=Enum.ExplosionType.NoCraters; e.Parent=ws end) end
registerMethod(6, "FEClassic", "6. Safe Explosion", "Explosion DestroyJoint=0", m_6)
local function m_92(o) local h=o:FindFirstChildOfClass("Humanoid"); local r=getRootPart(o); if not h or not r then return end; if not throttled(92, o, 3) then return end; task.spawn(function() local s=Instance.new("Seat"); s.Transparency=1; s.CanCollide=false; s.CFrame=r.CFrame; s.Parent=ws; pcall(function() s:Sit(h) end); task.wait(0.08); pcall(function() s.CFrame=CFrame.new(r.Position.X,2000,r.Position.Z); s.Anchored=true; if o.BreakJoints then o:BreakJoints() end end); game:GetService("Debris"):AddItem(s,10) end) end
registerMethod(92, "FEClassic", "92. Seat Sky Freeze", "Посадить в Seat → Y=2000", m_92)
local function m_117(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); if not h then return end; pcall(function() for _,s in pairs(Enum.HumanoidStateType:GetEnumItems()) do if s~=Enum.HumanoidStateType.Dead then pcall(function() h:SetStateEnabled(s,false) end) end end; h:ChangeState(Enum.HumanoidStateType.Dead); h.MaxHealth=0; h.Health=0 end) end
registerMethod(117, "FEClassic", "117. State Flood", "Все death states", m_117)
local function m_119(o) claimFE(o); pcall(function() for _,ff in ipairs(o:GetDescendants()) do if ff:IsA("ForceField") then ff:Destroy() end end; local r=getRootPart(o); if r then for i=1,3 do local e=Instance.new("Explosion"); e.Position=r.Position; e.BlastRadius=50; e.BlastPressure=0; e.DestroyJointRadiusPercent=1; e.ExplosionType=Enum.ExplosionType.NoCraters; e.Parent=ws end end; local h=o:FindFirstChildOfClass("Humanoid"); if h then h:TakeDamage(math.huge); h.Health=0 end end) end
registerMethod(119, "FEClassic", "119. FF Death Trap", "3 Explosion + Joint destroy", m_119)
local function m_121(o) claimFE(o); pcall(function() local h=o:FindFirstChildOfClass("Humanoid"); if h then h.RequiresNeck=true end; local hd=o:FindFirstChild("Head"); if hd then for _,j in ipairs(hd:GetChildren()) do if j:IsA("Motor6D") or j:IsA("Weld") then pcall(function() j.Part0=nil; j.Part1=nil end) end end end; if h then h:ChangeState(Enum.HumanoidStateType.Dead); h.Health=0 end end) end
registerMethod(121, "FEClassic", "121. Root/Head Decap", "Разрыв Head-Neck", m_121)
local function m_123(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); pcall(function() if h then h:ChangeState(Enum.HumanoidStateType.Ragdoll); h.PlatformStand=true end; for _,j in ipairs(getCached(o).motors) do pcall(function() j.Part0=nil; j.Part1=nil end) end; if h then h.Health=0 end end) end
registerMethod(123, "FEClassic", "123. Ragdoll Suffocation", "Ragdoll + Motor6D nil", m_123)
local function m_125(o) local r=getRootPart(o); if not r then return end; if not throttled(125, o, 2) then return end; task.spawn(function() for i=1,10 do if not o.Parent then break end; pcall(function() local a=(i/10)*math.pi*2; local off=Vector3.new(math.cos(a)*3,0,math.sin(a)*3); local e=Instance.new("Explosion"); e.Position=r.Position+off; e.BlastRadius=15; e.BlastPressure=0; e.DestroyJointRadiusPercent=1; e.ExplosionType=Enum.ExplosionType.NoCraters; e.Parent=ws; local h=o:FindFirstChildOfClass("Humanoid"); if h then h:TakeDamage(50000) end end); task.wait(0.05) end end) end
registerMethod(125, "FEClassic", "125. Explosion Ring 10x", "10 Explosion кольцом (was 20)", m_125)
local function m_137(o) claimFE(o); if not throttled(137, o, 1) then return end; task.spawn(function() local mts=getCached(o).motors; for tick=1,20 do if not o.Parent then break end; for i,m in ipairs(mts) do pcall(function() m.DesiredAngle=math.sin(tick*0.5+i)*1e6; m.MaxVelocity=math.huge end) end; task.wait(0.05) end end) end
registerMethod(137, "FEClassic", "137. Joint Velocity Osc", "Motor6D осцилляция (throttled)", m_137)
local function m_146(o) pcall(function() for _,d in ipairs(o:GetDescendants()) do if d:IsA("BindableEvent") then local nm=string.lower(d.Name); if string.find(nm,"died") or string.find(nm,"death") or string.find(nm,"kill") then pcall(function() d:Fire(); d:Fire(o) end) end end end end) end
registerMethod(146, "FEClassic", "146. Death Signal Fire", "Fire все Died events", m_146)
local function m_150(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); if not h then return end; task.spawn(function() pcall(function() h.Health=0; h:ChangeState(Enum.HumanoidStateType.Dead); task.wait(0.05); local hd=o:FindFirstChild("Head"); if hd then local n=hd:FindFirstChildOfClass("Motor6D"); if n then pcall(function() n:Destroy() end) end end; h:TakeDamage(math.huge) end) end) end
registerMethod(150, "FEClassic", "150. Death Cycle Sim", "Эмуляция death cycle", m_150)
local function m_156(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); if not h then return end; pcall(function() local d=Instance.new("HumanoidDescription"); d.HealthScale=0; d.HeightScale=0.01; d.WidthScale=0.01; d.DepthScale=0.01; h:ApplyDescription(d); task.wait(0.1); h.Health=0 end) end
registerMethod(156, "FEClassic", "156. HumanoidDesc Kill", "ApplyDescription scale=0", m_156)

-- 📡 REMOTES + WEAPONS
local function m_17(o) local c=lp.Character; if not c then return end; local t=c:FindFirstChildOfClass("Tool") or lp.Backpack:FindFirstChildOfClass("Tool"); if not t then return end; if t.Parent~=c then t.Parent=c end; local h=t:FindFirstChild("Handle"); local r=getRootPart(o); if not throttled(17, o, 0.5) then return end; task.spawn(function() for i=1,8 do if not o.Parent then break end; pcall(function() t:Activate() end); if h and r and firetouchinterest then pcall(function() h.Size=Vector3.new(35,35,35); h.Massless=true; h.CanCollide=false; firetouchinterest(h,r,0); firetouchinterest(h,r,1) end) end; task.wait(0.05) end; if h then pcall(function() h.Size=Vector3.new(1,4,1) end) end end) end
registerMethod(17, "RemotesWeapons", "17. Weapon Overdrive", "Tool:Activate + hitbox 35", m_17)
local function m_18(o) if #DeepAnalysisData.CombatRemotes==0 then runFullAnalysis() end; if not throttled(18, o, 0.4) then return end; task.spawn(function() for i=1,4 do if not o.Parent then break end; for _,r in ipairs(DeepAnalysisData.CombatRemotes) do pcall(function() if r:IsA("RemoteEvent") then r:FireServer(o); r:FireServer(o,100) elseif r:IsA("RemoteFunction") then task.spawn(function() r:InvokeServer(o) end) end end) end; task.wait(0.1) end end) end
registerMethod(18, "RemotesWeapons", "18. Remote Brute Force", "Combat remotes brute", m_18)
local function m_19(o) if #DeepAnalysisData.WeaponRemotes==0 then runFullAnalysis() end; for _,r in ipairs(DeepAnalysisData.WeaponRemotes) do pcall(function() if r:IsA("RemoteEvent") then r:FireServer(o); r:FireServer(getRootPart(o),999999) end end) end end
registerMethod(19, "RemotesWeapons", "19. Weapon Remote Hijack", "Все Tool remotes", m_19)
local function m_20(o) for _,d in ipairs(o:GetDescendants()) do if d:IsA("BindableEvent") then local nm=string.lower(d.Name); if string.find(nm,"die") or string.find(nm,"damage") then pcall(function() d:Fire() end) end end end end
registerMethod(20, "RemotesWeapons", "20. Bindable Trigger", "Fire все die/damage", m_20)
local function m_21(o) local r=getRootPart(o); local h=o:FindFirstChildOfClass("Humanoid"); for _,it in ipairs({o,r,h}) do if it then pcall(function() it:SetAttribute("Dead",true); it:SetAttribute("Health",0) end) end end end
registerMethod(21, "RemotesWeapons", "21. Attribute Tag", "SetAttribute Dead=true", m_21)
local function m_25(o) for _,v in ipairs(getCached(o).parts) do local nm=string.lower(v.Name); if string.find(nm,"hitbox") or string.find(nm,"weapon") then pcall(function() v:Destroy() end) end end end
registerMethod(25, "RemotesWeapons", "25. Disarm Hitbox", "Destroy hitbox/weapon parts", m_25)
local function m_37(o) if not firetouchinterest then return end; local c=lp.Character; if not c then return end; local t=c:FindFirstChildOfClass("Tool") or lp.Backpack:FindFirstChildOfClass("Tool"); if not t then return end; if t.Parent~=c then t.Parent=c end; if not throttled(37, o, 0.5) then return end; local tp={}; for _,p in ipairs(t:GetDescendants()) do if p:IsA("BasePart") then table.insert(tp,p) end end; local np=getCached(o).parts; task.spawn(function() for i=1,3 do if not o.Parent then break end; pcall(function() t:Activate() end); for _,x in ipairs(tp) do for _,y in ipairs(np) do pcall(function() firetouchinterest(x,y,0); firetouchinterest(x,y,1) end) end end; task.wait(0.08) end end) end
registerMethod(37, "RemotesWeapons", "37. Matrix Weapon Touch", "Tool parts × NPC parts", m_37)
local function m_43(o) if not firetouchinterest then return end; local r=getRootPart(o); if not r then return end; if not throttled(43, o, 0.5) then return end; task.spawn(function() local at={}; for _,d in ipairs(ws:GetDescendants()) do if d:IsA("TouchTransmitter") and d.Parent then table.insert(at,d.Parent) end end; for i=1,3 do for _,t in ipairs(at) do if t~=r then pcall(function() firetouchinterest(r,t,0); firetouchinterest(r,t,1) end) end end; task.wait(0.1) end end) end
registerMethod(43, "RemotesWeapons", "43. Touch Matrix Flood", "Все TouchTransmitters", m_43)
local function m_88(o) if not firetouchinterest then return end; local c=lp.Character; local r=getRootPart(o); if not c or not r then return end; for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then pcall(function() firetouchinterest(p,r,0); firetouchinterest(p,r,1) end) end end end
registerMethod(88, "RemotesWeapons", "88. Multi-Node Touch", "Части игрока → NPC root", m_88)
local function m_89(o) claimFE(o); for _,v in ipairs(o:GetDescendants()) do if v:IsA("Weld") or v:IsA("Motor6D") then if v.Part1 and string.find(string.lower(v.Part1.Name),"weapon") then pcall(function() v.Part0=nil; v.Part1=nil end) end end end end
registerMethod(89, "RemotesWeapons", "89. Custom Weld Detach", "Отрыв weapon welds", m_89)
local function m_105(o) local h=o:FindFirstChildOfClass("Humanoid"); if not h then return end; if not throttled(105, o, 3) then return end; task.spawn(function() for i=1,30 do if not o.Parent then break end; rs.Heartbeat:Wait(); pcall(function() h:TakeDamage(200) end) end end) end
registerMethod(105, "RemotesWeapons", "105. Server-Frame Sync", "TakeDamage x30 heartbeat", m_105)
local function m_106(o) local ids={}; pcall(function() for a,v in pairs(o:GetAttributes()) do if string.find(string.lower(a),"id") then table.insert(ids,v) end end end); table.insert(ids,o); table.insert(ids,o.Name); local r=getRootPart(o); if r then table.insert(ids,r) end; task.spawn(function() for _,rem in ipairs(DeepAnalysisData.CombatRemotes) do for _,id in ipairs(ids) do pcall(function() if rem:IsA("RemoteEvent") then rem:FireServer(id); rem:FireServer(id,999999); rem:FireServer({Target=id,Damage=999999}) end end) end; task.wait(0.05) end end) end
registerMethod(106, "RemotesWeapons", "106. Boss-ID Router", "Все ID × все remotes", m_106)
local function m_134(o) if not firetouchinterest then return end; local c=lp.Character; if not c then return end; if not throttled(134, o, 1) then return end; local mp={}; for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then table.insert(mp,p) end end; local np=getCached(o).parts; if #mp==0 or #np==0 then return end; task.spawn(function() for wave=1,3 do if not o.Parent then break end; for i=1,80 do pcall(function() local a=mp[math.random(1,#mp)]; local b=np[math.random(1,#np)]; if a and b then firetouchinterest(a,b,0); firetouchinterest(a,b,1) end end) end; task.wait(0.1) end end) end
registerMethod(134, "RemotesWeapons", "134. Touched Bomb", "Случайные Touched (throttled)", m_134)
local function m_139(o)
    if #DeepAnalysisData.CombatRemotes==0 then runFullAnalysis() end
    if not throttled(139, o, 1) then return end
    local r = getRootPart(o)
    local fmts = { {o},{o,999999},{o.Name},{"Attack",o},{"Damage",o,999999},{r,999999},{{Target=o,Damage=999999}},{lp,o,999999},{math.huge},{"kill",o.Name} }
    task.spawn(function()
        for _,rem in ipairs(DeepAnalysisData.CombatRemotes) do
            for _,f in ipairs(fmts) do pcall(function() if rem:IsA("RemoteEvent") then rem:FireServer(unpack(f)) end end) end
            task.wait(0.05)
        end
    end)
end
registerMethod(139, "RemotesWeapons", "139. Remote Fuzz 10fmt", "10 форматов на remotes", m_139)
local function m_145(o) local c=lp.Character; if not c then return end; local t=c:FindFirstChildOfClass("Tool") or lp.Backpack:FindFirstChildOfClass("Tool"); if not t then return end; if t.Parent~=c then t.Parent=c end; local h=t:FindFirstChild("Handle"); if not h then return end; local r=getRootPart(o); if not r then return end; if not throttled(145, o, 1) then return end; task.spawn(function() local oS=h.Size; for i=1,5 do if not o.Parent then break end; pcall(function() local mR=c:FindFirstChild("HumanoidRootPart"); if mR then local d=(r.Position-mR.Position).Magnitude+20; h.Size=Vector3.new(5,5,d); h.Massless=true; h.CanCollide=false; h.CFrame=CFrame.new(mR.Position,r.Position)*CFrame.new(0,0,-d/2) end; t:Activate(); if firetouchinterest then firetouchinterest(h,r,0); firetouchinterest(h,r,1) end end); task.wait(0.1) end; pcall(function() h.Size=oS end) end) end
registerMethod(145, "RemotesWeapons", "145. Handle Morph", "Растянуть Handle до NPC", m_145)
local function m_149(o) if not throttled(149, o, 5) then return end; task.spawn(function() print("[149] Запись 2сек — АТАКУЙ БОССА!"); local rec={}; for _,rem in ipairs(DeepAnalysisData.CombatRemotes) do if rem:IsA("RemoteEvent") then pcall(function() local orig=rem.FireServer; if rawset then rawset(rem,"FireServer",function(s,...) table.insert(rec,{r=s,a={...}}); return orig(s,...) end); table.insert(RecordedRemoteCalls,{r=rem,orig=orig}) end end) end end; task.wait(2); for _,x in ipairs(RecordedRemoteCalls) do pcall(function() rawset(x.r,"FireServer",nil) end) end; RecordedRemoteCalls={}; print("[149] Записано:",#rec," — повтор 20x"); for i=1,20 do if not o.Parent then break end; for _,r in ipairs(rec) do pcall(function() r.r:FireServer(unpack(r.a)) end) end; task.wait(0.05) end end) end
registerMethod(149, "RemotesWeapons", "149. Remote Replay", "Запись 2сек→повтор 20x", m_149)
local function m_155(o) local c=lp.Character; if not c then return end; local h=c:FindFirstChildOfClass("Humanoid"); if not h then return end; local ot=c:FindFirstChildOfClass("Tool") or lp.Backpack:FindFirstChildOfClass("Tool"); if not ot then return end; if not throttled(155, o, 3) then return end; task.spawn(function() local cls={}; for i=1,10 do pcall(function() local cl=ot:Clone(); cl.Parent=lp.Backpack; table.insert(cls,cl) end) end; task.wait(0.1); local r=getRootPart(o); for wave=1,3 do if not o.Parent then break end; for _,cl in ipairs(cls) do pcall(function() h:EquipTool(cl); cl:Activate(); local hd=cl:FindFirstChild("Handle"); if hd and r and firetouchinterest then firetouchinterest(hd,r,0); firetouchinterest(hd,r,1) end end) end; task.wait(0.15) end; for _,cl in ipairs(cls) do pcall(function() cl:Destroy() end) end end) end
registerMethod(155, "RemotesWeapons", "155. Tool Clone Flood", "10 клонов Tool → Activate", m_155)

-- 🦾 CUSTOM RIGS
local function m_7(o) claimFE(o); for _,v in ipairs(o:GetDescendants()) do if v:IsA("WeldConstraint") or v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") or v:IsA("AlignPosition") or v:IsA("SpringConstraint") then pcall(function() v:Destroy() end) end end end
registerMethod(7, "CustomRigs", "7. Constraint Shatter", "Уничтожение Constraint", m_7)
local function m_8(o) claimFE(o); for _,v in ipairs(getCached(o).bones) do pcall(function() v.Transform=CFrame.new(math.random(-50,50),math.random(-50,50),math.random(-50,50)) end) end end
registerMethod(8, "CustomRigs", "8. Bone Shatter", "Bones случайный CFrame", m_8)
local function m_9(o) claimFE(o); for i,p in ipairs(getCached(o).parts) do pcall(function() p.AssemblyLinearVelocity=Vector3.new(math.sin(i*99)*100000,math.cos(i*77)*100000,math.sin(i*33)*100000) end) end end
registerMethod(9, "CustomRigs", "9. Kinetic Body Tear", "Parts × разные velocity", m_9)
local function m_94(o) local t=o:FindFirstChildOfClass("Humanoid") or o:FindFirstChildOfClass("AnimationController"); if not t then return end; pcall(function() for _,tr in ipairs(t:GetPlayingAnimationTracks()) do tr:Stop(0) end end) end
registerMethod(94, "CustomRigs", "94. Animation Lock", "Stop все anim tracks", m_94)
local function m_95(o) claimFE(o); for _,p in ipairs(getCached(o).parts) do pcall(function() p.RootPriority=-127; p.Massless=true end) end end
registerMethod(95, "CustomRigs", "95. RootPriority Zero", "RootPriority=-127", m_95)
local function m_124(o) claimFE(o); if not throttled(124, o, 0.5) then return end; task.spawn(function() for wave=1,2 do if not o.Parent then break end; for i,p in ipairs(getCached(o).parts) do pcall(function() p.CanCollide=true; p.Massless=true; local d=Vector3.new(math.sin(i*0.7)*5000,math.abs(math.cos(i*0.3))*8000,math.cos(i*1.1)*5000); p.AssemblyLinearVelocity=d end) end; task.wait(0.1) end end) end
registerMethod(124, "CustomRigs", "124. Velocity Shredder", "Разрыв через velocity", m_124)
local function m_127(o) claimFE(o); if not throttled(127, o, 1) then return end; task.spawn(function() local mts=getCached(o).welds; for tick=1,20 do if not o.Parent then break end; for i,m in ipairs(mts) do pcall(function() local t=tick*0.1+i*0.37; m.C0=m.C0*CFrame.new(math.sin(t)*500,math.cos(t*1.3)*500,math.sin(t*0.7)*500) end) end; task.wait(0.05) end end) end
registerMethod(127, "CustomRigs", "127. CFrame Loop Crusher", "Motor6D CFrame атака", m_127)
local function m_128(o) claimFE(o); local t=o:FindFirstChildOfClass("Humanoid") or o:FindFirstChildOfClass("AnimationController"); if not t then return end; if not throttled(128, o, 5) then return end; task.spawn(function() local a=t:FindFirstChildOfClass("Animator"); if not a then a=Instance.new("Animator"); a.Parent=t end; for i=1,100 do if not o.Parent then break end; pcall(function() local an=Instance.new("Animation"); an.AnimationId="rbxassetid://0"; local tr=a:LoadAnimation(an); tr:Play(); tr:AdjustSpeed(1000) end); if i%20==0 then task.wait() end end; local h=o:FindFirstChildOfClass("Humanoid"); if h then task.wait(0.1); pcall(function() h:TakeDamage(math.huge); h.Health=0 end) end end) end
registerMethod(128, "CustomRigs", "128. Anim Track Overload", "100 anim tracks (was 500)", m_128)
local function m_129(o) local r=getRootPart(o); if not r then return end; if not throttled(129, o, 2) then return end; task.spawn(function() for i=1,5 do if not o.Parent then break end; pcall(function() local s=Instance.new("Sound"); s.SoundId="rbxassetid://9046196336"; s.Volume=10; s.PlaybackSpeed=math.huge; s.Pitch=20; s.Parent=r; s:Play(); game:GetService("Debris"):AddItem(s,0.5) end); task.wait(0.1) end end) end
registerMethod(129, "CustomRigs", "129. Sound Freq Weapon", "Sound PlaybackSpeed=huge", m_129)
local function m_130(o) claimFE(o); if not throttled(130, o, 1) then return end; task.spawn(function() local atts=getCached(o).atts; for tick=1,15 do if not o.Parent then break end; for i,att in ipairs(atts) do pcall(function() local t=tick*0.15+i*0.5; att.CFrame=CFrame.new(math.sin(t)*100,math.cos(t)*100,math.sin(t*2)*100) end) end; task.wait(0.06) end end) end
registerMethod(130, "CustomRigs", "130. Attachment Chaos", "Attachments орбиты", m_130)
local function m_131(o) claimFE(o); pcall(function() local gn="V"..tostring(math.random(1000,9999)); pcall(function() PhysicsService:RegisterCollisionGroup(gn) end); pcall(function() PhysicsService:CollisionGroupSetCollidable(gn,"Default",false) end); for _,p in ipairs(getCached(o).parts) do pcall(function() p.CollisionGroup=gn; p.CanCollide=false; p.Massless=true end) end; local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.FallingDown); h:TakeDamage(math.huge) end) end end) end
registerMethod(131, "CustomRigs", "131. CollisionGroup Iso", "Свой CollisionGroup", m_131)
local function m_132(o) if not throttled(132, o, 2) then return end; task.spawn(function() local ps={}; for _,p in ipairs(getCached(o).parts) do if not p.Anchored then table.insert(ps,p) end end; for wave=1,10 do if not o.Parent then break end; for _,p in ipairs(ps) do pcall(function() if wave%2==0 then p:SetNetworkOwner(lp) else p:SetNetworkOwnershipAuto() end end) end; task.wait(0.06) end; local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:TakeDamage(math.huge); h.Health=0 end) end end) end
registerMethod(132, "CustomRigs", "132. NetOwner Ping-Pong", "10 переключений NetOwner", m_132)
local function m_133(o) claimFE(o); if not throttled(133, o, 2) then return end; task.spawn(function() for _,p in ipairs(getCached(o).parts) do pcall(function() local bv=Instance.new("BodyVelocity"); bv.MaxForce=Vector3.new(math.huge,math.huge,math.huge); bv.Velocity=Vector3.new((math.random()-0.5)*500,math.random()*800,(math.random()-0.5)*500); bv.Parent=p; game:GetService("Debris"):AddItem(bv,1) end) end; task.wait(0.5); local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:TakeDamage(math.huge); h.Health=0 end) end end) end
registerMethod(133, "CustomRigs", "133. BodyForce Infinite", "BodyVelocity MaxForce=huge", m_133)
local function m_135(o) claimFE(o); pcall(function() for _,p in ipairs(getCached(o).parts) do pcall(function() p.Size=Vector3.new(0.01,0.01,0.01); p.Massless=true end) end; for _,p in ipairs(o:GetDescendants()) do if p:IsA("SpecialMesh") or p:IsA("BlockMesh") then pcall(function() p.Scale=Vector3.new(0.001,0.001,0.001) end) end end; local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:TakeDamage(math.huge); h.Health=0 end) end end) end
registerMethod(135, "CustomRigs", "135. Mesh Resize 0.01", "Все parts → 1см", m_135)
local function m_140(o) claimFE(o); pcall(function() for _,d in ipairs(o:GetDescendants()) do if d:IsA("WrapLayer") or d:IsA("WrapTarget") then pcall(function() d:Destroy() end) end; if d:IsA("MeshPart") then pcall(function() d.HasSkinnedMesh=false; d.Size=Vector3.new(0.01,0.01,0.01) end) end; if d:IsA("Bone") then pcall(function() d.Position=Vector3.new(math.random(-1e6,1e6),math.random(-1e6,1e6),math.random(-1e6,1e6)); d.Transform=CFrame.new(math.random(-9999,9999),math.random(-9999,9999),math.random(-9999,9999)) end) end end; local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:TakeDamage(math.huge) end) end end) end
registerMethod(140, "CustomRigs", "⭐140. SkinnedMesh Annihilate", "MOST POWERFUL!", m_140)
local function m_144(o) claimFE(o); pcall(function() for _,d in ipairs(o:GetDescendants()) do if d:IsA("ControllerManager") then pcall(function() d.BaseMoveSpeed=0; d.BaseTurnSpeed=0 end) end; if d:IsA("GroundController") or d:IsA("AirController") then pcall(function() d.MoveSpeedFactor=0 end) end end; local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Ragdoll); h.Health=0 end) end end) end
registerMethod(144, "CustomRigs", "144. CtrlManager Hijack", "ControllerManager speed=0", m_144)
local function m_147(o) claimFE(o); pcall(function() for _,d in ipairs(o:GetDescendants()) do if d:IsA("SpecialMesh") then pcall(function() d.MeshId=""; d.TextureId=""; d.Scale=Vector3.new(0,0,0) end) elseif d:IsA("MeshPart") then pcall(function() d.MeshId=""; d.TextureID=""; d.Size=Vector3.new(0.01,0.01,0.01) end) end end; local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:TakeDamage(math.huge) end) end end) end
registerMethod(147, "CustomRigs", "147. MeshId Corruption", "MeshId=''+Scale=0", m_147)
local function m_151(o) claimFE(o); pcall(function() for _,d in ipairs(getCached(o).parts) do if d:IsA("Part") then pcall(function() d.Shape=Enum.PartType.Ball; d.CustomPhysicalProperties=PhysicalProperties.new(0.01,0,1,100,100) end) end end; local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Physics); h:TakeDamage(math.huge) end) end end) end
registerMethod(151, "CustomRigs", "151. Part Shape → Ball", "Shape=Ball всё катится", m_151)
local function m_154(o) claimFE(o); pcall(function() for _,d in ipairs(getCached(o).parts) do local nm=string.lower(d.Name); if string.find(nm,"hitbox") or string.find(nm,"weapon") or string.find(nm,"attack") or string.find(nm,"claw") or string.find(nm,"fist") or string.find(nm,"blade") then pcall(function() d.CanQuery=false; d.CanTouch=false; d.CanCollide=false; d.Transparency=1 end) end end; local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:TakeDamage(math.huge); h.Health=0 end) end end) end
registerMethod(154, "CustomRigs", "154. CanQuery Disable", "Вырубить hitboxes", m_154)

-- 📊 MATH STATS
local function m_4(o) claimFE(o); for _,v in ipairs(o:GetDescendants()) do if v:IsA("NumberValue") or v:IsA("IntValue") then local nm=string.lower(v.Name); if string.find(nm,"hp") or string.find(nm,"health") or string.find(nm,"shield") then pcall(function() v.Value=0 end) end end end; for a,_ in pairs(o:GetAttributes()) do local nm=string.lower(a); if string.find(nm,"hp") or string.find(nm,"health") then pcall(function() o:SetAttribute(a,0) end) end end end
registerMethod(4, "MathStats", "4. Value/Attr Zero", "HP values → 0", m_4)
local function m_11(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); if h then if not throttled(11, o, 1) then return end; task.spawn(function() for i=1,8 do if not o.Parent then break end; pcall(function() h:TakeDamage(math.huge); h.Health=0 end); task.wait(0.06) end end) end end
registerMethod(11, "MathStats", "11. TakeDamage Loop", "TakeDamage(huge) x8", m_11)
local function m_12(o) for _,v in ipairs(o:GetDescendants()) do if v:IsA("NumberValue") then local nm=string.lower(v.Name); if string.find(nm,"hp") or string.find(nm,"health") then pcall(function() v.Value=0/0 end) end end end end
registerMethod(12, "MathStats", "12. NaN Crash", "HP = 0/0 (NaN)", m_12)
local function m_13(o) for _,v in ipairs(o:GetDescendants()) do if v:IsA("NumberValue") then local nm=string.lower(v.Name); if string.find(nm,"hp") or string.find(nm,"damage") then pcall(function() v.Value=1e308 end) end end end end
registerMethod(13, "MathStats", "13. Double Overflow", "HP = 1e308", m_13)
local function m_14(o) for _,v in ipairs(o:GetDescendants()) do if v:IsA("NumberValue") or v:IsA("IntValue") then local nm=string.lower(v.Name); if string.find(nm,"hp") or string.find(nm,"health") then pcall(function() v.Value=-999999 end) end end end end
registerMethod(14, "MathStats", "14. Negative HP", "HP = -999999", m_14)
local function m_15(o) for _,ff in ipairs(o:GetDescendants()) do if ff:IsA("ForceField") then pcall(function() ff:Destroy() end) end end; for _,v in ipairs(o:GetDescendants()) do if v:IsA("NumberValue") or v:IsA("BoolValue") then local nm=string.lower(v.Name); if string.find(nm,"shield") or string.find(nm,"god") then pcall(function() if v:IsA("BoolValue") then v.Value=false else v.Value=0 end end) end end end end
registerMethod(15, "MathStats", "15. Strip Shields", "ForceField+shield=0", m_15)
local function m_16(o) local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h.MaxHealth=1; h.Health=0 end) end end
registerMethod(16, "MathStats", "16. MaxHealth=1", "MaxHealth=1→Health=0", m_16)
local function m_91(o) local r=getRootPart(o); local h=o:FindFirstChildOfClass("Humanoid"); for _,it in ipairs({o,r,h}) do if it then for _,a in ipairs({"Shield","Armor","GodMode","Invulnerable"}) do pcall(function() it:SetAttribute(a,0) end) end end end end
registerMethod(91, "MathStats", "91. Shield Vaporizer", "Shield attrs = 0", m_91)
local function m_96(o) pcall(function() for _,t in ipairs({"Dead","Killed","KillBrick","Lava","Deadly","Death"}) do pcall(function() CollectionService:AddTag(o,t) end) end end) end
registerMethod(96, "MathStats", "96. Universal Death Tag", "Все death-теги", m_96)
local function m_118(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); if not throttled(118, o, 1) then return end; task.spawn(function() for i=1,15 do if not o.Parent then break end; pcall(function() if h then h.MaxHealth=0; h.Health=0; h:TakeDamage(math.huge) end end); task.wait(0.05) end end) end
registerMethod(118, "MathStats", "118. Health Clamp", "MaxHealth=0 loop", m_118)
local function m_120(o) pcall(function() for _,p in ipairs(getCached(o).parts) do pcall(function() p.BrickColor=BrickColor.new("Medium stone grey") end) end; for _,a in ipairs({"Team","TeamColor","Faction","Enemy"}) do pcall(function() o:SetAttribute(a,"Neutral") end) end; local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:TakeDamage(math.huge); h.Health=0 end) end end) end
registerMethod(120, "MathStats", "120. Neutral Team", "Team → Neutral", m_120)
local function m_122(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); if not h then return end; if not throttled(122, o, 1) then return end; task.spawn(function() for wave=1,3 do if not o.Parent then break end; for i=1,50 do pcall(function() h:TakeDamage(1e9) end) end; pcall(function() h.Health=0 end); task.wait(0.05) end end) end
registerMethod(122, "MathStats", "122. Massive TakeDamage", "50×TakeDamage(1e9) x3", m_122)
local function m_136(o) pcall(function() for _,v in ipairs(o:GetDescendants()) do pcall(function() if v:IsA("NumberValue") or v:IsA("IntValue") then v.Value=0 elseif v:IsA("BoolValue") then v.Value=false end end) end; for a,vl in pairs(o:GetAttributes()) do pcall(function() if type(vl)=="number" then o:SetAttribute(a,0) elseif type(vl)=="boolean" then o:SetAttribute(a,false) end end) end end) end
registerMethod(136, "MathStats", "136. Cascade Purge", "Обнуление Values/Attributes", m_136)
local function m_138(o) claimFE(o); pcall(function() for _,v in ipairs(o:GetDescendants()) do if v:IsA("NumberValue") or v:IsA("IntValue") then local nm=string.lower(v.Name); if string.find(nm,"regen") or string.find(nm,"heal") then pcall(function() v.Value=-1e6 end) end end end; local h=o:FindFirstChildOfClass("Humanoid"); if h then local c; c=h.HealthChanged:Connect(function(nh) if nh>0 then pcall(function() h.Health=0; h:TakeDamage(math.huge) end) end end); task.delay(10,function() if c then c:Disconnect() end end) end end) end
registerMethod(138, "MathStats", "138. Regen Inversion", "Regen=-1e6+auto-kill", m_138)
local function m_143(o) pcall(function() for _,v in ipairs(o:GetDescendants()) do if v:IsA("NumberValue") or v:IsA("IntValue") then local nm=string.lower(v.Name); if string.find(nm,"defense") or string.find(nm,"armor") or string.find(nm,"resist") then pcall(function() v.Value=0 end) elseif string.find(nm,"multi") then pcall(function() v.Value=1000 end) end end end end) end
registerMethod(143, "MathStats", "143. Defense Hijack", "Armor=0, Multi=1000", m_143)
local function m_148(o) pcall(function() for _,st in ipairs({"Poison","Burn","Bleed","Frozen","Cursed"}) do o:SetAttribute(st,true); o:SetAttribute(st.."Stacks",999); o:SetAttribute(st.."Damage",999999) end; local h=o:FindFirstChildOfClass("Humanoid"); if h then if not throttled(148, o, 2) then return end; task.spawn(function() for i=1,15 do if not o.Parent then break end; pcall(function() h:TakeDamage(50000) end); task.wait(0.15) end end) end end) end
registerMethod(148, "MathStats", "148. Status Effect Inject", "Poison/Burn+DoT loop", m_148)
local function m_153(o) claimFE(o); local h=o:FindFirstChildOfClass("Humanoid"); if not h then return end; if not throttled(153, o, 1) then return end; task.spawn(function() local m=h.MaxHealth; for step=1,12 do if not o.Parent then break end; pcall(function() m=m*0.5; h.MaxHealth=math.max(1,m); h.Health=math.min(h.Health,h.MaxHealth); if step>=8 then h.MaxHealth=0; h.Health=0 end end); task.wait(0.08) end end) end
registerMethod(153, "MathStats", "153. MaxHealth Ladder", "MaxHealth ×0.5 x12", m_153)

-- 👑 GOLDEN GRAIL
local function m_86(o) local h=o:FindFirstChildOfClass("Humanoid"); if not h then return end; local d=CombatSettings.DamageAmount; pcall(function() h:TakeDamage(d); if d>=999999 then h.Health=0 end end) end
registerMethod(86, "GoldenGrail", "86. Golden Grail", "Настраиваемый TakeDamage", m_86)
local function m_87(o) local h=o:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:TakeDamage(999999); h.Health=0 end) end; task.spawn(function() for _,r in ipairs(DeepAnalysisData.CombatRemotes) do pcall(function() if r:IsA("RemoteEvent") then r:FireServer(o); r:FireServer(o,999999) end end) end end) end
registerMethod(87, "GoldenGrail", "87. Grail Composite", "TakeDamage+эхо remotes", m_87)
local function m_141(o) local h=o:FindFirstChildOfClass("Humanoid"); if not h then return end; if not throttled(141, o, 1) then return end; task.spawn(function() for w=1,6 do if not o.Parent then break end; local d=CombatSettings.DamageAmount*w; pcall(function() h:TakeDamage(d); if w>=5 then h.Health=0 end end); task.wait(0.08) end end) end
registerMethod(141, "GoldenGrail", "141. Grail Wave Stack", "6 нарастающих волн", m_141)
local function m_152(o) local h=o:FindFirstChildOfClass("Humanoid"); if not h then return end; if not throttled(152, o, 1) then return end; task.spawn(function() local d=CombatSettings.DamageAmount; for i=1,200 do pcall(function() h:TakeDamage(d) end) end; pcall(function() h.Health=0 end) end) end
registerMethod(152, "GoldenGrail", "152. Grail Shotgun 200x", "200×TakeDamage за кадр", m_152)

-- 🎮 PLAYER INPUT SIM
local function m_93(o) for _,d in ipairs(ws:GetDescendants()) do if d:IsA("ProximityPrompt") then pcall(function() if fireproximityprompt then fireproximityprompt(d) end end) elseif d:IsA("ClickDetector") then pcall(function() if fireclickdetector then fireclickdetector(d) end end) end end end
registerMethod(93, "PlayerInputSim", "93. Dungeon PP/Click", "Все PP+ClickDetector", m_93)
local function m_98(o) local c=lp.Character; if not c then return end; local h=c:FindFirstChildOfClass("Humanoid"); if not h then return end; if not throttled(98, o, 1) then return end; task.spawn(function() local tools={}; for _,t in ipairs(c:GetChildren()) do if t:IsA("Tool") then table.insert(tools,t) end end; for _,t in ipairs(lp.Backpack:GetChildren()) do if t:IsA("Tool") then table.insert(tools,t) end end; for _,t in ipairs(tools) do if not o.Parent then break end; pcall(function() h:EquipTool(t) end); task.wait(0.1); for i=1,5 do pcall(function() t:Activate() end); task.wait(0.15) end end end) end
registerMethod(98, "PlayerInputSim", "98. Tool Activate Legit", "Cycle Equip+Activate", m_98)
local function m_99(o) local keys={Enum.KeyCode.Q,Enum.KeyCode.E,Enum.KeyCode.R,Enum.KeyCode.F,Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,Enum.KeyCode.Four}; task.spawn(function() for _,k in ipairs(keys) do pcall(function() VIM:SendKeyEvent(true,k,false,game); task.wait(0.05); VIM:SendKeyEvent(false,k,false,game) end); task.wait(0.1) end end) end
registerMethod(99, "PlayerInputSim", "99. Ability Keys", "Нажать Q/E/R/F/1-4", m_99)
local function m_102(o) local c=lp.Character; if not c then return end; local mH=c:FindFirstChildOfClass("Humanoid"); if not mH then return end; task.spawn(function() for i=1,10 do pcall(function() if mH.Health<mH.MaxHealth*0.5 then mH.Health=mH.MaxHealth end; if not c:FindFirstChildOfClass("ForceField") then local ff=Instance.new("ForceField"); ff.Visible=false; ff.Parent=c; game:GetService("Debris"):AddItem(ff,3) end end); task.wait(0.5) end end); pcall(function() mH.BreakJointsOnDeath=false end) end
registerMethod(102, "PlayerInputSim", "102. Self-Kick Prevent", "Base защита игрока", m_102)
local function m_103(o) local c=lp.Character; if not c then return end; local h=c:FindFirstChildOfClass("Humanoid"); for _,t in ipairs(lp.Backpack:GetChildren()) do if t:IsA("Tool") then pcall(function() h:EquipTool(t) end); task.wait(0.05) end end end
registerMethod(103, "PlayerInputSim", "103. Auto-Equip All", "Взять все Tools", m_103)
local function m_142(o) if not fireproximityprompt then return end; if not throttled(142, o, 1) then return end; task.spawn(function() for wave=1,3 do if not o.Parent then break end; for _,pp in ipairs(o:GetDescendants()) do if pp:IsA("ProximityPrompt") then pcall(function() fireproximityprompt(pp) end) end end; task.wait(0.15) end end) end
registerMethod(142, "PlayerInputSim", "142. PP Abuse", "Триггер PP на боссе", m_142)

-- 🚀 DESTROYER
local function m_10(o) claimFE(o); local r=getRootPart(o); if not r then return end; pcall(function() r.AssemblyAngularVelocity=Vector3.new(1e6,1e6,1e6) end) end
registerMethod(10, "DestroyerServer", "10. Angular Spin", "AssemblyAngular 1e6", m_10, false)
local function m_29(o) claimFE(o); local r=getRootPart(o); if not r then return end; pcall(function() r.CanCollide=false; r.CFrame=r.CFrame+Vector3.new(0,50,0); r.AssemblyLinearVelocity=Vector3.new(1e9,1e9,-1e9) end) end
registerMethod(29, "DestroyerServer", "29. Supersonic Launch", "Отстрел 10^9", m_29, false)
local function m_41(o) claimFE(o); for _,v in ipairs(getCached(o).welds) do pcall(function() v.C0=CFrame.new(0,-5000,0); v.C1=CFrame.new(10000,10000,10000) end) end end
registerMethod(41, "DestroyerServer", "41. Motor CFrame Crush", "C0/C1 крайние", m_41, false)

-- ============================================================================
-- 🎯 10 НОВЫХ МЕТОДОВ v41 (№157-166) — ПРОДВИНУТЫЙ ПОДХОД К БОССАМ
-- ============================================================================

-- 🎯 157. SERVER-AUTHORITY BYPASS — эксплойт через ownership queue
-- Идея: если мы владеем частью через network ownership, сервер обязан
-- принять физику. Пулим ownership 50 раз чтобы забить очередь и вставить
-- нашу «смертельную» физику пока сервер не успел валидировать.
local function m_157(o)
    if not throttled(157, o, 3) then return end
    print("[🎯 157] Server-Authority Bypass:", o.Name)
    task.spawn(function()
        local parts = getCached(o).parts
        if #parts == 0 then return end
        -- Фаза 1: захватываем ownership на все части
        for _,p in ipairs(parts) do
            pcall(function() if not p.Anchored then p:SetNetworkOwner(lp) end end)
        end
        task.wait(0.05)
        -- Фаза 2: массированно вставляем «смертельную» физику в течение 1 кадра
        -- Сервер обрабатывает ownership queue пачками, наши изменения
        -- пройдут раньше валидации
        rs.Heartbeat:Wait()
        local r = getRootPart(o)
        if r then
            for i = 1, 10 do
                pcall(function()
                    r.AssemblyLinearVelocity = Vector3.new(math.random(-1e5,1e5), 1e5, math.random(-1e5,1e5))
                    r.CFrame = r.CFrame  -- «touch» триггерит replication
                end)
            end
        end
        -- Фаза 3: сразу же наносим Humanoid урон в тот же кадр
        local h = o:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:TakeDamage(math.huge); h.Health = 0 end) end
    end)
end
registerMethod(157, "RemotesWeapons", "157. 🎯 Server-Auth Bypass", "Ownership queue exploit", m_157)

-- 🎯 158. REMOTE ARGUMENT MUTATION — подсматриваем реальный вызов и мутируем
-- Идея: игра сама шлёт валидный remote с валидными аргументами. Мы хукаем
-- метод FireServer, копируем аргументы последнего вызова, потом файрим
-- этот же remote 30 раз с той же структурой аргументов, но меняем damage.
local RemoteMutation = { hooked = {}, lastCall = nil }
local function m_158(o)
    if not throttled(158, o, 4) then return end
    print("[🎯 158] Remote Arg Mutation — АТАКУЙ 2 сек чтобы записать!")
    task.spawn(function()
        -- Ставим хук на все combat remotes
        for _,rem in ipairs(DeepAnalysisData.CombatRemotes) do
            if rem:IsA("RemoteEvent") and not RemoteMutation.hooked[rem] then
                pcall(function()
                    if rawset then
                        local orig = rem.FireServer
                        rawset(rem, "FireServer", function(self, ...)
                            RemoteMutation.lastCall = { rem = self, args = {...} }
                            return orig(self, ...)
                        end)
                        RemoteMutation.hooked[rem] = orig
                    end
                end)
            end
        end
        task.wait(2)  -- Игрок должен ударить
        -- Убираем хуки
        for rem, orig in pairs(RemoteMutation.hooked) do
            pcall(function() rawset(rem, "FireServer", nil) end)
        end
        RemoteMutation.hooked = {}
        -- Мутируем и повторяем 30 раз
        if RemoteMutation.lastCall then
            local rec = RemoteMutation.lastCall
            print("[🎯 158] Записан вызов, аргументов:", #rec.args, "— мутируем 30x")
            for i = 1, 30 do
                if not o.Parent then break end
                pcall(function()
                    -- Пробуем мутировать argument #2 (обычно damage) в 1000000
                    local mutated = {}
                    for j, arg in ipairs(rec.args) do
                        if j == 2 and type(arg) == "number" then mutated[j] = 999999
                        else mutated[j] = arg end
                    end
                    rec.rem:FireServer(unpack(mutated))
                end)
                task.wait(0.05)
            end
        else print("[🎯 158] Не удалось записать вызов — атакуй боссом!") end
    end)
end
registerMethod(158, "RemotesWeapons", "158. 🎯 Arg Mutation Replay", "Хук+мутация реального remote", m_158)

-- 🎯 159. HUMANOID SUBTYPE COERCION — принудительный R6/R15 mismatch
-- Идея: если босс R15, форсим его в R6 (или наоборот). Rig не совпадёт
-- со скелетом → бесконечные ошибки анимации + сервер не может обработать.
local function m_159(o)
    claimFE(o)
    local h = o:FindFirstChildOfClass("Humanoid"); if not h then return end
    print("[🎯 159] Humanoid Subtype Coercion:", o.Name)
    pcall(function()
        -- Переключаем RigType (если R15 → R6, если R6 → R15)
        local currentType = h.RigType
        h.RigType = (currentType == Enum.HumanoidRigType.R15) and Enum.HumanoidRigType.R6 or Enum.HumanoidRigType.R15
        task.wait(0.05)
        -- И обратно за 1 кадр — race condition
        h.RigType = currentType
        task.wait(0.05)
        h.RigType = (currentType == Enum.HumanoidRigType.R15) and Enum.HumanoidRigType.R6 or Enum.HumanoidRigType.R15
        -- Финал: наносим урон пока rig ломается
        h:TakeDamage(math.huge)
        h.Health = 0
    end)
end
registerMethod(159, "CustomRigs", "159. 🎯 Rig Type Coercion", "R6/R15 mismatch attack", m_159)

-- 🎯 160. CHARACTER PROPERTY MIRROR — временное владение боссом
-- Идея: LocalPlayer.Character = boss. Сервер и client-side скрипты
-- обрабатывают боса как «нашего персонажа» — все системы урона игрока
-- начинают бить его. Быстро возвращаем свой Character назад.
local function m_160(o)
    if not throttled(160, o, 5) then return end
    print("[🎯 160] Character Property Mirror:", o.Name)
    local myChar = lp.Character
    local myCF = myChar and myChar:FindFirstChild("HumanoidRootPart") and myChar.HumanoidRootPart.CFrame
    task.spawn(function()
        pcall(function()
            -- Временно «владеем» боссом как своим Character
            lp.Character = o
            task.wait()  -- 1 кадр
            local h = o:FindFirstChildOfClass("Humanoid")
            if h then
                -- Все системы «нашей смерти» теперь бьют по боссу
                h.Health = 0
                h:TakeDamage(math.huge)
                h:ChangeState(Enum.HumanoidStateType.Dead)
                if o.BreakJoints then o:BreakJoints() end
            end
            task.wait(0.1)
            -- Возвращаем свой Character
            lp.Character = myChar
            if myChar and myChar:FindFirstChild("HumanoidRootPart") and myCF then
                myChar.HumanoidRootPart.CFrame = myCF
            end
        end)
    end)
end
registerMethod(160, "RemotesWeapons", "160. 🎯 Character Mirror", "lp.Character=boss на 1 кадр", m_160)

-- 🎯 161. REMOTE PAYLOAD OVERSIZE — 100KB строка в аргументе
-- Идея: если игра парсит remote args синхронно, огромный payload
-- заставит сервер задыхаться и таймаутить handler. Пока обработка
-- висит, следующие наши remote проходят без валидации.
local function m_161(o)
    if not throttled(161, o, 5) then return end
    print("[🎯 161] Remote Payload Oversize:", o.Name)
    task.spawn(function()
        -- Создаём 50KB строку (100KB может уронить нас самих)
        local hugeString = string.rep("A", 50000)
        for _,rem in ipairs(DeepAnalysisData.CombatRemotes) do
            if rem:IsA("RemoteEvent") then
                pcall(function()
                    -- Оверсайз payload
                    rem:FireServer(o, hugeString)
                    rem:FireServer(o, 999999, hugeString)
                    rem:FireServer(hugeString, o)
                end)
            end
        end
        -- Пока сервер жуёт → наши «легитимные» атаки проходят
        task.wait(0.2)
        local h = o:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:TakeDamage(math.huge); h.Health=0 end) end
        for _,rem in ipairs(DeepAnalysisData.CombatRemotes) do
            if rem:IsA("RemoteEvent") then pcall(function() rem:FireServer(o); rem:FireServer(o,999999) end) end
        end
    end)
end
registerMethod(161, "RemotesWeapons", "161. 🎯 Payload Oversize 50KB", "Оверсайз remote args", m_161)

-- 🎯 162. PHYSICS PIPELINE HIJACK — AlignPosition с infinite force на HRP
-- Идея: AlignPosition с math.huge force заставляет физический solver
-- сервера сходить с ума. HRP уходит в -Y с бесконечной силой пока
-- Humanoid обрабатывает FallingDown → Dead автоматом.
local function m_162(o)
    claimFE(o)
    local r = getRootPart(o); if not r then return end
    if not throttled(162, o, 3) then return end
    print("[🎯 162] Physics Pipeline Hijack:", o.Name)
    task.spawn(function()
        pcall(function()
            -- Создаём Attachment на HRP если нет
            local att = r:FindFirstChildOfClass("Attachment") or Instance.new("Attachment", r)
            att.Position = Vector3.zero
            -- AlignPosition с бесконечной силой
            local ap = Instance.new("AlignPosition")
            ap.Attachment0 = att
            ap.Mode = Enum.PositionAlignmentMode.OneAttachment
            ap.MaxForce = math.huge
            ap.MaxVelocity = math.huge
            ap.Responsiveness = 200
            ap.Position = Vector3.new(r.Position.X, -1000, r.Position.Z)  -- тянем вниз
            ap.Parent = r
            game:GetService("Debris"):AddItem(ap, 3)
            -- Плюс Humanoid state
            local h = o:FindFirstChildOfClass("Humanoid")
            if h then h:ChangeState(Enum.HumanoidStateType.FallingDown); h:TakeDamage(math.huge) end
        end)
    end)
end
registerMethod(162, "CustomRigs", "162. 🎯 Physics Pipeline Hijack", "AlignPosition math.huge force", m_162)

-- 🎯 163. EVENT REPLAY WITHOUT INPUT — крадём сигнатуру у другого игрока
-- Идея: когда другой игрок бьёт босса, его remote летит через сервер.
-- Некоторые игры реплицируют через OnClientEvent → мы ловим ЧУЖОЙ event
-- и файрим его от своего имени, обходя проверки «наш ли это удар».
local StolenEventCache = { hookedRemotes = {}, stolen = {} }
local function m_163(o)
    if not throttled(163, o, 5) then return end
    print("[🎯 163] Event Replay Steal — ждём атаку ДРУГИХ игроков 3 сек!")
    task.spawn(function()
        -- Хукаем OnClientEvent для всех remotes
        for _,rem in ipairs(rep:GetDescendants()) do
            if rem:IsA("RemoteEvent") and not StolenEventCache.hookedRemotes[rem] then
                pcall(function()
                    local c = rem.OnClientEvent:Connect(function(...)
                        table.insert(StolenEventCache.stolen, { rem = rem, args = {...} })
                    end)
                    StolenEventCache.hookedRemotes[rem] = c
                end)
            end
        end
        task.wait(3)
        -- Отключаем хуки
        for _, c in pairs(StolenEventCache.hookedRemotes) do pcall(function() c:Disconnect() end) end
        StolenEventCache.hookedRemotes = {}
        print("[🎯 163] Украдено событий:", #StolenEventCache.stolen, "— файрим все на сервер")
        -- Реплеим все украденные события на сервер
        for _, ev in ipairs(StolenEventCache.stolen) do
            pcall(function() ev.rem:FireServer(unpack(ev.args)) end)
        end
        StolenEventCache.stolen = {}
    end)
end
registerMethod(163, "RemotesWeapons", "163. 🎯 Event Steal Replay", "Красть OnClientEvent 3сек", m_163)

-- 🎯 164. HITBOX PARENT SWAP — Handle оружия как ребёнок босса
-- Идея: некоторые игры проверяют «принадлежит ли hitbox моему герою».
-- Если наш Handle временно станет ребёнком босса, движок посчитает
-- его частью босса → self-damage прописывается автоматически.
local function m_164(o)
    local c = lp.Character; if not c then return end
    local t = c:FindFirstChildOfClass("Tool") or lp.Backpack:FindFirstChildOfClass("Tool"); if not t then return end
    if t.Parent ~= c then t.Parent = c end
    local h = t:FindFirstChild("Handle"); if not h then return end
    if not throttled(164, o, 3) then return end
    print("[🎯 164] Hitbox Parent Swap:", o.Name)
    task.spawn(function()
        local origParent = h.Parent
        pcall(function()
            -- Перемещаем Handle внутрь босса как child (не Weld, а именно Parent!)
            h.Parent = o
            task.wait()
            -- Активируем tool чтобы hitbox сработал
            t:Activate()
            task.wait(0.05)
            -- Firetouch на все части босса
            if firetouchinterest then
                for _,p in ipairs(getCached(o).parts) do
                    pcall(function() firetouchinterest(h, p, 0); firetouchinterest(h, p, 1) end)
                end
            end
            task.wait(0.1)
            -- Возвращаем
            h.Parent = origParent
        end)
    end)
end
registerMethod(164, "RemotesWeapons", "164. 🎯 Hitbox Parent Swap", "Handle → child боса", m_164)

-- 🎯 165. STREAMING ZONE ABUSE — форсим босса в NonReplicated zone
-- Идея: если у игры StreamingEnabled, куски мира могут быть NonReplicated.
-- Перемещаем модель босса как child NonReplicated контейнера временно →
-- сервер начинает игнорировать босса, клиент теряет визуал, но урон Health
-- продолжает применяться.
local function m_165(o)
    if not throttled(165, o, 5) then return end
    print("[🎯 165] Streaming Zone Abuse:", o.Name)
    task.spawn(function()
        local origParent = o.Parent
        pcall(function()
            -- Пробуем найти NonReplicatedFolder или создать
            local nonRep = ws:FindFirstChild("NonReplicated") or ws:FindFirstChild("CameraShake") or ws:FindFirstChild("Debris")
            if not nonRep then
                nonRep = Instance.new("Folder")
                nonRep.Name = "_ZoneVoid"
                nonRep.Parent = ws
                game:GetService("Debris"):AddItem(nonRep, 5)
            end
            -- Перемещаем босса
            o.Parent = nonRep
            task.wait(0.05)
            -- Бьём пока «невидимый»
            local h = o:FindFirstChildOfClass("Humanoid")
            if h then
                for i = 1, 10 do
                    pcall(function() h:TakeDamage(math.huge); h.Health = 0 end)
                    task.wait(0.02)
                end
            end
            -- Возвращаем на место (уже мёртвый)
            if origParent and origParent.Parent then
                pcall(function() o.Parent = origParent end)
            end
        end)
    end)
end
registerMethod(165, "CustomRigs", "165. 🎯 Streaming Zone Abuse", "Босс в NonReplicated 1 кадр", m_165)

-- 🎯 166. REMOTE INVOKE RECURSION — переполнение handler stack
-- Идея: RemoteFunction:InvokeServer блокирует пока сервер не ответит.
-- Если делать 100 InvokeServer одновременно (через spawn), у сервера
-- забивается stack и он теряет валидацию promises.
local function m_166(o)
    if not throttled(166, o, 5) then return end
    print("[🎯 166] Remote Invoke Recursion:", o.Name)
    task.spawn(function()
        local rfs = {}
        for _,rem in ipairs(DeepAnalysisData.CombatRemotes) do
            if rem:IsA("RemoteFunction") then table.insert(rfs, rem) end
        end
        if #rfs == 0 then print("[166] Нет RemoteFunctions"); return end
        -- Запускаем 100 параллельных InvokeServer
        for i = 1, 100 do
            task.spawn(function()
                pcall(function()
                    local rf = rfs[math.random(1, #rfs)]
                    rf:InvokeServer(o, 999999)
                end)
            end)
        end
        task.wait(0.3)
        -- В окно stack overflow вставляем обычные атаки
        local h = o:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:TakeDamage(math.huge); h.Health = 0 end) end
    end)
end
registerMethod(166, "RemotesWeapons", "166. 🎯 Invoke Recursion 100x", "100 InvokeServer параллельно", m_166)

-- ============================================================================
-- 🎯 10 НОВЫХ МЕТОДОВ v42 (№167-176) — ЕЩЁ БОЛЬШЕ ПРОДВИНУТЫХ ВЕКТОРОВ
-- ============================================================================

-- 🎯 167. HUMANOID HEALTH DISPLAY CORRUPT — эксплойт HealthDisplayDistance
-- Идея: HealthDisplayDistance/HealthDisplayType влияют на клиентский расчёт HP.
-- Установка в невалидный enum + отрицательное расстояние заставляет клиент
-- посылать некорректные HP updates, сервер синхронизирует и HP уходит в 0.
local function m_167(o)
    claimFE(o)
    local h = o:FindFirstChildOfClass("Humanoid"); if not h then return end
    print("[🎯 167] HealthDisplay Corrupt:", o.Name)
    pcall(function()
        h.HealthDisplayDistance = -1
        h.NameDisplayDistance = -1
        h.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
        h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        -- Плюс sync-attack на HP
        for i = 1, 5 do
            h.Health = -math.huge
            h:TakeDamage(math.huge)
            task.wait()
        end
    end)
end
registerMethod(167, "MathStats", "167. 🎯 HealthDisplay Corrupt", "HealthDisplayDistance=-1+HP=-huge", m_167)

-- 🎯 168. ANIMATOR EVAL POISON — вставка модифицированного Animator
-- Идея: Animator есть у любого Humanoid/AnimationController. Если удалить
-- родной и вставить новый + залить 200 треков с невалидными IDs, сервер
-- начнёт race condition между animation eval и humanoid tick.
local function m_168(o)
    claimFE(o)
    local target = o:FindFirstChildOfClass("Humanoid") or o:FindFirstChildOfClass("AnimationController")
    if not target then return end
    if not throttled(168, o, 3) then return end
    print("[🎯 168] Animator Eval Poison:", o.Name)
    task.spawn(function()
        pcall(function()
            -- Убиваем старый Animator
            for _,a in ipairs(target:GetChildren()) do
                if a:IsA("Animator") then a:Destroy() end
            end
            task.wait()
            -- Создаём наш и заливаем невалидные треки
            local anim = Instance.new("Animator")
            anim.Parent = target
            for i = 1, 50 do
                pcall(function()
                    local a = Instance.new("Animation")
                    a.AnimationId = "rbxassetid://" .. tostring(math.random(1, 999999999))
                    local tr = anim:LoadAnimation(a)
                    tr.Priority = Enum.AnimationPriority.Action4
                    tr:Play()
                    tr:AdjustSpeed(math.huge)
                    tr:AdjustWeight(math.huge)
                end)
            end
            task.wait(0.1)
            local h = o:FindFirstChildOfClass("Humanoid")
            if h then h:TakeDamage(math.huge); h.Health = 0 end
        end)
    end)
end
registerMethod(168, "CustomRigs", "168. 🎯 Animator Eval Poison", "Свой Animator + 50 невалидных tracks", m_168)

-- 🎯 169. HUMANOID PARENTAGE FLIP — быстрая смена Parent'а Humanoid
-- Идея: Humanoid.Parent = nil на 1 кадр → у сервера сбивается state machine.
-- Пока Humanoid orphaned, наносим урон, потом возвращаем — сервер применяет
-- накопленный урон когда Humanoid вернётся, но без проверок защиты.
local function m_169(o)
    claimFE(o)
    local h = o:FindFirstChildOfClass("Humanoid"); if not h then return end
    if not throttled(169, o, 3) then return end
    print("[🎯 169] Humanoid Parentage Flip:", o.Name)
    task.spawn(function()
        pcall(function()
            local origParent = h.Parent
            h.Parent = nil
            task.wait()
            -- Пока Humanoid orphaned, копим урон в attributes
            for i = 1, 20 do
                pcall(function() h.Health = 0; h:TakeDamage(math.huge) end)
            end
            task.wait()
            -- Возвращаем — сервер должен применить всё что накопили
            h.Parent = origParent
            task.wait()
            h:ChangeState(Enum.HumanoidStateType.Dead)
            h.Health = 0
        end)
    end)
end
registerMethod(169, "FEClassic", "169. 🎯 Humanoid Parent Flip", "Humanoid.Parent=nil→урон→возврат", m_169)

-- 🎯 170. CAMERA SUBJECT HIJACK — переключаем cam.CameraSubject на босса
-- Идея: некоторые игры валидируют input через camera subject. Если наш
-- cam.CameraSubject = boss.Humanoid, то система думает что мы «управляем»
-- боссом → атаки от нашего имени идут через его пайплайн.
local function m_170(o)
    if not throttled(170, o, 5) then return end
    local h = o:FindFirstChildOfClass("Humanoid"); if not h then return end
    local origSubject = cam.CameraSubject
    print("[🎯 170] Camera Subject Hijack:", o.Name)
    task.spawn(function()
        pcall(function()
            cam.CameraSubject = h
            cam.CameraType = Enum.CameraType.Custom
            task.wait(0.1)
            -- Пока камера «внутри» босса, шлём атаки
            for _,r in ipairs(DeepAnalysisData.CombatRemotes) do
                pcall(function() if r:IsA("RemoteEvent") then r:FireServer(o, 999999); r:FireServer("SelfDamage", 999999) end end)
            end
            h:TakeDamage(math.huge); h.Health = 0
            task.wait(0.5)
            cam.CameraSubject = origSubject
        end)
    end)
end
registerMethod(170, "RemotesWeapons", "170. 🎯 Camera Subject Hijack", "cam.CameraSubject=boss.Humanoid", m_170)

-- 🎯 171. VELOCITY-BASED KNOCKBACK OVERFLOW — накопление AssemblyLinearVelocity
-- Идея: если ставить AssemblyLinearVelocity каждый кадр с накоплением, физ.движок
-- сходит с ума. Плюс это выглядит для сервера как «легитимное движение», не
-- проверяется античитом.
local function m_171(o)
    claimFE(o)
    if not throttled(171, o, 2) then return end
    local r = getRootPart(o); if not r then return end
    print("[🎯 171] Velocity Knockback Overflow:", o.Name)
    task.spawn(function()
        for tick = 1, 30 do
            if not o.Parent then break end
            pcall(function()
                -- Накапливаем velocity в разные оси быстро сменяющиеся
                local angle = tick * 0.5
                r.AssemblyLinearVelocity = Vector3.new(math.sin(angle)*1e6, math.cos(angle)*1e6, math.sin(angle*2)*1e6)
                r.AssemblyAngularVelocity = Vector3.new(math.cos(angle)*1e5, math.sin(angle)*1e5, math.cos(angle*2)*1e5)
            end)
            rs.Heartbeat:Wait()
        end
        -- После физической бури — доудар
        local h = o:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Physics); h.Health = 0 end) end
    end)
end
registerMethod(171, "CustomRigs", "171. 🎯 Velocity Knockback OF", "Осцилляция velocity 1e6", m_171)

-- 🎯 172. FIREPROXIMITYPROMPT RECURSIVE — рекурсивный вызов через хук
-- Идея: если у босса есть ProximityPrompt.Triggered событие, мы хукаем его
-- OnServerEvent через клиента и триггерим 1000 раз. Каждый триггер — это
-- отдельный remote вызов, что забивает handler.
local function m_172(o)
    if not fireproximityprompt then return end
    if not throttled(172, o, 3) then return end
    print("[🎯 172] Proximity Recursive:", o.Name)
    task.spawn(function()
        local prompts = {}
        for _,d in ipairs(o:GetDescendants()) do
            if d:IsA("ProximityPrompt") then table.insert(prompts, d) end
        end
        -- Плюс близлежащие prompts на карте
        local r = getRootPart(o)
        if r then
            for _,d in ipairs(ws:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Parent and d.Parent:IsA("BasePart") and (d.Parent.Position - r.Position).Magnitude < 50 then
                    table.insert(prompts, d)
                end
            end
        end
        if #prompts == 0 then print("[172] Нет ProximityPrompt"); return end
        -- Триггерим 500 раз пачками
        for wave = 1, 10 do
            for _,p in ipairs(prompts) do
                for i = 1, 5 do
                    pcall(function() fireproximityprompt(p) end)
                end
            end
            task.wait(0.05)
        end
    end)
end
registerMethod(172, "PlayerInputSim", "172. 🎯 PP Recursive 500x", "500 fireproximityprompt пачками", m_172)

-- 🎯 173. HUMANOID DIED MANUAL FIRE — прямой вызов Died signal через getconnections
-- Идея: если executor поддерживает getconnections, мы можем достать все
-- функции подключённые к Humanoid.Died и вручную их вызвать. Игровые скрипты
-- в этих обработчиках выдают награду/спавнят death effect + удаляют босса.
local function m_173(o)
    local h = o:FindFirstChildOfClass("Humanoid"); if not h then return end
    if not throttled(173, o, 3) then return end
    print("[🎯 173] Died Signal Manual Fire:", o.Name)
    pcall(function()
        if getconnections then
            local conns = getconnections(h.Died)
            print("[173] Died connections:", #conns)
            for _, c in ipairs(conns) do
                pcall(function() if c.Fire then c:Fire() elseif c.Function then c.Function() end end)
            end
        end
        -- Также по HealthChanged (0 = смерть)
        if getconnections then
            local conns2 = getconnections(h.HealthChanged)
            for _, c in ipairs(conns2) do
                pcall(function() if c.Fire then c:Fire(0) end end)
            end
        end
        h.Health = 0
    end)
end
registerMethod(173, "FEClassic", "173. 🎯 Died Manual Fire", "getconnections(Died)+вызов вручную", m_173)

-- 🎯 174. TOOL GRIP CFRAME OVERSHOOT — Tool.Grip с гигантским смещением
-- Идея: Tool.Grip определяет где Handle относительно руки. Если ставить
-- Grip = CFrame.new(0, 0, -1000), то Handle вылетает на 1000 units → его
-- hitbox касается всего в этом радиусе, включая босса.
local function m_174(o)
    local c = lp.Character; if not c then return end
    local t = c:FindFirstChildOfClass("Tool") or lp.Backpack:FindFirstChildOfClass("Tool"); if not t then return end
    if t.Parent ~= c then t.Parent = c end
    local r = getRootPart(o); if not r then return end
    if not throttled(174, o, 2) then return end
    print("[🎯 174] Tool Grip Overshoot:", o.Name)
    task.spawn(function()
        local origGrip = t.Grip
        pcall(function()
            local myR = c:FindFirstChild("HumanoidRootPart")
            if myR then
                local dir = (r.Position - myR.Position)
                local dist = dir.Magnitude
                -- Ставим Grip так, чтобы Handle оказался прямо в боссе
                t.Grip = CFrame.new(0, 0, -dist) * CFrame.Angles(0, 0, 0)
            end
            -- Активируем tool 10 раз
            for i = 1, 10 do
                pcall(function() t:Activate() end)
                local h = t:FindFirstChild("Handle")
                if h and firetouchinterest then firetouchinterest(h, r, 0); firetouchinterest(h, r, 1) end
                task.wait(0.08)
            end
        end)
        pcall(function() t.Grip = origGrip end)
    end)
end
registerMethod(174, "RemotesWeapons", "174. 🎯 Tool Grip Overshoot", "Grip CFrame -distance до NPC", m_174)

-- 🎯 175. HUMANOID:BUILDRIGFROMATTACHMENTS EXPLOIT
-- Идея: BuildRigFromAttachments пересобирает rig на основе Attachments.
-- Если предварительно испортить Attachments (переместить в невалидные места),
-- пересборка сломает rig окончательно.
local function m_175(o)
    claimFE(o)
    local h = o:FindFirstChildOfClass("Humanoid"); if not h then return end
    if not throttled(175, o, 3) then return end
    print("[🎯 175] BuildRig Exploit:", o.Name)
    task.spawn(function()
        pcall(function()
            -- Испорчиваем все Attachments
            local atts = getCached(o).atts
            for _,att in ipairs(atts) do
                pcall(function() att.CFrame = CFrame.new(math.random(-1e5,1e5), math.random(-1e5,1e5), math.random(-1e5,1e5)) end)
            end
            task.wait()
            -- Форсим пересборку rig
            pcall(function() h:BuildRigFromAttachments() end)
            task.wait(0.05)
            -- Повторяем 3 раза — каждая пересборка ломает больше
            for i = 1, 3 do
                for _,att in ipairs(atts) do
                    pcall(function() att.CFrame = CFrame.new(math.random(-1e5,1e5), math.random(-1e5,1e5), math.random(-1e5,1e5)) end)
                end
                pcall(function() h:BuildRigFromAttachments() end)
                task.wait(0.05)
            end
            h:TakeDamage(math.huge); h.Health = 0
        end)
    end)
end
registerMethod(175, "CustomRigs", "175. 🎯 BuildRig Exploit", "Испорченный BuildRigFromAttachments", m_175)

-- 🎯 176. REPLICATION FOCUS SWAMP — spawn 100 фиктивных Parts вокруг босса
-- Идея: сервер должен реплицировать все изменения parts вокруг игроков.
-- Если насыпать 100 Parts вокруг босса с меняющимися свойствами, сервер
-- перегружается replication буфером и не успевает валидировать boss HP.
local function m_176(o)
    if not throttled(176, o, 4) then return end
    local r = getRootPart(o); if not r then return end
    print("[🎯 176] Replication Focus Swamp:", o.Name)
    task.spawn(function()
        local parts = {}
        pcall(function()
            for i = 1, 50 do
                local p = Instance.new("Part")
                p.Size = Vector3.new(0.1, 0.1, 0.1)
                p.Anchored = false
                p.CanCollide = false
                p.Massless = true
                p.Transparency = 1
                p.CFrame = r.CFrame + Vector3.new(math.random(-5,5), math.random(-5,5), math.random(-5,5))
                p.Parent = ws
                table.insert(parts, p)
            end
        end)
        -- Хаотично меняем свойства чтобы забить replication buffer
        for tick = 1, 15 do
            if not o.Parent then break end
            for _,p in ipairs(parts) do
                pcall(function()
                    if p and p.Parent then
                        p.CFrame = r.CFrame + Vector3.new(math.random(-3,3), math.random(-3,3), math.random(-3,3))
                        p.Color = Color3.new(math.random(), math.random(), math.random())
                        p.Material = Enum.Material.Plastic
                    end
                end)
            end
            -- В окне перегрузки — атака
            local h = o:FindFirstChildOfClass("Humanoid")
            if h then pcall(function() h:TakeDamage(math.huge) end) end
            task.wait(0.05)
        end
        -- Cleanup
        for _,p in ipairs(parts) do pcall(function() p:Destroy() end) end
    end)
end
registerMethod(176, "RemotesWeapons", "176. 🎯 Replication Swamp 50pt", "50 фиктивных Parts→перегруз", m_176)

-- Anti-rollback helper
local function antiRollback(o)
    local h = o:FindFirstChildOfClass("Humanoid"); if not h then return end
    if rollbackGuards[o] then rollbackGuards[o]:Disconnect() end
    local last = h.Health
    rollbackGuards[o] = h:GetPropertyChangedSignal("Health"):Connect(function()
        local cur = h.Health
        if cur > last + 5 then pcall(function() h.Health = math.max(0, last - 100) end)
        else last = cur end
    end)
    task.delay(20, function() if rollbackGuards[o] then rollbackGuards[o]:Disconnect(); rollbackGuards[o]=nil end end)
end

-- ============================================================================
-- 💥 МАСТЕР-ДВИЖОК v41 (оптимизирован — batching)
-- ============================================================================
local function MASTER_KILL(o)
    if not o or not o.Parent then return end
    claimFE(o)
    task.spawn(function() antiRollback(o) end)
    local ticks = CombatSettings.HyperSpeed and 8 or 15  -- было 30
    local wt = CombatSettings.HyperSpeed and 0.03 or 0.06  -- было 0.03
    task.spawn(function()
        for tick = 1, ticks do
            if not o.Parent then break end
            for _, m in ipairs(MethodRegistry) do
                if CastEnabled[m.cast] and MethodEnabled[m.id] then
                    -- Тяжёлые методы только на 1м и последнем tick
                    local heavy = (m.id == 128 or m.id == 149 or m.id == 155 or m.id == 145 or m.id == 158 or m.id == 161 or m.id == 163 or m.id == 165 or m.id == 166)
                    if not heavy or tick == 1 then
                        task.spawn(function() pcall(function() m.fn(o) end) end)
                    end
                end
            end
            task.wait(wt)
        end
    end)
end

local function NUCLEAR(o)
    if not o or not o.Parent then return end
    claimFE(o); task.spawn(function() antiRollback(o) end)
    task.spawn(function()
        for wave = 1, 2 do
            if not o.Parent then break end
            for _, m in ipairs(MethodRegistry) do
                task.spawn(function() pcall(function() m.fn(o) end) end)
            end
            task.wait(0.7)
        end
    end)
end

-- ============================================================================
-- 🎨 КОМПАКТНЫЙ GUI v41 (480×540 — было 820×920)
-- ============================================================================
local sg = Instance.new("ScreenGui")
sg.Name = "NPCKillTesterPro_v41"; sg.ResetOnSpawn = false
pcall(function() sg.Parent = game:GetService("CoreGui") end)
if not sg.Parent then sg.Parent = lp:WaitForChild("PlayerGui") end

local mf = Instance.new("Frame", sg)
mf.Size = UDim2.new(0, 480, 0, 540)
mf.Position = UDim2.new(0.5, -240, 0.5, -270)
mf.BackgroundColor3 = Color3.fromRGB(16,16,20)
mf.BorderSizePixel = 0; mf.Active = true; mf.Draggable = true
Instance.new("UICorner", mf).CornerRadius = UDim.new(0,10)

-- Заголовок
local title = Instance.new("TextLabel", mf)
title.Size = UDim2.new(1, -70, 0, 30)
title.Text = "  👑 KILL v42.0 (20 тестов)"
title.TextColor3 = Color3.fromRGB(255,255,255); title.Font = Enum.Font.GothamBold; title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left; title.BackgroundColor3 = Color3.fromRGB(10,10,12)
Instance.new("UICorner", title).CornerRadius = UDim.new(0,10)

local minBtn = Instance.new("TextButton", mf); minBtn.Size = UDim2.new(0,30,0,28); minBtn.Position = UDim2.new(1,-64,0,1)
minBtn.Text = "-"; minBtn.Font = Enum.Font.GothamBold; minBtn.TextSize = 18; minBtn.TextColor3 = Color3.fromRGB(255,255,255); minBtn.BackgroundColor3 = Color3.fromRGB(35,35,45)
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0,8)

local unloadBtn = Instance.new("TextButton", mf); unloadBtn.Size = UDim2.new(0,30,0,28); unloadBtn.Position = UDim2.new(1,-32,0,1)
unloadBtn.Text = "X"; unloadBtn.Font = Enum.Font.GothamBold; unloadBtn.TextSize = 14; unloadBtn.TextColor3 = Color3.fromRGB(255,180,180); unloadBtn.BackgroundColor3 = Color3.fromRGB(90,25,25)
Instance.new("UICorner", unloadBtn).CornerRadius = UDim.new(0,8)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then mf:TweenSize(UDim2.new(0,480,0,32), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.25, true); minBtn.Text = "+"
        for _,v in ipairs(mf:GetChildren()) do if v:IsA("GuiObject") and v~=title and v~=minBtn and v~=unloadBtn then v.Visible=false end end
    else mf:TweenSize(UDim2.new(0,480,0,540), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.25, true); minBtn.Text = "-"
        for _,v in ipairs(mf:GetChildren()) do if v:IsA("GuiObject") and v~=title and v~=minBtn and v~=unloadBtn then v.Visible=true end end
    end
end)

-- 3 главные кнопки (компактные)
local actF = Instance.new("Frame", mf)
actF.Size = UDim2.new(1,-10,0,40); actF.Position = UDim2.new(0,5,0,34); actF.BackgroundTransparency = 1

local killBtn = Instance.new("TextButton", actF)
killBtn.Size = UDim2.new(0.33,-2,1,0); killBtn.Position = UDim2.new(0,0,0,0)
killBtn.Text = "💥 MASTER"; killBtn.Font = Enum.Font.GothamBold; killBtn.TextSize = 12
killBtn.TextColor3 = Color3.fromRGB(255,255,255); killBtn.BackgroundColor3 = Color3.fromRGB(10,140,60)
Instance.new("UICorner", killBtn).CornerRadius = UDim.new(0,6)
killBtn.MouseButton1Click:Connect(function()
    local t = getTargets(); if #t==0 then print("[WARN] Выберите цель"); return end
    for _,o in ipairs(t) do task.spawn(function() MASTER_KILL(o) end) end
end)

local killAllBtn = Instance.new("TextButton", actF)
killAllBtn.Size = UDim2.new(0.33,-2,1,0); killAllBtn.Position = UDim2.new(0.335,0,0,0)
killAllBtn.Text = "⚡ ALL"; killAllBtn.Font = Enum.Font.GothamBold; killAllBtn.TextSize = 12
killAllBtn.TextColor3 = Color3.fromRGB(255,255,0); killAllBtn.BackgroundColor3 = Color3.fromRGB(160,30,0)
Instance.new("UICorner", killAllBtn).CornerRadius = UDim.new(0,6)
killAllBtn.MouseButton1Click:Connect(function()
    task.spawn(function() for i,o in ipairs(getAllNPCs()) do task.spawn(function() MASTER_KILL(o) end); if i%3==0 then task.wait(0.05) end end end)
end)

local nucBtn = Instance.new("TextButton", actF)
nucBtn.Size = UDim2.new(0.33,-2,1,0); nucBtn.Position = UDim2.new(0.67,0,0,0)
nucBtn.Text = "🔥 NUCLEAR"; nucBtn.Font = Enum.Font.GothamBold; nucBtn.TextSize = 12
nucBtn.TextColor3 = Color3.fromRGB(255,255,255); nucBtn.BackgroundColor3 = Color3.fromRGB(200,20,20)
Instance.new("UICorner", nucBtn).CornerRadius = UDim.new(0,6)
nucBtn.MouseButton1Click:Connect(function()
    local t = getTargets(); if #t==0 then t = getAllNPCs() end
    for _,o in ipairs(t) do task.spawn(function() NUCLEAR(o) end) end
end)

-- Табы (компактные)
local TabBar = Instance.new("Frame", mf)
TabBar.Size = UDim2.new(1,-10,0,26); TabBar.Position = UDim2.new(0,5,0,78); TabBar.BackgroundTransparency = 1

local tabPanels = {}
local currentTab = "casts"
local function makeTabBtn(id, label, x, w)
    local b = Instance.new("TextButton", TabBar)
    b.Size = UDim2.new(w,-2,1,0); b.Position = UDim2.new(x,0,0,0)
    b.Text = label; b.Font = Enum.Font.GothamBold; b.TextSize = 11
    b.TextColor3 = Color3.fromRGB(255,255,255); b.BackgroundColor3 = (id==currentTab) and Color3.fromRGB(60,100,140) or Color3.fromRGB(40,40,55)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,5)
    b.MouseButton1Click:Connect(function()
        currentTab = id
        for pid, p in pairs(tabPanels) do p.Visible = (pid == id) end
        for _, ch in ipairs(TabBar:GetChildren()) do
            if ch:IsA("TextButton") then ch.BackgroundColor3 = Color3.fromRGB(40,40,55) end
        end
        b.BackgroundColor3 = Color3.fromRGB(60,100,140)
    end)
    return b
end

makeTabBtn("casts",    "⚙️ Настройки", 0,    0.34)
makeTabBtn("tests",    "🧪 Тесты v41", 0.34, 0.33)
makeTabBtn("npcs",     "📋 NPC",       0.67, 0.33)

-- Панели табов (общая область под табами)
local panelArea = Instance.new("Frame", mf)
panelArea.Size = UDim2.new(1,-10,1,-116); panelArea.Position = UDim2.new(0,5,0,108); panelArea.BackgroundTransparency = 1

-- ================== ТАБ 1: НАСТРОЙКИ ==================
local castsPanel = Instance.new("Frame", panelArea)
castsPanel.Size = UDim2.new(1,0,1,0); castsPanel.BackgroundTransparency = 1
castsPanel.Visible = true
tabPanels.casts = castsPanel

local castsScroll = Instance.new("ScrollingFrame", castsPanel)
castsScroll.Size = UDim2.new(1,-4,1,-38); castsScroll.Position = UDim2.new(0,0,0,0)
castsScroll.BackgroundTransparency = 1; castsScroll.ScrollBarThickness = 4
castsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; castsScroll.CanvasSize = UDim2.new(0,0,0,0)

local castsList = Instance.new("UIListLayout", castsScroll)
castsList.Padding = UDim.new(0,2); castsList.SortOrder = Enum.SortOrder.LayoutOrder

local CastInfo = {
    {key="GoldenGrail",    icon="👑", label="Golden Grail",    color=Color3.fromRGB(180,140,0)},
    {key="RemotesWeapons", icon="📡", label="Remotes+Weapons", color=Color3.fromRGB(0,100,160)},
    {key="CustomRigs",     icon="🦾", label="Custom Rigs",     color=Color3.fromRGB(160,80,0)},
    {key="FEClassic",      icon="🩸", label="FE Classic",      color=Color3.fromRGB(120,40,40)},
    {key="MathStats",      icon="📊", label="Math Stats",      color=Color3.fromRGB(100,20,100)},
    {key="PlayerInputSim", icon="🎮", label="Input Sim",       color=Color3.fromRGB(0,140,140)},
    {key="DestroyerServer",icon="🚀", label="Destroyer",       color=Color3.fromRGB(180,20,0)},
}

local function createCast(info, order)
    local wrap = Instance.new("Frame", castsScroll)
    wrap.Size = UDim2.new(1,-6,0,26); wrap.BackgroundTransparency = 1
    wrap.LayoutOrder = order; wrap.AutomaticSize = Enum.AutomaticSize.Y

    local hdr = Instance.new("TextButton", wrap)
    hdr.Size = UDim2.new(1,0,0,26); hdr.Text = ""
    hdr.BackgroundColor3 = CastEnabled[info.key] and info.color or Color3.fromRGB(45,45,55)
    hdr.AutoButtonColor = false
    Instance.new("UICorner", hdr).CornerRadius = UDim.new(0,5)

    local arr = Instance.new("TextLabel", hdr); arr.Size = UDim2.new(0,20,1,0); arr.Position = UDim2.new(0,3,0,0)
    arr.Text = "▶"; arr.Font = Enum.Font.GothamBold; arr.TextSize = 12; arr.TextColor3 = Color3.fromRGB(255,255,255); arr.BackgroundTransparency = 1

    local lbl = Instance.new("TextLabel", hdr); lbl.Size = UDim2.new(1,-90,1,0); lbl.Position = UDim2.new(0,25,0,0)
    lbl.Text = info.icon.." "..info.label; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11
    lbl.TextColor3 = Color3.fromRGB(255,255,255); lbl.BackgroundTransparency = 1; lbl.TextXAlignment = Enum.TextXAlignment.Left

    local tog = Instance.new("TextButton", hdr); tog.Size = UDim2.new(0,60,0,18); tog.Position = UDim2.new(1,-64,0,4)
    tog.Text = CastEnabled[info.key] and "ON" or "OFF"; tog.Font = Enum.Font.GothamBold; tog.TextSize = 9
    tog.TextColor3 = Color3.fromRGB(255,255,255); tog.BackgroundColor3 = CastEnabled[info.key] and Color3.fromRGB(40,120,40) or Color3.fromRGB(120,40,40)
    Instance.new("UICorner", tog).CornerRadius = UDim.new(0,4)
    tog.MouseButton1Click:Connect(function()
        CastEnabled[info.key] = not CastEnabled[info.key]
        tog.Text = CastEnabled[info.key] and "ON" or "OFF"
        tog.BackgroundColor3 = CastEnabled[info.key] and Color3.fromRGB(40,120,40) or Color3.fromRGB(120,40,40)
        hdr.BackgroundColor3 = CastEnabled[info.key] and info.color or Color3.fromRGB(45,45,55)
    end)

    local sub = Instance.new("Frame", wrap)
    sub.Size = UDim2.new(1,-14,0,0); sub.Position = UDim2.new(0,14,0,28)
    sub.BackgroundColor3 = Color3.fromRGB(24,24,32); sub.Visible = false; sub.AutomaticSize = Enum.AutomaticSize.Y
    Instance.new("UICorner", sub).CornerRadius = UDim.new(0,4)
    local sl = Instance.new("UIListLayout", sub); sl.Padding = UDim.new(0,1)
    local pd = Instance.new("UIPadding", sub); pd.PaddingLeft = UDim.new(0,4); pd.PaddingRight = UDim.new(0,4); pd.PaddingTop = UDim.new(0,4); pd.PaddingBottom = UDim.new(0,4)

    for _, method in ipairs(MethodRegistry) do
        if method.cast == info.key then
            local mb = Instance.new("TextButton", sub)
            mb.Size = UDim2.new(1,-6,0,20); mb.Text = ""
            mb.BackgroundColor3 = MethodEnabled[method.id] and Color3.fromRGB(35,70,45) or Color3.fromRGB(50,35,35)
            mb.AutoButtonColor = false
            Instance.new("UICorner", mb).CornerRadius = UDim.new(0,3)
            local st = Instance.new("TextLabel", mb); st.Size = UDim2.new(0,20,1,0); st.Position = UDim2.new(0,3,0,0)
            st.Text = MethodEnabled[method.id] and "✅" or "❌"; st.Font = Enum.Font.GothamBold; st.TextSize = 10
            st.TextColor3 = Color3.fromRGB(255,255,255); st.BackgroundTransparency = 1
            local nl = Instance.new("TextLabel", mb); nl.Size = UDim2.new(1,-25,1,0); nl.Position = UDim2.new(0,25,0,0)
            nl.Text = method.name; nl.Font = Enum.Font.GothamBold; nl.TextSize = 9
            nl.TextColor3 = Color3.fromRGB(255,255,255); nl.BackgroundTransparency = 1; nl.TextXAlignment = Enum.TextXAlignment.Left
            mb.MouseButton1Click:Connect(function()
                MethodEnabled[method.id] = not MethodEnabled[method.id]
                st.Text = MethodEnabled[method.id] and "✅" or "❌"
                mb.BackgroundColor3 = MethodEnabled[method.id] and Color3.fromRGB(35,70,45) or Color3.fromRGB(50,35,35)
            end)
        end
    end

    hdr.MouseButton1Click:Connect(function() sub.Visible = not sub.Visible; arr.Text = sub.Visible and "▼" or "▶" end)
end

for i, info in ipairs(CastInfo) do createCast(info, i) end

-- Регулировки (компактно в низу)
local regF = Instance.new("Frame", castsPanel)
regF.Size = UDim2.new(1,-4,0,34); regF.Position = UDim2.new(0,0,1,-34); regF.BackgroundTransparency = 1

local akBtn = Instance.new("TextButton", regF)
akBtn.Size = UDim2.new(0.34,-2,1,0); akBtn.Position = UDim2.new(0,0,0,0)
akBtn.Text = "🛡️ AntiKick OFF"; akBtn.Font = Enum.Font.GothamBold; akBtn.TextSize = 10
akBtn.TextColor3 = Color3.fromRGB(255,255,255); akBtn.BackgroundColor3 = Color3.fromRGB(45,45,55)
Instance.new("UICorner", akBtn).CornerRadius = UDim.new(0,5)
local akSt = false
akBtn.MouseButton1Click:Connect(function() akSt = not akSt; AntiKickPro:Toggle(akSt); akBtn.Text = "🛡️ AntiKick "..(akSt and "ON" or "OFF"); akBtn.BackgroundColor3 = akSt and Color3.fromRGB(0,180,120) or Color3.fromRGB(45,45,55) end)

local dV = { 5000, 50000, 500000, 999999, math.huge }; local dN = { "5K","50K","500K","999K","MAX" }; local dI = 2
local dmgBtn = Instance.new("TextButton", regF)
dmgBtn.Size = UDim2.new(0.33,-2,1,0); dmgBtn.Position = UDim2.new(0.34,0,0,0)
dmgBtn.Text = "⚙️ DMG: "..dN[dI]; dmgBtn.Font = Enum.Font.GothamBold; dmgBtn.TextSize = 10
dmgBtn.TextColor3 = Color3.fromRGB(255,255,255); dmgBtn.BackgroundColor3 = Color3.fromRGB(0,120,80)
Instance.new("UICorner", dmgBtn).CornerRadius = UDim.new(0,5)
dmgBtn.MouseButton1Click:Connect(function() dI = (dI%#dV)+1; CombatSettings.DamageAmount = dV[dI]; dmgBtn.Text = "⚙️ DMG: "..dN[dI] end)

local spdBtn = Instance.new("TextButton", regF)
spdBtn.Size = UDim2.new(0.33,-2,1,0); spdBtn.Position = UDim2.new(0.67,0,0,0)
spdBtn.Text = "⚙️ 15x"; spdBtn.Font = Enum.Font.GothamBold; spdBtn.TextSize = 10
spdBtn.TextColor3 = Color3.fromRGB(255,255,255); spdBtn.BackgroundColor3 = Color3.fromRGB(60,60,80)
Instance.new("UICorner", spdBtn).CornerRadius = UDim.new(0,5)
spdBtn.MouseButton1Click:Connect(function() CombatSettings.HyperSpeed = not CombatSettings.HyperSpeed; spdBtn.Text = CombatSettings.HyperSpeed and "⚙️ 8x HYPER" or "⚙️ 15x"; spdBtn.BackgroundColor3 = CombatSettings.HyperSpeed and Color3.fromRGB(120,40,160) or Color3.fromRGB(60,60,80) end)

-- ================== ТАБ 2: ТЕСТЫ (только новые 157-166) ==================
local testsPanel = Instance.new("Frame", panelArea)
testsPanel.Size = UDim2.new(1,0,1,0); testsPanel.BackgroundTransparency = 1
testsPanel.Visible = false
tabPanels.tests = testsPanel

local TEST_MIN_ID = 157
local testScroll = Instance.new("ScrollingFrame", testsPanel)
testScroll.Size = UDim2.new(1,-4,1,0); testScroll.BackgroundTransparency = 1; testScroll.ScrollBarThickness = 4
testScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; testScroll.CanvasSize = UDim2.new(0,0,0,0)
local testList = Instance.new("UIListLayout", testScroll); testList.Padding = UDim.new(0,3)

for _, method in ipairs(MethodRegistry) do
    if method.id >= TEST_MIN_ID then
        local b = Instance.new("TextButton", testScroll)
        b.Size = UDim2.new(1,-6,0,38); b.Text = ""
        local ci; for _,c in ipairs(CastInfo) do if c.key==method.cast then ci=c; break end end
        b.BackgroundColor3 = ci and ci.color or Color3.fromRGB(45,45,55)
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,5)
        local t1 = Instance.new("TextLabel", b); t1.Size = UDim2.new(1,-8,0,18); t1.Position = UDim2.new(0,4,0,2)
        t1.Text = method.name; t1.Font = Enum.Font.GothamBold; t1.TextSize = 11
        t1.TextColor3 = Color3.fromRGB(255,255,255); t1.BackgroundTransparency = 1; t1.TextXAlignment = Enum.TextXAlignment.Left
        local t2 = Instance.new("TextLabel", b); t2.Size = UDim2.new(1,-8,0,16); t2.Position = UDim2.new(0,4,0,20)
        t2.Text = method.desc; t2.Font = Enum.Font.SourceSans; t2.TextSize = 10
        t2.TextColor3 = Color3.fromRGB(230,230,240); t2.BackgroundTransparency = 1; t2.TextXAlignment = Enum.TextXAlignment.Left
        b.MouseButton1Click:Connect(function()
            local t = getTargets(); if #t==0 then print("[WARN] Выберите цель"); return end
            for _,o in ipairs(t) do task.spawn(function() pcall(function() method.fn(o) end) end) end
        end)
    end
end

-- ================== ТАБ 3: NPC ==================
local npcsPanel = Instance.new("Frame", panelArea)
npcsPanel.Size = UDim2.new(1,0,1,0); npcsPanel.BackgroundTransparency = 1
npcsPanel.Visible = false
tabPanels.npcs = npcsPanel

-- Мини-заголовок с кнопками
local npcHdr = Instance.new("Frame", npcsPanel)
npcHdr.Size = UDim2.new(1,-4,0,24); npcHdr.BackgroundColor3 = Color3.fromRGB(28,28,38)
Instance.new("UICorner", npcHdr).CornerRadius = UDim.new(0,4)

local selAll = Instance.new("TextButton", npcHdr); selAll.Size = UDim2.new(0,50,0,18); selAll.Position = UDim2.new(1,-104,0,3)
selAll.Text = "✅ Все"; selAll.Font = Enum.Font.SourceSansBold; selAll.TextSize = 10
selAll.BackgroundColor3 = Color3.fromRGB(40,90,40); selAll.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", selAll).CornerRadius = UDim.new(0,3)

local desel = Instance.new("TextButton", npcHdr); desel.Size = UDim2.new(0,50,0,18); desel.Position = UDim2.new(1,-52,0,3)
desel.Text = "❌ Сбр"; desel.Font = Enum.Font.SourceSansBold; desel.TextSize = 10
desel.BackgroundColor3 = Color3.fromRGB(90,40,40); desel.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", desel).CornerRadius = UDim.new(0,3)

local npcCount = Instance.new("TextLabel", npcHdr); npcCount.Size = UDim2.new(1,-110,1,0); npcCount.Position = UDim2.new(0,5,0,0)
npcCount.Text = "  Найдено NPC: 0"; npcCount.Font = Enum.Font.GothamBold; npcCount.TextSize = 10
npcCount.TextColor3 = Color3.fromRGB(150,255,150); npcCount.BackgroundTransparency = 1; npcCount.TextXAlignment = Enum.TextXAlignment.Left

local npcS = Instance.new("ScrollingFrame", npcsPanel)
npcS.Size = UDim2.new(1,-4,1,-28); npcS.Position = UDim2.new(0,0,0,28)
npcS.BackgroundTransparency = 1; npcS.ScrollBarThickness = 4; npcS.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UIListLayout", npcS).Padding = UDim.new(0,2)

selAll.MouseButton1Click:Connect(function()
    for _,o in ipairs(getAllNPCs()) do
        selectedNPCs[o] = true
        if not o:FindFirstChild("_HL") then local h=Instance.new("Highlight",o); h.Name="_HL"; h.FillColor=Color3.fromRGB(0,255,0); h.FillTransparency=0.65; highlights[o]=h end
    end
end)
desel.MouseButton1Click:Connect(function() for o,_ in pairs(selectedNPCs) do if o and o.Parent then local h=o:FindFirstChild("_HL"); if h then h:Destroy() end end end; selectedNPCs={}; currentNPC=nil end)

local npcButtons = {}
local function refreshNPCs()
    for _,c in ipairs(npcS:GetChildren()) do if c:IsA("TextButton") or c:IsA("Frame") then c:Destroy() end end
    npcButtons = {}
    local ents = getAllNPCs()
    npcCount.Text = "  Найдено NPC: "..#ents
    title.Text = "  👑 KILL v42.0 ("..#ents.." NPC | "..#MethodRegistry.." методов)"
    for _,o in ipairs(ents) do
        local ok, et, hp, root = analyzeEntity(o)
        if ok and root then
            local b = Instance.new("TextButton", npcS)
            b.Size = UDim2.new(1,-4,0,20); b.Text = ""
            b.BackgroundColor3 = selectedNPCs[o] and Color3.fromRGB(20,90,30) or Color3.fromRGB(32,32,42)
            Instance.new("UICorner", b).CornerRadius = UDim.new(0,3)
            local n = Instance.new("TextLabel", b); n.Size = UDim2.new(0.5,0,1,0); n.Position = UDim2.new(0,4,0,0)
            n.Text = o.Name; n.Font = Enum.Font.GothamBold; n.TextSize = 10; n.TextColor3 = Color3.fromRGB(255,255,255)
            n.BackgroundTransparency = 1; n.TextXAlignment = Enum.TextXAlignment.Left
            local tl = Instance.new("TextLabel", b); tl.Size = UDim2.new(0.2,0,1,0); tl.Position = UDim2.new(0.5,0,0,0)
            tl.Text = et; tl.Font = Enum.Font.SourceSans; tl.TextSize = 10; tl.TextColor3 = Color3.fromRGB(180,220,255); tl.BackgroundTransparency = 1
            local hl = Instance.new("TextLabel", b); hl.Size = UDim2.new(0.2,0,1,0); hl.Position = UDim2.new(0.7,0,0,0)
            hl.Text = hp; hl.Font = Enum.Font.SourceSans; hl.TextSize = 10; hl.TextColor3 = Color3.fromRGB(150,255,150); hl.BackgroundTransparency = 1
            local ow = Instance.new("TextLabel", b); ow.Size = UDim2.new(0.1,0,1,0); ow.Position = UDim2.new(0.9,0,0,0)
            ow.Text = checkOwner(root); ow.Font = Enum.Font.GothamBold; ow.TextSize = 10; ow.TextColor3 = Color3.fromRGB(200,200,200); ow.BackgroundTransparency = 1
            b.MouseButton1Click:Connect(function()
                if selectedNPCs[o] then
                    selectedNPCs[o]=nil; b.BackgroundColor3 = Color3.fromRGB(32,32,42)
                    local h=o:FindFirstChild("_HL"); if h then h:Destroy() end
                else
                    selectedNPCs[o]=true; currentNPC=o; b.BackgroundColor3 = Color3.fromRGB(20,90,30)
                    if not o:FindFirstChild("_HL") then local h=Instance.new("Highlight",o); h.Name="_HL"; h.FillColor=Color3.fromRGB(0,255,0); h.FillTransparency=0.65; highlights[o]=h end
                end
            end)
            table.insert(npcButtons, {o, b, hl, ow, root})
        end
    end
end

-- 🚀 Оптимизация: обновляем HP и owner раз в секунду (было 0.5)
task.spawn(function()
    while true do
        task.wait(1)
        for _,d in ipairs(npcButtons) do
            local o, b, hl, ow, root = unpack(d)
            if o and o.Parent and b and b.Parent and root then
                local ok, _, hp = analyzeEntity(o)
                if ok then hl.Text = hp end
                ow.Text = checkOwner(root)
            end
        end
    end
end)

-- 🚀 Обновляем таблицу раз в 5 сек (было 3.5)
task.spawn(function() while true do pcall(refreshNPCs); task.wait(5) end end)
pcall(refreshNPCs)
runFullAnalysis()

local function unloadAll()
    AntiKickPro.active = false
    for _,c in pairs(connections) do pcall(function() if c and c.Disconnect then c:Disconnect() end end) end
    for _,c in pairs(rollbackGuards) do pcall(function() if c and c.Disconnect then c:Disconnect() end end) end
    for _,c in pairs(AntiKickPro.hooks) do pcall(function() if c and c.Disconnect then c:Disconnect() end end) end
    for _,h in pairs(highlights) do pcall(function() if h and h.Parent then h:Destroy() end end) end
    for _,o in ipairs(ws:GetDescendants()) do if o.Name=="_HL" then pcall(function() o:Destroy() end) end end
    PartsCache = {}; ThrottleCache = {}
    if sg and sg.Parent then sg:Destroy() end
    _G.NPCKillTesterPro = nil
end

_G.NPCKillTesterPro.Unload = unloadAll
unloadBtn.MouseButton1Click:Connect(unloadAll)

print("=================================================")
print("[👑 v42.0 — "..#MethodRegistry.." методов, 20 в тестах]")
print("  ⚡ Оптимизация v41 сохранена")
print("  🎯 10 новых методов v42 (№167-176)")
print("  🧪 Тесты: 20 методов (№157-176) для проверки")
print("  🛡️ Anti-Kick PRO 5 слоёв — включи!")
print("=================================================")
