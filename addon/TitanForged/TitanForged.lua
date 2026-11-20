local ADDON, NS = ...

local OWNER = "TitanForgedFrame"
local PROXY_PREFIX = "TitanForgedPad_"
local FUNC_PREFIX = "TitanForgedFunc_"

local ACTIONS = {
    { id = "moveForward",  label = "Move forward",        def = "W",      kind = "cmd",  cmd = "MOVEFORWARD" },
    { id = "moveBackward", label = "Move backward",       def = "S",      kind = "cmd",  cmd = "MOVEBACKWARD" },
    { id = "turnLeft",     label = "Turn left",           def = "A",      kind = "cmd",  cmd = "TURNLEFT" },
    { id = "turnRight",    label = "Turn right",          def = "D",      kind = "cmd",  cmd = "TURNRIGHT" },
    { id = "strafeLeft",   label = "Strafe left",         def = "Q",      kind = "cmd",  cmd = "STRAFELEFT" },
    { id = "strafeRight",  label = "Strafe right",        def = "E",      kind = "cmd",  cmd = "STRAFERIGHT" },
    { id = "jump",         label = "Jump",                def = "SPACE",  kind = "cmd",  cmd = "JUMP" },
    { id = "target",       label = "Target nearest (sym)",def = "TAB",    kind = "cmd",  cmd = "TARGETNEARESTENEMY" },
    { id = "interact",     label = "Interact",            def = "M",      kind = "cmd",  cmd = "INTERACTTARGET" },
    { id = "bar1",         label = "Action bar 1",        def = "Y",      kind = "cmd",  cmd = "GAMEPADACTIONBUTTON1" },
    { id = "bar2",         label = "Action bar 2",        def = "U",      kind = "cmd",  cmd = "GAMEPADACTIONBUTTON2" },
    { id = "bar3",         label = "Action bar 3",        def = "I",      kind = "cmd",  cmd = "GAMEPADACTIONBUTTON3" },
    { id = "bar4",         label = "Action bar 4",        def = "O",      kind = "cmd",  cmd = "GAMEPADACTIONBUTTON4" },
    { id = "bar5",         label = "Action bar 5",        def = "H",      kind = "cmd",  cmd = "GAMEPADACTIONBUTTON5" },
    { id = "bar6",         label = "Action bar 6",        def = "J",      kind = "cmd",  cmd = "GAMEPADACTIONBUTTON6" },
    { id = "bar7",         label = "Action bar 7",        def = "K",      kind = "cmd",  cmd = "GAMEPADACTIONBUTTON7" },
    { id = "bar8",         label = "Action bar 8",        def = "L",      kind = "cmd",  cmd = "GAMEPADACTIONBUTTON8" },
    { id = "pageLeft",     label = "Bar page 2 (hold)",   def = "LSHIFT", kind = "cmd",  cmd = "GAMEPADLEFTMOD" },
    { id = "pageRight",    label = "Bar page 3 (hold)",   def = "ALT",    kind = "cmd",  cmd = "GAMEPADRIGHTMOD" },
    { id = "uiFocus",      label = "Toggle UI focus",     def = "T",      kind = "cmd",  cmd = "TOGGLEUIFOCUS" },
    { id = "radial",       label = "Radial menu",         def = "R",      kind = "cmd",  cmd = "OPENRADIAL" },
    { id = "padLeft",      label = "UI d-pad left",       def = "Z",      kind = "pad",  pad = "PADDLEFT" },
    { id = "padDown",      label = "UI d-pad down",       def = "X",      kind = "pad",  pad = "PADDDOWN" },
    { id = "padUp",        label = "UI d-pad up",         def = "C",      kind = "pad",  pad = "PADDUP" },
    { id = "padRight",     label = "UI d-pad right",      def = "V",      kind = "pad",  pad = "PADDRIGHT" },
    { id = "padConfirm",   label = "UI confirm",          def = "B",      kind = "pad",  pad = "PAD1" },
    { id = "padBack",      label = "UI back",             def = "N",      kind = "pad",  pad = "PAD2" },
    { id = "help",         label = "Toggle this help",    def = "F",      kind = "func", fn = "ToggleHelp" },
}

local function KeyFor(action)
    return (NS.db.keys[action.id] or action.def):upper()
end

local function BuildDB()
    if not NS.db then
        NS.db = { keys = {} }
    end
    NS.db.keys = NS.db.keys or {}
end

local function ProxyButtonName(action)
    return PROXY_PREFIX .. action.pad
end

local function FuncButtonName(action)
    return FUNC_PREFIX .. action.id
end

local function EnsureOwner()
    if _G[OWNER] then return _G[OWNER] end
    local f = CreateFrame("Frame", OWNER, UIParent)
    _G[OWNER] = f
    return f
end

local function EnsureProxyButtons(owner)
    for _, action in ipairs(ACTIONS) do
        if action.kind == "pad" then
            local name = ProxyButtonName(action)
            if not _G[name] then
                local b = CreateFrame("Button", name, owner)
                b:SetSize(1, 1)
                b:SetFrameStrata("BACKGROUND")
                b:SetAlpha(0)
                b:SetScript("OnClick", function()
                    local target = _G["InputFunctionBindingButton_" .. action.pad]
                    if target and target.Click then
                        target:Click("LeftButton")
                    else
                        print("|cff808080TitanForged:|r gamepad button " .. action.pad .. " not created by Blizzard yet")
                    end
                end)
            end
        elseif action.kind == "func" then
            local name = FuncButtonName(action)
            if not _G[name] then
                local b = CreateFrame("Button", name, owner)
                b:SetSize(1, 1)
                b:SetFrameStrata("BACKGROUND")
                b:SetAlpha(0)
                b:SetScript("OnClick", function() NS[action.fn]() end)
            end
        end
    end
end

local function ApplyBindings()
    if InCombatLockdown() then return end
    local owner = EnsureOwner()
    ClearOverrideBindings(owner)
    for _, action in ipairs(ACTIONS) do
        local key = KeyFor(action)
        if key ~= "" then
            if action.kind == "cmd" then
                owner:SetOverrideBinding(true, key, action.cmd)
            elseif action.kind == "pad" then
                owner:SetOverrideBindingClick(true, key, ProxyButtonName(action))
            elseif action.kind == "func" then
                owner:SetOverrideBindingClick(true, key, FuncButtonName(action))
            end
        end
    end
end

local function EnsureGamepadUI()
    if Enum.InputDeviceInterfaceType and C_InputInterfaceStyle then
        if C_InputInterfaceStyle.GetCurrentStyle() ~= Enum.InputDeviceInterfaceType.Gamepad then
            SetCVar("InputDeviceInterfaceStyle", Enum.InputDeviceInterfaceType.Gamepad)
        end
    end
end

local function BuildHelp()
    if NS.helpFrame then return NS.helpFrame end
    local f = CreateFrame("Frame", "TitanForgedHelp", UIParent, "BackdropTemplate")
    f:SetSize(560, 620)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({ bgFile = "Background/black8b", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 16 })
    f:Hide()
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Titan Forged key map  (/tfe to change)")
    local rows = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rows:SetPoint("TOPLEFT", 24, -48)
    rows:SetPoint("BOTTOMRIGHT", -24, 24)
    rows:SetJustifyH("LEFT")
    f.rows = rows
    function f:Refresh()
        local lines = {}
        for i, action in ipairs(ACTIONS) do
            lines[i] = "|cffffd100" .. format("%-9s|r %s", KeyFor(action), action.label)
        end
        rows:SetText(table.concat(lines, "\n"))
    end
    NS.helpFrame = f
    return f
end

function NS.ToggleHelp()
    local f = BuildHelp()
    if f:IsShown() then
        f:Hide()
    else
        f:Refresh()
        f:Show()
    end
end

function NS.Rebind(idOrIndex, key)
    local idx = tonumber(idOrIndex)
    local action
    if idx then
        action = ACTIONS[idx]
    else
        for _, a in ipairs(ACTIONS) do
            if a.id == idOrIndex then action = a break end
        end
    end
    if not action then print("TitanForged: unknown action " .. tostring(idOrIndex)) return end
    if not key then NS.db.keys[action.id] = nil print("TitanForged: " .. action.id .. " reset to " .. action.def)
    else NS.db.keys[action.id] = key:upper() print("TitanForged: " .. action.id .. " = " .. key:upper()) end
    ApplyBindings()
end

local function OnSlash(input)
    local a, b = strmatch(input or "", "^(%S+)%s+(%S+)$")
    if not a then a = input end
    if not a or a == "" or a == "help" then
        print("|cffffd100/tfe|r list | /tfe <#|id> <key> | /tfe <#|id> (reset)")
        for i, action in ipairs(ACTIONS) do
            print(format("|cffffd100%2d|r %-9s %-8s %s", i, KeyFor(action), action.id, action.label))
        end
    elseif a == "list" then
        for i, action in ipairs(ACTIONS) do
            print(format("|cffffd100%2d|r %-9s %-8s %s", i, KeyFor(action), action.id, action.label))
        end
    elseif a == "reset" then
        NS.db.keys = {}
        ApplyBindings()
        print("TitanForged: all bindings reset to defaults")
    else
        NS.Rebind(a, b)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("UPDATE_BINDINGS")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        BuildDB()
        EnsureOwner()
        EnsureProxyButtons(_G[OWNER])
        ApplyBindings()
        SLASH_TITANFORGED1 = "/tfe"
        SlashCmdList["TITANFORGED"] = OnSlash
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not NS.enteredWorld then
            NS.enteredWorld = true
            EnsureGamepadUI()
            ApplyBindings()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        C_Timer.After(0.1, ApplyBindings)
    elseif event == "UPDATE_BINDINGS" then
        if not InCombatLockdown() and not NS.applyingFromUs then
            NS.applyingFromUs = true
            ApplyBindings()
            C_Timer.After(0.2, function() NS.applyingFromUs = nil end)
        end
    end
end)
