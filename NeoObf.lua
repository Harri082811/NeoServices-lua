-- NeoServices Lua Script
print("[NeoServices] Starting execution...")

local function safeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then warn("[NeoServices] Error: " .. tostring(err)) end
    return ok, err
end

local scriptOk, scriptErr = pcall(function()

local isUnloaded = false
local connections = {}

shared.NeoServices = {
    ['Settings'] = {
        ['Knock Check'] = true,
        ['Visible Check'] = false, 
        ['Menu Toggle Key'] = 'RightShift',
        ['Show HUD'] = true,
        ['Accent_R'] = 60, ['Accent_G'] = 120, ['Accent_B'] = 255,
        ['Selected Config'] = 'Default',
    },
    ['FOV'] = {
        ['Enabled'] = false, ['Visible'] = true,
        ['Size'] = Vector2.new(2000, 2000), ['Thickness'] = 2,
        ['Color'] = Color3.fromRGB(255, 255, 255),
    },
    ['Silent Aim'] = {
        ['Enabled'] = false, ['Active'] = false, ['Key'] = 'C', ['Mode'] = 'Toggle',
        ['Hit Part'] = 'Head', ['Use Prediction'] = false,
        ['Prediction'] = { ['X'] = 0, ['Y'] = 0, ['Z'] = 0 },
    },
    ['Camera Lock'] = {
        ['Enabled'] = false, ['Active'] = false, ['Key'] = 'E', ['Mode'] = 'Toggle',
        ['Hit Part'] = 'Closest Part',
        ['Smoothing'] = 20, ['Use Prediction'] = true, ['Prediction'] = 0.133,
    },
    ['Trigger Bot'] = {
        ['Enabled'] = false, ['Active'] = false, ['Key'] = 'T', ['Mode'] = 'Toggle', ['Delay'] = 0.10,
        ['Specific Weapons'] = { ['Enabled'] = false, ['Weapons'] = {'[Double-Barrel SG]','[Revolver]','[TacticalShotgun]'} },
    },
    ['Spread'] = {
        ['Enabled'] = false, ['Active'] = false, ['Key'] = 'X', ['Mode'] = 'Toggle', ['Amount'] = 26,
        ['Specific Weapons'] = { ['Enabled'] = false, ['Weapons'] = {'[Double-Barrel SG]','[TacticalShotgun]'} },
    },
    ['Speed'] = { 
        ['Enabled'] = false, ['Active'] = false, ['Key'] = 'Q', ['Mode'] = 'Toggle', ['Multiplier'] = 40, ['Anti Fling'] = false 
    },
    ['Fly'] = { 
        ['Enabled'] = false, ['Active'] = false, ['Key'] = 'F', ['Mode'] = 'Toggle', ['Speed'] = 150 
    },
    ['Hitbox Expander'] = { 
        ['Enabled'] = false, ['Active'] = false, ['Key'] = 'Z', ['Mode'] = 'Toggle', ['Size'] = 5, ['Solid'] = false 
    },
    ['Visual Awareness'] = {
        ['Enabled'] = false, ['Active'] = false,
        ['Box'] = true, ['Skeleton'] = true, ['Health'] = true, ['Distance'] = true,
        ['Color_R'] = 50, ['Color_G'] = 205, ['Color_B'] = 50,
        ['TargetColor_R'] = 180, ['TargetColor_G'] = 0, ['TargetColor_B'] = 0,
    },
    ['Super Jump'] = { 
        ['Enabled'] = false, ['Active'] = false, ['Key'] = 'V', ['Mode'] = 'Toggle', ['Power'] = 260, ['Cooldown'] = 0.1 
    },
    ['Infinite Range'] = { 
        ['Enabled'] = false, ['Active'] = false, ['Key'] = 'N', ['Mode'] = 'Toggle', ['Max Range'] = 77777
    },
    ['Rapid Fire'] = {
        ['Enabled'] = false, ['Delay'] = 0.0005,
        ['Specific Weapons'] = { ['Enabled'] = false, ['Weapons'] = {'[Revolver]','[Double-Barrel SG]'} },
    },
}

local Config = shared.NeoServices
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local HAS_DRAWING = false
pcall(function() if Drawing and Drawing.new then HAS_DRAWING = true end end)

local lockedCamTarget = nil
local lockedSilentTarget = nil
local espCache = {}
local lastTriggerClick = 0
local isLocking = false
local rapidFireMB1 = false
local flyBV = nil
local menuOpen = true
local allThemeElements = {}
local UI_Updaters = {}
local currentConfigName = "Default"
local hudStroke = nil

local function UnloadNeoServices()
    isUnloaded = true
    
    -- Terminate Connections
    for _, conn in ipairs(connections) do
        if conn.Connected then conn:Disconnect() end
    end
    
    -- Destroy ESP
    for _, esp in pairs(espCache) do
        pcall(function()
            esp.nameTag:Remove(); esp.box:Remove(); esp.healthBar:Remove()
            esp.healthBarBg:Remove(); esp.distTag:Remove()
            for _, line in ipairs(esp.skeleton) do line:Remove() end
        end)
    end
    espCache = {}
    
    -- Destroy GUI
    if parentGui:FindFirstChild("NeoServicesGUI") then parentGui.NeoServicesGUI:Destroy() end
    
    -- Reset Character Alterations
    if flyBV then flyBV:Destroy(); flyBV = nil end
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then 
                hrp.Size = Vector3.new(2, 2, 1)
                hrp.Transparency = 1
                hrp.Massless = false 
                hrp.CanCollide = false 
            end
        end
    end
    
    print("[NeoServices] Script successfully unloaded.")
end

local currentTheme = {
    Primary = Color3.fromRGB(20, 25, 45), 
    Secondary = Color3.fromRGB(30, 35, 55),
    Accent = Color3.fromRGB(Config['Settings']['Accent_R'], Config['Settings']['Accent_G'], Config['Settings']['Accent_B']), 
    Text = Color3.fromRGB(220, 225, 240), TextDim = Color3.fromRGB(140, 150, 180), 
    Toggle_On = Color3.fromRGB(Config['Settings']['Accent_R'], Config['Settings']['Accent_G'], Config['Settings']['Accent_B']), 
    Toggle_Off = Color3.fromRGB(60, 65, 85), Border = Color3.fromRGB(50, 60, 100), 
    TabActive = Color3.fromRGB(Config['Settings']['Accent_R'], Config['Settings']['Accent_G'], Config['Settings']['Accent_B']), 
    SliderFill = Color3.fromRGB(Config['Settings']['Accent_R'], Config['Settings']['Accent_G'], Config['Settings']['Accent_B']), 
    SliderBg = Color3.fromRGB(40, 45, 65),
}

local function applyHover(obj, themeColorKey)
    local ogColor
    table.insert(connections, obj.MouseEnter:Connect(function()
        local base = currentTheme[themeColorKey]
        ogColor = base
        if base then
            obj.BackgroundColor3 = Color3.fromRGB(math.clamp(base.R*255 + 35, 0, 255), math.clamp(base.G*255 + 35, 0, 255), math.clamp(base.B*255 + 35, 0, 255))
        end
    end))
    table.insert(connections, obj.MouseLeave:Connect(function()
        if ogColor then obj.BackgroundColor3 = currentTheme[themeColorKey] end
    end))
end

local function getGuiParent()
    local parent = nil
    pcall(function()
        if gethui then parent = gethui() end
        if not parent and game:GetService("CoreGui") then parent = game:GetService("CoreGui") end
    end)
    if not parent then parent = LocalPlayer:WaitForChild("PlayerGui") end
    return parent
end

local parentGui = getGuiParent()
pcall(function() if parentGui:FindFirstChild("NeoServicesGUI") then parentGui.NeoServicesGUI:Destroy() end end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NeoServicesGUI"; ScreenGui.ResetOnSpawn = false; ScreenGui.Parent = parentGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 540, 0, 480); MainFrame.Position = UDim2.new(0.5, -270, 0.5, -240)
MainFrame.BackgroundColor3 = currentTheme.Primary; MainFrame.BorderSizePixel = 0; 
MainFrame.Active = true; MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner"); MainCorner.CornerRadius = UDim.new(0, 6); MainCorner.Parent = MainFrame
local MainStroke = Instance.new("UIStroke"); MainStroke.Thickness = 1.5; MainStroke.Parent = MainFrame

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 38); TitleBar.BackgroundColor3 = currentTheme.Secondary; TitleBar.BorderSizePixel = 0; TitleBar.Parent = MainFrame
local TitleCorner = Instance.new("UICorner"); TitleCorner.CornerRadius = UDim.new(0, 6); TitleCorner.Parent = TitleBar
local TitleFix = Instance.new("Frame"); TitleFix.Size = UDim2.new(1, 0, 0, 12); TitleFix.Position = UDim2.new(0, 0, 1, -12); TitleFix.BackgroundColor3 = currentTheme.Secondary; TitleFix.BorderSizePixel = 0; TitleFix.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Text = "NeoServices"; TitleLabel.Size = UDim2.new(1, -80, 1, 0); TitleLabel.Position = UDim2.new(0, 15, 0, 0); TitleLabel.BackgroundTransparency = 1; TitleLabel.Font = Enum.Font.GothamBold; TitleLabel.TextSize = 16; TitleLabel.TextXAlignment = Enum.TextXAlignment.Left; TitleLabel.Parent = TitleBar

local dragging, dragInput, dragStart, startPos
table.insert(connections, TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = MainFrame.Position
        local dragEnd; dragEnd = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false; dragEnd:Disconnect() end
        end)
    end
end))
table.insert(connections, TitleBar.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end end))
table.insert(connections, UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end))

local TabBar = Instance.new("Frame"); TabBar.Size = UDim2.new(0, 120, 1, -38); TabBar.Position = UDim2.new(0, 0, 0, 38); TabBar.BackgroundTransparency = 1; TabBar.BorderSizePixel = 0; TabBar.Parent = MainFrame
local TabLayout = Instance.new("UIListLayout"); TabLayout.SortOrder = Enum.SortOrder.LayoutOrder; TabLayout.Padding = UDim.new(0, 4); TabLayout.Parent = TabBar
local TabPadding = Instance.new("UIPadding"); TabPadding.PaddingTop = UDim.new(0, 10); TabPadding.PaddingLeft = UDim.new(0, 8); TabPadding.PaddingRight = UDim.new(0, 8); TabPadding.Parent = TabBar

local ContentArea = Instance.new("Frame"); ContentArea.Size = UDim2.new(1, -130, 1, -48); ContentArea.Position = UDim2.new(0, 125, 0, 43); ContentArea.BackgroundTransparency = 1; ContentArea.BorderSizePixel = 0; ContentArea.ClipsDescendants = true; ContentArea.Parent = MainFrame

local pages, tabs, activeTab = {}, {}, nil

local function UpdateThemeColors()
    local r = tonumber(Config['Settings']['Accent_R']) or 60
    local g = tonumber(Config['Settings']['Accent_G']) or 120
    local b = tonumber(Config['Settings']['Accent_B']) or 255
    local cAcc = Color3.fromRGB(r, g, b)
    
    local bgR = math.clamp(math.floor(r * 0.15), 0, 255)
    local bgG = math.clamp(math.floor(g * 0.15), 0, 255)
    local bgB = math.clamp(math.floor(b * 0.15), 0, 255)
    local cPri = Color3.fromRGB(bgR, bgG, bgB)
    
    local barR = math.clamp(bgR + 15, 0, 255)
    local barG = math.clamp(bgG + 15, 0, 255)
    local barB = math.clamp(bgB + 15, 0, 255)
    local cLight = Color3.fromRGB(barR, barG, barB)
    
    currentTheme.Accent = cAcc
    currentTheme.Primary = cPri
    currentTheme.Secondary = cLight
    
    MainFrame.BackgroundColor3 = cPri
    TitleBar.BackgroundColor3 = cLight
    TitleFix.BackgroundColor3 = cLight
    
    MainStroke.Color = cAcc
    TitleLabel.TextColor3 = cAcc
    if hudStroke then hudStroke.Color = cAcc end
    
    for _, el in ipairs(allThemeElements) do
        pcall(function()
            if el.role == "sectionLabel" or el.role == "accentText" then el.obj.TextColor3 = cAcc
            elseif el.role == "toggleBtn" then el.obj.BackgroundColor3 = el.getState() and cAcc or Color3.fromRGB(60,65,85)
            elseif el.role == "sliderFill" then el.obj.BackgroundColor3 = cAcc
            elseif el.role == "tab" then
                el.obj.BackgroundColor3 = (el.name == activeTab) and cAcc or cLight
                el.obj.TextColor3 = (el.name == activeTab) and Color3.fromRGB(255, 255, 255) or currentTheme.TextDim
            elseif el.role == "keybindBtn" or el.role == "dropValBtn" then el.obj.BackgroundColor3 = cPri; el.obj.TextColor3 = cAcc
            elseif el.role == "toggleFrame" or el.role == "dropdownOption" then el.obj.BackgroundColor3 = cLight
            elseif el.role == "button" then el.obj.BackgroundColor3 = cLight; el.obj.TextColor3 = cAcc
            elseif el.role == "dropStroke" then el.obj.Color = cAcc
            end
        end)
    end
end

local function createPage(name)
    local scroll = Instance.new("ScrollingFrame"); scroll.Size = UDim2.new(1, 0, 1, 0); scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0; scroll.ScrollBarThickness = 3; scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; scroll.Visible = false; scroll.Parent = ContentArea
    local layout = Instance.new("UIListLayout"); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Padding = UDim.new(0, 4); layout.Parent = scroll
    local padding = Instance.new("UIPadding"); padding.PaddingLeft = UDim.new(0, 8); padding.PaddingRight = UDim.new(0, 8); padding.PaddingTop = UDim.new(0, 6); padding.PaddingBottom = UDim.new(0, 6); padding.Parent = scroll
    pages[name] = scroll; return scroll
end

local function createTab(name, order)
    local btn = Instance.new("TextButton"); btn.Text = name; btn.Size = UDim2.new(1, 0, 0, 32); btn.BackgroundColor3 = currentTheme.Secondary; btn.BorderSizePixel = 0; btn.Font = Enum.Font.GothamSemibold; btn.TextSize = 13; btn.TextColor3 = currentTheme.TextDim; btn.LayoutOrder = order; btn.Parent = TabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    table.insert(allThemeElements, {obj = btn, role = "tab", name = name})
    
    table.insert(connections, btn.MouseButton1Click:Connect(function()
        for n, page in pairs(pages) do page.Visible = (n == name) end
        activeTab = name; UpdateThemeColors()
    end))
    btn.Name = name; table.insert(tabs, btn); return btn
end

local function createSectionLabel(parent, text, order)
    local lbl = Instance.new("TextLabel"); lbl.Text = "  " .. text; lbl.Size = UDim2.new(1, 0, 0, 26); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 13; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.LayoutOrder = order; lbl.Parent = parent
    table.insert(allThemeElements, {obj = lbl, role = "sectionLabel"})
end

local function createToggle(parent, text, configPath, configKey, order)
    local frame = Instance.new("TextButton"); frame.Size = UDim2.new(1, 0, 0, 30); frame.BackgroundColor3 = currentTheme.Secondary; frame.BorderSizePixel = 0; frame.LayoutOrder = order; frame.Parent = parent; frame.AutoButtonColor = false; frame.Text = ""; frame.Active = true
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,6)
    local lbl = Instance.new("TextLabel"); lbl.Text = text; lbl.Size = UDim2.new(1, -60, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12; lbl.TextColor3 = currentTheme.Text; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = frame
    
    local btn = Instance.new("Frame"); btn.Size = UDim2.new(0, 38, 0, 20); btn.Position = UDim2.new(1, -48, 0.5, -10); btn.BorderSizePixel = 0; btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1,0)
    local circle = Instance.new("Frame"); circle.Size = UDim2.new(0, 16, 0, 16); circle.BackgroundColor3 = Color3.new(1,1,1); circle.BorderSizePixel = 0; circle.Parent = btn
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1,0)

    table.insert(allThemeElements, {obj = btn, role = "toggleBtn", getState = function() return configPath[configKey] end})
    table.insert(allThemeElements, {obj = frame, role = "toggleFrame"})
    
    local function updateVisuals()
        btn.BackgroundColor3 = configPath[configKey] and currentTheme.Accent or Color3.fromRGB(60,65,85)
        circle.Position = configPath[configKey] and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    end
    table.insert(UI_Updaters, updateVisuals); updateVisuals()

    table.insert(connections, frame.MouseButton1Click:Connect(function()
        configPath[configKey] = not configPath[configKey]
        if configPath['Active'] ~= nil and configPath['Mode'] == 'Toggle' then
            configPath['Active'] = configPath[configKey]
        end
        updateVisuals()
    end))
end

local function createSlider(parent, text, min, max, configPath, configKey, order)
    local frame = Instance.new("Frame"); frame.Size = UDim2.new(1, 0, 0, 42); frame.BackgroundColor3 = currentTheme.Secondary; frame.BorderSizePixel = 0; frame.LayoutOrder = order; frame.Parent = parent; frame.Active = true
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,6)
    table.insert(allThemeElements, {obj = frame, role = "toggleFrame"})

    local lbl = Instance.new("TextLabel"); lbl.Text = text; lbl.Size = UDim2.new(0.6, 0, 0, 20); lbl.Position = UDim2.new(0, 10, 0, 2); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12; lbl.TextColor3 = currentTheme.Text; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = frame
    local valLabel = Instance.new("TextLabel"); valLabel.Size = UDim2.new(0.3, 0, 0, 20); valLabel.Position = UDim2.new(0.7, -10, 0, 2); valLabel.BackgroundTransparency = 1; valLabel.Font = Enum.Font.GothamBold; valLabel.TextSize = 12; valLabel.TextXAlignment = Enum.TextXAlignment.Right; valLabel.Parent = frame
    local sliderBg = Instance.new("Frame"); sliderBg.Size = UDim2.new(1, -24, 0, 6); sliderBg.Position = UDim2.new(0, 12, 0, 28); sliderBg.BackgroundColor3 = Color3.fromRGB(40, 45, 65); sliderBg.BorderSizePixel = 0; sliderBg.Parent = frame
    Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(1,0)
    local sliderFill = Instance.new("Frame"); sliderFill.BorderSizePixel = 0; sliderFill.Parent = sliderBg
    Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1,0)
    
    table.insert(allThemeElements, {obj = valLabel, role = "accentText"}); table.insert(allThemeElements, {obj = sliderFill, role = "sliderFill"})

    local function updateVisuals()
        local pct = math.clamp((configPath[configKey] - min) / (max - min), 0, 1)
        sliderFill.Size = UDim2.new(pct, 0, 1, 0)
        valLabel.Text = tostring(math.floor(configPath[configKey] * 10) / 10)
    end
    table.insert(UI_Updaters, updateVisuals); updateVisuals()
    
    local sliding = false
    table.insert(connections, sliderBg.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then sliding = true end end))
    table.insert(connections, UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end end))
    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
            local rel = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
            local val = min + (max - min) * rel; configPath[configKey] = math.floor(val * 10) / 10
            updateVisuals()
        end
    end))
end

local function createKeybind(parent, text, configPath, configKey, order)
    local frame = Instance.new("Frame"); frame.Size = UDim2.new(1, 0, 0, 30); frame.BackgroundColor3 = currentTheme.Secondary; frame.BorderSizePixel = 0; frame.LayoutOrder = order; frame.Parent = parent; frame.Active = true
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,6)
    table.insert(allThemeElements, {obj = frame, role = "toggleFrame"})

    local lbl = Instance.new("TextLabel"); lbl.Text = text; lbl.Size = UDim2.new(1, -90, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12; lbl.TextColor3 = currentTheme.Text; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = frame
    local btn = Instance.new("TextButton"); btn.Size = UDim2.new(0, 70, 0, 22); btn.Position = UDim2.new(1, -78, 0.5, -11); btn.Font = Enum.Font.GothamBold; btn.TextSize = 11; btn.BorderSizePixel = 0; btn.Parent = frame; btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
    table.insert(allThemeElements, {obj = btn, role = "keybindBtn"})

    local function updateVisuals() btn.Text = "[" .. configPath[configKey] .. "]" end
    table.insert(UI_Updaters, updateVisuals); updateVisuals()

    local listening = false
    table.insert(connections, btn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true; btn.Text = "[...]"
        local conn; conn = UserInputService.InputBegan:Connect(function(input, gp)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                configPath[configKey] = input.KeyCode.Name
                listening = false; conn:Disconnect(); updateVisuals()
            end
        end)
        table.insert(connections, conn)
        task.delay(5, function() if listening then listening = false; updateVisuals(); pcall(function() conn:Disconnect() end) end end)
    end))
    applyHover(btn, "Primary")
end

local function createDropdown(parent, text, options, configPath, configKey, order)
    local frame = Instance.new("TextButton", parent)
    frame.Size = UDim2.new(1, 0, 0, 30); frame.BackgroundColor3 = currentTheme.Secondary; frame.BorderSizePixel = 0; frame.LayoutOrder = order; frame.AutoButtonColor = false; frame.Text = ""; frame.Active = true
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,6)
    table.insert(allThemeElements, {obj = frame, role = "toggleFrame"})

    local lbl = Instance.new("TextLabel", frame)
    lbl.Text = "  " .. text; lbl.Size = UDim2.new(0.5, 0, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12; lbl.TextColor3 = currentTheme.Text; lbl.TextXAlignment = Enum.TextXAlignment.Left

    local valBtn = Instance.new("TextButton", frame)
    valBtn.Size = UDim2.new(0, 120, 0, 22); valBtn.Position = UDim2.new(1, -130, 0.5, -11); valBtn.Font = Enum.Font.Gotham; valBtn.TextSize = 11; valBtn.BorderSizePixel = 0; valBtn.AutoButtonColor = false
    Instance.new("UICorner", valBtn).CornerRadius = UDim.new(0, 6)
    table.insert(allThemeElements, {obj = valBtn, role = "dropValBtn"})

    local dropOpen = false
    local optionHeight = 24

    local blocker = Instance.new("TextButton", ScreenGui)
    blocker.Size = UDim2.new(1, 0, 1, 0); blocker.BackgroundTransparency = 1; blocker.Text = ""; blocker.Visible = false; blocker.ZIndex = 998

    local dropList = Instance.new("Frame", ScreenGui)
    dropList.Size = UDim2.new(0, 120, 0, 0); dropList.BackgroundColor3 = currentTheme.Secondary; dropList.BorderSizePixel = 0; dropList.Visible = false; dropList.ZIndex = 999; dropList.ClipsDescendants = true
    Instance.new("UICorner", dropList).CornerRadius = UDim.new(0, 6)
    local dStroke = Instance.new("UIStroke", dropList); dStroke.Thickness = 1
    table.insert(allThemeElements, {obj = dropList, role = "toggleFrame"})
    table.insert(allThemeElements, {obj = dStroke, role = "dropStroke"})

    local function updateVisuals() valBtn.Text = configPath[configKey] end
    table.insert(UI_Updaters, updateVisuals); updateVisuals()

    local function buildOptions(opts)
        for _, c in ipairs(dropList:GetChildren()) do if not c:IsA("UICorner") and not c:IsA("UIStroke") then c:Destroy() end end
        
        local spacing = 2
        local padding = 4
        local totalHeight = (#opts * optionHeight) + (math.max(0, #opts - 1) * spacing) + (padding * 2)
        dropList.Size = UDim2.new(0, 120, 0, totalHeight)
        
        local layout = Instance.new("UIListLayout", dropList)
        layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Padding = UDim.new(0, spacing); layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        
        local pad = Instance.new("UIPadding", dropList)
        pad.PaddingTop = UDim.new(0, padding); pad.PaddingBottom = UDim.new(0, padding)
        
        for _, opt in ipairs(opts) do
            local ob = Instance.new("TextButton", dropList)
            ob.Size = UDim2.new(1, -8, 0, optionHeight); ob.BackgroundColor3 = currentTheme.Secondary; ob.Text = opt; ob.Font = Enum.Font.Gotham; ob.TextSize = 11; ob.TextColor3 = currentTheme.Text; ob.AutoButtonColor = false; ob.BorderSizePixel = 0; ob.ZIndex = 1000
            
            Instance.new("UICorner", ob).CornerRadius = UDim.new(0, 6)
            
            applyHover(ob, "Secondary")
            table.insert(allThemeElements, {obj = ob, role = "dropdownOption"})
            table.insert(connections, ob.MouseButton1Click:Connect(function()
                configPath[configKey] = opt; updateVisuals()
                dropOpen = false; dropList.Visible = false; blocker.Visible = false
            end))
        end
    end
    buildOptions(options)

    table.insert(connections, RunService.RenderStepped:Connect(function()
        if dropOpen and valBtn.Parent then
            dropList.Position = UDim2.new(0, valBtn.AbsolutePosition.X, 0, valBtn.AbsolutePosition.Y + valBtn.AbsoluteSize.Y + 4)
        elseif dropOpen and not valBtn.Parent then
            dropOpen = false; dropList.Visible = false; blocker.Visible = false
        end
    end))

    table.insert(connections, valBtn.MouseButton1Click:Connect(function()
        dropOpen = not dropOpen; dropList.Visible = dropOpen; blocker.Visible = dropOpen
    end))
    table.insert(connections, blocker.MouseButton1Click:Connect(function()
        dropOpen = false; dropList.Visible = false; blocker.Visible = false
    end))
    
    return { updateOptions = function(newOpts) options = newOpts; buildOptions(options) end }
end

local function createColorPicker(parent, text, configPath, rKey, gKey, bKey, order, isTheme)
    local container = Instance.new("Frame"); container.Size = UDim2.new(1, 0, 0, 115); container.BackgroundColor3 = currentTheme.Secondary; container.BorderSizePixel = 0; container.LayoutOrder = order; container.Parent = parent; container.Active = true
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)
    table.insert(allThemeElements, {obj = container, role = "toggleFrame"})

    local lbl = Instance.new("TextLabel"); lbl.Text = "  " .. text; lbl.Size = UDim2.new(0.5, 0, 0, 25); lbl.Position = UDim2.new(0, 5, 0, 2); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11; lbl.TextColor3 = currentTheme.Text; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = container
    local colorPreview = Instance.new("TextButton"); colorPreview.Size = UDim2.new(0, 35, 0, 16); colorPreview.Position = UDim2.new(1, -45, 0, 6); colorPreview.Text = ""; colorPreview.AutoButtonColor = false; colorPreview.Parent = container
    Instance.new("UICorner", colorPreview).CornerRadius = UDim.new(0, 6)

    local function updateMainPreview() colorPreview.BackgroundColor3 = Color3.fromRGB(configPath[rKey], configPath[gKey], configPath[bKey]) end
    table.insert(UI_Updaters, updateMainPreview)
    updateMainPreview()

    local function createMiniSlider(chanName, yOffset, keyPath)
        local slbl = Instance.new("TextLabel", container); slbl.Text = chanName .. ":"; slbl.Size = UDim2.new(0, 20, 0, 16); slbl.Position = UDim2.new(0, 10, 0, yOffset); slbl.BackgroundTransparency = 1; slbl.TextColor3 = currentTheme.TextDim; slbl.Font = Enum.Font.GothamBold; slbl.TextSize = 11
        local sval = Instance.new("TextLabel", container); sval.Size = UDim2.new(0, 25, 0, 16); sval.Position = UDim2.new(1, -35, 0, yOffset); sval.BackgroundTransparency = 1; sval.TextColor3 = currentTheme.Accent; sval.Font = Enum.Font.GothamBold; sval.TextSize = 11; sval.TextXAlignment = Enum.TextXAlignment.Right
        local sbg = Instance.new("Frame", container); sbg.Size = UDim2.new(1, -80, 0, 6); sbg.Position = UDim2.new(0, 35, 0, yOffset + 5); sbg.BackgroundColor3 = Color3.fromRGB(40, 45, 65); sbg.BorderSizePixel = 0; Instance.new("UICorner", sbg).CornerRadius = UDim.new(1, 0)
        local sfill = Instance.new("Frame", sbg); sfill.BorderSizePixel = 0; Instance.new("UICorner", sfill).CornerRadius = UDim.new(1, 0)
        table.insert(allThemeElements, {obj = sval, role = "accentText"}); table.insert(allThemeElements, {obj = sfill, role = "sliderFill"})

        local function updateSlid()
            local val = configPath[keyPath]
            sfill.Size = UDim2.new(val / 255, 0, 1, 0)
            sval.Text = tostring(math.floor(val))
        end
        table.insert(UI_Updaters, updateSlid)
        updateSlid()

        local isSliding = false
        table.insert(connections, sbg.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then isSliding = true end end))
        table.insert(connections, UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then isSliding = false end end))
        table.insert(connections, UserInputService.InputChanged:Connect(function(input)
            if isSliding and input.UserInputType == Enum.UserInputType.MouseMovement then
                local relativeX = math.clamp((input.Position.X - sbg.AbsolutePosition.X) / sbg.AbsoluteSize.X, 0, 1)
                configPath[keyPath] = math.floor(relativeX * 255)
                updateSlid(); updateMainPreview()
                if isTheme then UpdateThemeColors() end
            end
        end))
    end
    createMiniSlider("R", 30, rKey); createMiniSlider("G", 52, gKey); createMiniSlider("B", 74, bKey)
end

local function createTextBox(parent, text, placeholder, order, callback)
    local frame = Instance.new("Frame"); frame.Size = UDim2.new(1, 0, 0, 30); frame.BackgroundColor3 = currentTheme.Secondary; frame.BorderSizePixel = 0; frame.LayoutOrder = order; frame.Parent = parent; frame.Active = true
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,6)
    table.insert(allThemeElements, {obj = frame, role = "toggleFrame"})
    
    local lbl = Instance.new("TextLabel"); lbl.Text = "  " .. text .. ":"; lbl.Size = UDim2.new(0.35, 0, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12; lbl.TextColor3 = currentTheme.Text; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = frame
    
    local clipFrame = Instance.new("Frame")
    clipFrame.Size = UDim2.new(0, 150, 0, 22)
    clipFrame.Position = UDim2.new(1, -160, 0.5, -11)
    clipFrame.BackgroundTransparency = 1; clipFrame.ClipsDescendants = true; clipFrame.Parent = frame
    
    local box = Instance.new("TextBox"); box.Size = UDim2.new(1, 0, 1, 0); box.Position = UDim2.new(0,0,0,0); box.BackgroundColor3 = currentTheme.Primary; box.Text = placeholder; box.Font = Enum.Font.Gotham; box.TextSize = 11; box.BorderSizePixel = 0; box.Parent = clipFrame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
    table.insert(allThemeElements, {obj = box, role = "keybindBtn"})
    
    table.insert(connections, box.FocusLost:Connect(function() if callback then safeCall(callback, box.Text) end end))
end

local function createButton(parent, text, order, callback)
    local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1, 0, 0, 30); btn.BackgroundColor3 = currentTheme.Secondary; btn.Text = text; btn.Font = Enum.Font.GothamBold; btn.TextSize = 12; btn.BorderSizePixel = 0; btn.LayoutOrder = order; btn.Parent = parent; btn.AutoButtonColor = false; btn.Active = true
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
    table.insert(allThemeElements, {obj = btn, role = "button"})
    table.insert(connections, btn.MouseButton1Click:Connect(function() if callback then safeCall(callback) end end))
    applyHover(btn, "Secondary")
end


local folderName = "NeoServices_Configs"
if makefolder and not isfolder(folderName) then pcall(function() makefolder(folderName) end) end

local function deepMerge(t1, t2)
    for k, v in pairs(t2) do
        if type(v) == "table" and type(t1[k]) == "table" then
            deepMerge(t1[k], v)
        elseif type(v) ~= "table" then
            t1[k] = v
        end
    end
end

local function saveConfig(name)
    if not writefile then return end
    pcall(function()
        local json = HttpService:JSONEncode(Config)
        writefile(folderName .. "/" .. name .. ".json", json)
        print("[NeoServices] Saved config: " .. name)
    end)
end

local function loadConfig(name)
    if not readfile then return end
    pcall(function()
        local path = folderName .. "/" .. name .. ".json"
        if isfile(path) then
            local json = readfile(path)
            local success, data = pcall(function() return HttpService:JSONDecode(json) end)
            if success and type(data) == "table" then
                deepMerge(Config, data)
                for _, updater in ipairs(UI_Updaters) do pcall(updater) end
                UpdateThemeColors()
                print("[NeoServices] Successfully Loaded config: " .. name)
            else
                warn("[NeoServices] Corrupted JSON in config: " .. name)
            end
        end
    end)
end

local function getConfigList()
    local list = {}
    if listfiles and isfolder(folderName) then
        pcall(function()
            for _, file in ipairs(listfiles(folderName)) do
                local name = file:match("([^/\\]+)%.json$")
                if name then table.insert(list, name) end
            end
        end)
    end
    if #list == 0 then table.insert(list, "Default") end
    return list
end

-- TABS Construction
createTab("Aim", 1); createTab("Combat", 2); createTab("Movement", 3); createTab("Visuals", 4); createTab("Settings", 5);
local aimPage = createPage("Aim"); local combatPage = createPage("Combat"); local movementPage = createPage("Movement"); local visualsPage = createPage("Visuals"); local settingsPage = createPage("Settings");

-- AIM TAB
createSectionLabel(aimPage, "Silent Aim (Doesn't work on all executors)", 1)
createToggle(aimPage, "Enable", Config['Silent Aim'], 'Enabled', 2)
createKeybind(aimPage, "Keybind", Config['Silent Aim'], 'Key', 3)
createDropdown(aimPage, "Mode", {"Toggle", "Hold"}, Config['Silent Aim'], 'Mode', 4)
createDropdown(aimPage, "Target Bone", {"Head", "UpperTorso", "HumanoidRootPart", "Closest Part"}, Config['Silent Aim'], 'Hit Part', 5)

createSectionLabel(aimPage, "Cam Lock", 10)
createToggle(aimPage, "Enable", Config['Camera Lock'], 'Enabled', 11)
createKeybind(aimPage, "Keybind", Config['Camera Lock'], 'Key', 12)
createDropdown(aimPage, "Mode", {"Toggle", "Hold"}, Config['Camera Lock'], 'Mode', 13)
createDropdown(aimPage, "Target Bone", {"Head", "UpperTorso", "HumanoidRootPart", "Closest Part"}, Config['Camera Lock'], 'Hit Part', 14)
createSlider(aimPage, "Smoothness (0=Snap)", 0, 100, Config['Camera Lock'], 'Smoothing', 15)

createSectionLabel(aimPage, "Target Checks", 20)
createToggle(aimPage, "Wall Check (Visible Only)", Config['Settings'], 'Visible Check', 21)
createToggle(aimPage, "Knock Check (Ignore Downed)", Config['Settings'], 'Knock Check', 22)

-- COMBAT TAB
createSectionLabel(combatPage, "Trigger Bot", 1)
createToggle(combatPage, "Enable", Config['Trigger Bot'], 'Enabled', 2)
createKeybind(combatPage, "Keybind", Config['Trigger Bot'], 'Key', 3)
createDropdown(combatPage, "Mode", {"Toggle", "Hold"}, Config['Trigger Bot'], 'Mode', 4)

createSectionLabel(combatPage, "Hitbox Expander", 20)
createToggle(combatPage, "Enable", Config['Hitbox Expander'], 'Enabled', 21)
createKeybind(combatPage, "Keybind", Config['Hitbox Expander'], 'Key', 22)
createDropdown(combatPage, "Mode", {"Toggle", "Hold"}, Config['Hitbox Expander'], 'Mode', 23)
createToggle(combatPage, "Solid Hitboxes", Config['Hitbox Expander'], 'Solid', 24)

createSectionLabel(combatPage, "Infinite Range", 30)
createToggle(combatPage, "Enable", Config['Infinite Range'], 'Enabled', 31)
createKeybind(combatPage, "Keybind", Config['Infinite Range'], 'Key', 32)
createDropdown(combatPage, "Mode", {"Toggle", "Hold"}, Config['Infinite Range'], 'Mode', 33)

-- MOVEMENT TAB
createSectionLabel(movementPage, "Speed", 1)
createToggle(movementPage, "Enable", Config['Speed'], 'Enabled', 2)
createKeybind(movementPage, "Keybind", Config['Speed'], 'Key', 3)
createDropdown(movementPage, "Mode", {"Toggle", "Hold"}, Config['Speed'], 'Mode', 4)
createSlider(movementPage, "Multiplier", 1, 200, Config['Speed'], 'Multiplier', 5)

createSectionLabel(movementPage, "Fly", 10)
createToggle(movementPage, "Enable", Config['Fly'], 'Enabled', 11)
createKeybind(movementPage, "Keybind", Config['Fly'], 'Key', 12)
createDropdown(movementPage, "Mode", {"Toggle", "Hold"}, Config['Fly'], 'Mode', 13)
createSlider(movementPage, "Speed", 10, 300, Config['Fly'], 'Speed', 14)

createSectionLabel(movementPage, "Super Jump", 20)
createToggle(movementPage, "Enable", Config['Super Jump'], 'Enabled', 21)
createKeybind(movementPage, "Keybind", Config['Super Jump'], 'Key', 22)
createDropdown(movementPage, "Mode", {"Toggle", "Hold"}, Config['Super Jump'], 'Mode', 23)
createSlider(movementPage, "Power", 50, 500, Config['Super Jump'], 'Power', 24)

-- VISUALS TAB
createSectionLabel(visualsPage, "ESP", 1)
createToggle(visualsPage, "Enable", Config['Visual Awareness'], 'Enabled', 2)
createToggle(visualsPage, "Show Boxes", Config['Visual Awareness'], 'Box', 3)
createToggle(visualsPage, "Show Skeleton", Config['Visual Awareness'], 'Skeleton', 4)
createToggle(visualsPage, "Show Health", Config['Visual Awareness'], 'Health', 5)
createToggle(visualsPage, "Show Distance", Config['Visual Awareness'], 'Distance', 6)

createSectionLabel(visualsPage, "ESP Colors", 10)
createColorPicker(visualsPage, "Normal ESP Color", Config['Visual Awareness'], 'Color_R', 'Color_G', 'Color_B', 11, false)
createColorPicker(visualsPage, "Targeted ESP Color", Config['Visual Awareness'], 'TargetColor_R', 'TargetColor_G', 'TargetColor_B', 12, false)

-- SETTINGS TAB
createSectionLabel(settingsPage, "Settings", 1)
createKeybind(settingsPage, "Menu Toggle Key", Config['Settings'], 'Menu Toggle Key', 2)
createToggle(settingsPage, "Show Active Keybinds HUD", Config['Settings'], 'Show HUD', 3)

createSectionLabel(settingsPage, "Theme Colors", 10)
createColorPicker(settingsPage, "Menu Accent Color", Config['Settings'], 'Accent_R', 'Accent_G', 'Accent_B', 11, true)

createSectionLabel(settingsPage, "Config Manager", 20)
createTextBox(settingsPage, "Config Name", "Default", 21, function(val) currentConfigName = val end)

local btnRow = Instance.new("Frame", settingsPage)
btnRow.Size = UDim2.new(1, 0, 0, 30); btnRow.BackgroundTransparency = 1; btnRow.LayoutOrder = 22

local sBtn = Instance.new("TextButton", btnRow)
sBtn.Size = UDim2.new(0.48, 0, 1, 0); sBtn.BackgroundColor3 = currentTheme.Secondary; sBtn.Text = "Save Config"; sBtn.Font = Enum.Font.GothamBold; sBtn.TextSize = 12; sBtn.TextColor3 = currentTheme.Accent; sBtn.BorderSizePixel = 0; sBtn.AutoButtonColor = false; Instance.new("UICorner", sBtn).CornerRadius = UDim.new(0,6)
local lBtn = Instance.new("TextButton", btnRow)
lBtn.Size = UDim2.new(0.48, 0, 1, 0); lBtn.Position = UDim2.new(0.52, 0, 0, 0); lBtn.BackgroundColor3 = currentTheme.Secondary; lBtn.Text = "Load Config"; lBtn.Font = Enum.Font.GothamBold; lBtn.TextSize = 12; lBtn.TextColor3 = currentTheme.Accent; lBtn.BorderSizePixel = 0; lBtn.AutoButtonColor = false; Instance.new("UICorner", lBtn).CornerRadius = UDim.new(0,6)

table.insert(allThemeElements, {obj = sBtn, role = "button"}); table.insert(allThemeElements, {obj = lBtn, role = "button"})
applyHover(sBtn, "Secondary"); applyHover(lBtn, "Secondary")

local configDrop = createDropdown(settingsPage, "Saved Configs", getConfigList(), Config['Settings'], 'Selected Config', 23)

table.insert(connections, sBtn.MouseButton1Click:Connect(function() saveConfig(currentConfigName); configDrop.updateOptions(getConfigList()) end))
table.insert(connections, lBtn.MouseButton1Click:Connect(function() loadConfig(Config['Settings']['Selected Config']) end))

createSectionLabel(settingsPage, "Unload", 30)
createButton(settingsPage, "Unload Script (broken)", 31, function() UnloadNeoServices() end)

for _, t in ipairs(tabs) do
    if t.Name == "Aim" then
        activeTab = "Aim"
    end
end
for _, page in pairs(pages) do page.Visible = false end
if pages["Aim"] then pages["Aim"].Visible = true end
UpdateThemeColors()


local function isPlayerKnockedOrKO(player)
    if not Config['Settings']['Knock Check'] then return false end
    if player.Character then
        local bodyEffects = player.Character:FindFirstChild("BodyEffects")
        if bodyEffects then
            local ko = bodyEffects:FindFirstChild("K.O") or bodyEffects:FindFirstChild("KO")
            if ko and ko.Value == true then return true end
            local knocked = bodyEffects:FindFirstChild("Knocked")
            if knocked and knocked.Value == true then return true end
        end
    end
    return false
end

local function isSelfKnocked()
    if LocalPlayer.Character then
        local bodyEffects = LocalPlayer.Character:FindFirstChild("BodyEffects")
        if bodyEffects then
            local ko = bodyEffects:FindFirstChild("K.O") or bodyEffects:FindFirstChild("KO")
            if ko and ko.Value == true then return true end
            local knocked = bodyEffects:FindFirstChild("Knocked")
            if knocked and knocked.Value == true then return true end
        end
    end
    return false
end

local function canSeeTarget(part)
    if not Config['Settings']['Visible Check'] then return true end
    if not part or not part.Parent then return false end
    
    local character = part.Parent
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    
    local state = humanoid:GetState()
    local isAirborne = (state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.FallingDown)
    local root = character:FindFirstChild("HumanoidRootPart")
    local velY = root and math.abs(root.AssemblyLinearVelocity.Y) or 0
    
    if (isAirborne or velY > 8) and (isLocking or Config['Silent Aim']['Active']) then return true end
    
    local origin = Camera.CFrame.Position
    local direction = (part.Position - origin).Unit * (part.Position - origin).Magnitude
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, character}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.IgnoreWater = true
    
    local rayResult = Workspace:Raycast(origin, direction, raycastParams)
    return rayResult == nil or rayResult.Instance:IsDescendantOf(character)
end

local function getClosestBodyPart(character)
    local closestPart = nil
    local shortestDist = math.huge
    local bodyParts = {
        character:FindFirstChild("Head"), character:FindFirstChild("UpperTorso"),
        character:FindFirstChild("HumanoidRootPart"), character:FindFirstChild("LowerTorso")
    }
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, part in pairs(bodyParts) do
        if part then
            local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen then
                local dist = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
                if dist < shortestDist then shortestDist = dist; closestPart = part end
            end
        end
    end
    return closestPart
end

local function isMouseInFOV(character)
    if not Config['FOV']['Enabled'] then return true end
    if not character then return false end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    if not rootPart or not head then return false end
    
    local headPos, headOnScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
    local legPos, legOnScreen = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
    if not headOnScreen or not legOnScreen then return false end
    
    local height = math.abs(headPos.Y - legPos.Y)
    local width = height / 2
    local rootPos = Camera:WorldToViewportPoint(rootPart.Position)
    local padding = 10
    return (Mouse.X >= (rootPos.X - width/2 - padding) and Mouse.X <= (rootPos.X + width/2 + padding) and Mouse.Y >= (headPos.Y - padding) and Mouse.Y <= (legPos.Y + padding))
end

local function isTargetValid(targetPart)
    if not targetPart or not targetPart.Parent then return false end
    local player = Players:GetPlayerFromCharacter(targetPart.Parent)
    if not player or isPlayerKnockedOrKO(player) then return false end
    if not canSeeTarget(targetPart) then return false end
    return true
end

local function findClosestTarget(hitPartConfig)
    local closestTarget = nil
    local shortestDistance = math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if not isPlayerKnockedOrKO(player) then
                local targetPart = (hitPartConfig == 'Closest Part') and getClosestBodyPart(player.Character) or player.Character:FindFirstChild(hitPartConfig)
                if targetPart and canSeeTarget(targetPart) then
                    local pos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    if isMouseInFOV(player.Character) and onScreen then
                        local dist = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
                        if dist < shortestDistance then shortestDistance = dist; closestTarget = targetPart end
                    end
                end
            end
        end
    end
    return closestTarget
end

local function getPredictedPosition(part, config)
    if not config['Use Prediction'] then return part.Position end
    local velocity = part.AssemblyLinearVelocity or part.Velocity or Vector3.new(0, 0, 0)
    local prediction = config['Prediction']
    if type(prediction) == "table" then
        return part.Position + Vector3.new(velocity.X * (prediction['X'] or 0.133), velocity.Y * (prediction['Y'] or 0.133), velocity.Z * (prediction['Z'] or 0.133))
    else
        return part.Position + (velocity * (prediction == 0 and 0.1245 or prediction))
    end
end


local function applyCameraLock()
    if not Config['Camera Lock']['Enabled'] or not isLocking or not lockedCamTarget then return end
    if isSelfKnocked() or not isTargetValid(lockedCamTarget) then lockedCamTarget = nil; isLocking = false; return end
    
    local targetPos = getPredictedPosition(lockedCamTarget, Config['Camera Lock'])
    local targetCFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)
    local smoothValue = Config['Camera Lock']['Smoothing']
    
    if smoothValue == 0 then
        Camera.CFrame = targetCFrame
    else
        local alpha = math.clamp(1 - (smoothValue / 100), 0.01, 0.99)
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, alpha)
    end
end


local function TriggerBot()
    if not Config['Trigger Bot']['Enabled'] or not Config['Trigger Bot']['Active'] then return end
    if tick() - lastTriggerClick < Config['Trigger Bot']['Delay'] then return end
    
    local target = lockedSilentTarget or findClosestTarget(Config['Silent Aim']['Hit Part'])
    if not target or not isTargetValid(target) then return end
    
    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if not tool then return end
    
    if Config['Trigger Bot']['Specific Weapons']['Enabled'] then
        local weaponValid = false
        for _, weaponName in pairs(Config['Trigger Bot']['Specific Weapons']['Weapons']) do
            if tool.Name == weaponName or tool.Name:find(weaponName:gsub("%[", ""):gsub("%]", "")) then weaponValid = true; break end
        end
        if not weaponValid then return end
    end
    tool:Activate()
    lastTriggerClick = tick()
end

task.spawn(function()
    pcall(function()
        local grm = getrawmetatable(game)
        local oldIndex = grm.__index
        setreadonly(grm, false)
        grm.__index = newcclosure(function(self, key)
            if isUnloaded then return oldIndex(self, key) end
            if not checkcaller() and self == Mouse and Config['Silent Aim']['Enabled'] and Config['Silent Aim']['Active'] then
                if (key == "Hit" or key == "Target") and lockedSilentTarget and isTargetValid(lockedSilentTarget) then
                    if key == "Hit" then return CFrame.new(getPredictedPosition(lockedSilentTarget, Config['Silent Aim'])) end
                    if key == "Target" then return lockedSilentTarget end
                end
            end
            return oldIndex(self, key)
        end)
        setreadonly(grm, true)
    end)
end)

task.spawn(function()
    pcall(function()
        local oldRandom
        oldRandom = hookfunction(math.random, function(...)
            if isUnloaded then return oldRandom(...) end
            local args = {...}
            if checkcaller() then return oldRandom(...) end
            if (#args == 0) or (args[1] == -0.05 and args[2] == 0.05) or (args[1] == -0.1) or (args[1] == -0.05) then
                if Config['Spread']['Enabled'] and Config['Spread']['Active'] then
                    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                    if tool then
                        if Config['Spread']['Specific Weapons']['Enabled'] then
                            for _, w in pairs(Config['Spread']['Specific Weapons']['Weapons']) do
                                if tool.Name == w then return oldRandom(...) * (Config['Spread']['Amount'] / 100) end
                            end
                        else
                            return oldRandom(...) * (Config['Spread']['Amount'] / 100)
                        end
                    end
                end
            end
            return oldRandom(...)
        end)
    end)
end)


local skeletonConnections = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}
}

local function addESPToPlayer(player)
    if not HAS_DRAWING or player == LocalPlayer then return end
    safeCall(function()
        local esp = {
            player = player,
            nameTag = Drawing.new("Text"), box = Drawing.new("Square"),
            healthBar = Drawing.new("Line"), healthBarBg = Drawing.new("Line"),
            distTag = Drawing.new("Text"), skeleton = {}
        }
        esp.nameTag.Size = 13; esp.nameTag.Center = true; esp.nameTag.Outline = true; esp.nameTag.Visible = false; esp.nameTag.ZIndex = 1000
        esp.distTag.Size = 11; esp.distTag.Center = true; esp.distTag.Outline = true; esp.distTag.Visible = false; esp.distTag.ZIndex = 1000
        esp.box.Thickness = 1; esp.box.Filled = false; esp.box.Visible = false; esp.box.ZIndex = 999
        esp.healthBarBg.Thickness = 2.5; esp.healthBarBg.Color = Color3.new(0,0,0); esp.healthBarBg.Visible = false; esp.healthBarBg.ZIndex = 998
        esp.healthBar.Thickness = 1; esp.healthBar.Visible = false; esp.healthBar.ZIndex = 999
        for i=1, #skeletonConnections do
            local line = Drawing.new("Line")
            line.Thickness = 1; line.Visible = false; line.ZIndex = 998
            table.insert(esp.skeleton, line)
        end
        espCache[player.UserId] = esp
    end)
end

local function hideESP(esp)
    if esp then
        esp.nameTag.Visible = false
        esp.box.Visible = false
        esp.healthBar.Visible = false
        esp.healthBarBg.Visible = false
        esp.distTag.Visible = false
        for _, line in ipairs(esp.skeleton) do line.Visible = false end
    end
end

local function removeESPFromPlayer(player)
    local esp = espCache[player.UserId]
    if esp then 
        safeCall(function() 
            esp.nameTag:Remove(); esp.box:Remove(); esp.healthBar:Remove(); esp.healthBarBg:Remove(); esp.distTag:Remove()
            for _, line in ipairs(esp.skeleton) do line:Remove() end
            espCache[player.UserId] = nil 
        end)
    end
end

local function refreshESP()
    if not HAS_DRAWING then return end
    if not Config['Visual Awareness']['Enabled'] then
        for _, esp in pairs(espCache) do hideESP(esp) end
        return
    end
    
    local c = Config['Visual Awareness']
    local baseColor = Color3.fromRGB(c['Color_R'], c['Color_G'], c['Color_B'])
    local targColor = Color3.fromRGB(c['TargetColor_R'], c['TargetColor_G'], c['TargetColor_B'])

    for userId, esp in pairs(espCache) do
        local player = esp.player
        local char = player and player.Character
        if not char or not char.Parent then
            hideESP(esp)
            continue
        end
        
        local rootPart = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        
        if rootPart and head and humanoid and humanoid.Health > 0 then
            local legPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
            if onScreen and legPos.Z > 0 then
                local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                local dist = (Camera.CFrame.Position - rootPart.Position).Magnitude
                local height = math.abs(headPos.Y - legPos.Y)
                local width = height / 1.9
                
                local isTargeted = (lockedCamTarget and lockedCamTarget.Parent == char) or (lockedSilentTarget and lockedSilentTarget.Parent == char)
                local renderColor = isTargeted and targColor or baseColor
                
                esp.nameTag.Position = Vector2.new(headPos.X, headPos.Y - 14)
                esp.nameTag.Text = (player.DisplayName ~= "") and player.DisplayName or player.Name
                esp.nameTag.Color = renderColor
                esp.nameTag.Visible = true
                
                if c['Box'] then
                    esp.box.Size = Vector2.new(width, height)
                    esp.box.Position = Vector2.new(headPos.X - width/2, headPos.Y)
                    esp.box.Color = renderColor
                    esp.box.Visible = true
                else esp.box.Visible = false end
                
                if c['Distance'] then
                    esp.distTag.Position = Vector2.new(legPos.X, legPos.Y + 2)
                    esp.distTag.Text = math.floor(dist) .. "m"
                    esp.distTag.Color = renderColor
                    esp.distTag.Visible = true
                else esp.distTag.Visible = false end
                
                if c['Health'] then
                    local hpPct = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                    local hpHeight = height * hpPct
                    esp.healthBarBg.From = Vector2.new(headPos.X - width/2 - 5, headPos.Y)
                    esp.healthBarBg.To = Vector2.new(headPos.X - width/2 - 5, legPos.Y)
                    esp.healthBarBg.Visible = true
                    
                    esp.healthBar.From = Vector2.new(headPos.X - width/2 - 5, legPos.Y - hpHeight)
                    esp.healthBar.To = Vector2.new(headPos.X - width/2 - 5, legPos.Y)
                    esp.healthBar.Color = Color3.fromRGB(255 - (hpPct * 255), hpPct * 255, 0)
                    esp.healthBar.Visible = true
                else
                    esp.healthBar.Visible = false; esp.healthBarBg.Visible = false
                end
                
                if c['Skeleton'] then
                    for i, conn in ipairs(skeletonConnections) do
                        local p1 = char:FindFirstChild(conn[1])
                        local p2 = char:FindFirstChild(conn[2])
                        if p1 and p2 then
                            local pos1, s1 = Camera:WorldToViewportPoint(p1.Position)
                            local pos2, s2 = Camera:WorldToViewportPoint(p2.Position)
                            if s1 and s2 then
                                esp.skeleton[i].From = Vector2.new(pos1.X, pos1.Y)
                                esp.skeleton[i].To = Vector2.new(pos2.X, pos2.Y)
                                esp.skeleton[i].Color = renderColor
                                esp.skeleton[i].Visible = true
                            else esp.skeleton[i].Visible = false end
                        else esp.skeleton[i].Visible = false end
                    end
                else
                    for _, line in ipairs(esp.skeleton) do line.Visible = false end
                end
            else
                hideESP(esp)
            end
        else
            hideESP(esp)
        end
    end
end

for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then addESPToPlayer(player) end
    table.insert(connections, player.CharacterAdded:Connect(function(char) removeESPFromPlayer(player); char:WaitForChild("HumanoidRootPart"); task.wait(0.1); addESPToPlayer(player) end))
    table.insert(connections, player.CharacterRemoving:Connect(function() removeESPFromPlayer(player) end))
end
table.insert(connections, Players.PlayerAdded:Connect(function(player)
    table.insert(connections, player.CharacterAdded:Connect(function(char) task.wait(0.5); addESPToPlayer(player) end))
    table.insert(connections, player.CharacterRemoving:Connect(function() removeESPFromPlayer(player) end))
end))
table.insert(connections, Players.PlayerRemoving:Connect(function(player) removeESPFromPlayer(player) end))


local function ProcessKeybind(feature, state)
    local cfg = Config[feature]
    if not cfg or not cfg['Enabled'] then return end
    
    if state == Enum.UserInputState.Begin then
        if cfg['Mode'] == 'Toggle' then
            cfg['Active'] = not cfg['Active']
        else
            cfg['Active'] = true
        end
    elseif state == Enum.UserInputState.End and cfg['Mode'] == 'Hold' then
        cfg['Active'] = false
    end
end

table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode.Name == Config['Settings']['Menu Toggle Key'] then menuOpen = not menuOpen; MainFrame.Visible = menuOpen end

    local featureMap = {"Trigger Bot", "Speed", "Fly", "Super Jump", "Infinite Range", "Hitbox Expander", "Spread"}
    for _, f in ipairs(featureMap) do
        local ok, key = pcall(function() return Enum.KeyCode[Config[f]['Key']] end)
        if ok and input.KeyCode == key then ProcessKeybind(f, Enum.UserInputState.Begin) end
    end

    local okLock, lockKey = pcall(function() return Enum.KeyCode[Config['Camera Lock']['Key']] end)
    if okLock and input.KeyCode == lockKey and Config['Camera Lock']['Enabled'] then
        ProcessKeybind("Camera Lock", Enum.UserInputState.Begin)
        if Config['Camera Lock']['Active'] then
            lockedCamTarget = findClosestTarget(Config['Camera Lock']['Hit Part'])
            isLocking = lockedCamTarget ~= nil
            if not isLocking then Config['Camera Lock']['Active'] = false end
        else lockedCamTarget = nil; isLocking = false end
    end
    
    local okSA, saKey = pcall(function() return Enum.KeyCode[Config['Silent Aim']['Key']] end)
    if okSA and input.KeyCode == saKey and Config['Silent Aim']['Enabled'] then
        ProcessKeybind("Silent Aim", Enum.UserInputState.Begin)
        lockedSilentTarget = Config['Silent Aim']['Active'] and findClosestTarget(Config['Silent Aim']['Hit Part']) or nil
        if Config['Silent Aim']['Active'] and not lockedSilentTarget then Config['Silent Aim']['Active'] = false end
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then rapidFireMB1 = true end
end))

table.insert(connections, UserInputService.InputEnded:Connect(function(input, processed)
    if processed then return end
    local featureMap = {"Camera Lock", "Trigger Bot", "Speed", "Fly", "Super Jump", "Infinite Range", "Hitbox Expander", "Spread", "Silent Aim"}
    for _, f in ipairs(featureMap) do
        local ok, key = pcall(function() return Enum.KeyCode[Config[f]['Key']] end)
        if ok and input.KeyCode == key then
            ProcessKeybind(f, Enum.UserInputState.End)
            if f == "Camera Lock" and Config['Camera Lock']['Mode'] == 'Hold' then lockedCamTarget = nil; isLocking = false end
            if f == "Silent Aim" and Config['Silent Aim']['Mode'] == 'Hold' then lockedSilentTarget = nil end
        end
    end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then rapidFireMB1 = false end
end))


table.insert(connections, RunService.RenderStepped:Connect(function(dt)
    if isUnloaded then return end
    
    -- FIXED: Camera Lock applies FIRST so ESP calculations sync flawlessly
    safeCall(function()
        if Config['Camera Lock']['Enabled'] and isLocking then applyCameraLock() end
    end)
    
    safeCall(function() refreshESP() end)
    
    safeCall(function()
        if isSelfKnocked() then
            lockedCamTarget = nil; isLocking = false; Config['Camera Lock']['Active'] = false
            lockedSilentTarget = nil; Config['Silent Aim']['Active'] = false
        end
    end)
    
    safeCall(function() TriggerBot() end)
    
    safeCall(function()
        if Config['Speed']['Active'] and Config['Speed']['Enabled'] then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChild("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.MoveDirection.Magnitude > 0 then
                hrp.CFrame = hrp.CFrame + (hum.MoveDirection * (Config['Speed']['Multiplier'] * dt))
            end
        end
    end)

    safeCall(function()
        if Config['Fly']['Active'] and Config['Fly']['Enabled'] then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local moveDir = Vector3.new()
                local camCFrame = Camera.CFrame
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camCFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camCFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camCFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camCFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end
                
                if not flyBV then
                    flyBV = Instance.new("BodyVelocity", hrp)
                    flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                end
                flyBV.Velocity = moveDir * Config['Fly']['Speed']
            end
        else
            if flyBV then flyBV:Destroy(); flyBV = nil end
        end
    end)
    
    safeCall(function()
        if Config['Hitbox Expander']['Active'] and Config['Hitbox Expander']['Enabled'] then
            local sizeValue = Config['Hitbox Expander']['Size']
            local beSolid = Config['Hitbox Expander']['Solid']
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then 
                        hrp.Size = Vector3.new(sizeValue, sizeValue, sizeValue)
                        hrp.Transparency = 0.75
                        hrp.Massless = true 
                        hrp.CanCollide = beSolid 
                    end
                end
            end
        else
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then 
                        hrp.Size = Vector3.new(2, 2, 1)
                        hrp.Transparency = 1
                        hrp.Massless = false 
                        hrp.CanCollide = false 
                    end
                end
            end
        end
    end)
    
    safeCall(function()
        if Config['Infinite Range']['Active'] and Config['Infinite Range']['Enabled'] then
            local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
            if tool then
                local maxRangeVal = Config['Infinite Range']['Max Range']
                for _, v in pairs(tool:GetDescendants()) do
                    if v:IsA("NumberValue") or v:IsA("IntValue") then
                        local lName = string.lower(v.Name)
                        if string.find(lName, "range") or string.find(lName, "dist") or string.find(lName, "max") then
                            v.Value = maxRangeVal
                        end
                    end
                end
                pcall(function()
                    for attrName, _ in pairs(tool:GetAttributes()) do
                        if string.find(string.lower(attrName), "range") or string.find(string.lower(attrName), "dist") then
                            tool:SetAttribute(attrName, maxRangeVal)
                        end
                    end
                end)
            end
        end
    end)
end))

table.insert(connections, RunService.Heartbeat:Connect(function()
    if isUnloaded then return end
    
    safeCall(function()
        if Config['Super Jump']['Active'] and Config['Super Jump']['Enabled'] then
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            if humanoid and rootPart and (humanoid:GetState() == Enum.HumanoidStateType.Landed or humanoid.FloorMaterial ~= Enum.Material.Air) then
                rootPart.Velocity = Vector3.new(rootPart.Velocity.X, Config['Super Jump']['Power'], rootPart.Velocity.Z)
            end
        end
    end)
    
    safeCall(function()
        if Config['Rapid Fire']['Enabled'] and rapidFireMB1 then
            local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
            if tool then
                tool:Activate()
                task.delay(0.001, function() pcall(function() tool:Deactivate() end) end)
            end
        end
    end)
end))


safeCall(function()
    if ScreenGui:FindFirstChild("NeoServicesStatusHUD") then ScreenGui.NeoServicesStatusHUD:Destroy() end

    local hudFrame = Instance.new("Frame", ScreenGui)
    hudFrame.Name = "NeoServicesStatusHUD"
    hudFrame.Size = UDim2.new(0, 180, 0, 180); hudFrame.Position = UDim2.new(0.5, -100, 1, -220)
    hudFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20); hudFrame.BackgroundTransparency = 0.15; hudFrame.Active = true
    Instance.new("UICorner", hudFrame).CornerRadius = UDim.new(0, 6)
    
    hudStroke = Instance.new("UIStroke", hudFrame)
    hudStroke.Color = currentTheme.Accent; hudStroke.Thickness = 1.5

    local hudDragging, hudDragInput, hudDragStart, hudStartPos
    table.insert(connections, hudFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            hudDragging = true; hudDragStart = input.Position; hudStartPos = hudFrame.Position
            local conn; conn = input.Changed:Connect(function() 
                if input.UserInputState == Enum.UserInputState.End then hudDragging = false; conn:Disconnect() end 
            end)
        end
    end))
    table.insert(connections, hudFrame.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then hudDragInput = input end end))
    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if hudDragging and input == hudDragInput then
            local delta = input.Position - hudDragStart
            hudFrame.Position = UDim2.new(hudStartPos.X.Scale, hudStartPos.X.Offset + delta.X, hudStartPos.Y.Scale, hudStartPos.Y.Offset + delta.Y)
        end
    end))

    local titleBar = Instance.new("Frame", hudFrame)
    titleBar.Size = UDim2.new(1, 0, 0, 25); titleBar.BackgroundColor3 = Color3.fromRGB(10, 10, 15); titleBar.BorderSizePixel = 0
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 6)
    
    local titleFix = Instance.new("Frame", titleBar)
    titleFix.Size = UDim2.new(1, 0, 0, 10); titleFix.Position = UDim2.new(0, 0, 1, -10); titleFix.BackgroundColor3 = Color3.fromRGB(10, 10, 15); titleFix.BorderSizePixel = 0

    local title = Instance.new("TextLabel", titleBar)
    title.Size = UDim2.new(1, 0, 1, 0); title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBlack; title.TextSize = 12
    title.TextColor3 = Color3.fromRGB(255, 255, 255); title.Text = "ACTIVE KEYBINDS"
    
    local line = Instance.new("Frame", hudFrame)
    line.Size = UDim2.new(1, -20, 0, 1); line.Position = UDim2.new(0, 10, 0, 25); line.BackgroundColor3 = Color3.fromRGB(50, 50, 60); line.BorderSizePixel = 0

    local listFrame = Instance.new("Frame", hudFrame)
    listFrame.Size = UDim2.new(1, 0, 1, -30); listFrame.Position = UDim2.new(0, 0, 0, 30); listFrame.BackgroundTransparency = 1
    
    local listLayout = Instance.new("UIListLayout", listFrame)
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 4)

    local HUD_Features = {"Speed", "Silent Aim", "Camera Lock", "Trigger Bot", "Infinite Range", "Hitbox Expander", "Fly", "Super Jump", "Spread"}
    local lineFrames = {}

    for _, fName in ipairs(HUD_Features) do
        local entry = Instance.new("Frame", listFrame)
        entry.Size = UDim2.new(1, 0, 0, 16); entry.BackgroundTransparency = 1
        
        local fLbl = Instance.new("TextLabel", entry)
        fLbl.Size = UDim2.new(0.5, -5, 1, 0); fLbl.BackgroundTransparency = 1; fLbl.Font = Enum.Font.GothamBold; fLbl.TextSize = 11
        fLbl.TextColor3 = Color3.fromRGB(180, 0, 0); fLbl.TextXAlignment = Enum.TextXAlignment.Right; fLbl.Text = string.lower(fName:gsub(" ", "-"))

        local sLbl = Instance.new("TextLabel", entry)
        sLbl.Size = UDim2.new(0.5, -5, 1, 0); sLbl.Position = UDim2.new(0.5, 5, 0, 0); sLbl.BackgroundTransparency = 1; sLbl.Font = Enum.Font.GothamBold
        sLbl.TextSize = 11; sLbl.TextXAlignment = Enum.TextXAlignment.Left

        lineFrames[fName] = {frame = entry, stateLbl = sLbl}
    end

    table.insert(connections, RunService.RenderStepped:Connect(function()
        if not Config['Settings'] or type(Config['Settings']['Show HUD']) == "nil" or isUnloaded then return end
        hudFrame.Visible = Config['Settings']['Show HUD']
        if not hudFrame.Visible then return end
        
        local activeStates = {
            ["Speed"] = Config['Speed']['Active'], ["Silent Aim"] = Config['Silent Aim']['Active'], ["Camera Lock"] = isLocking,
            ["Trigger Bot"] = Config['Trigger Bot']['Active'], ["Infinite Range"] = Config['Infinite Range']['Active'],
            ["Hitbox Expander"] = Config['Hitbox Expander']['Active'], ["Fly"] = Config['Fly']['Active'],
            ["Super Jump"] = Config['Super Jump']['Active'], ["Spread"] = Config['Spread']['Active']
        }
        
        local visibleCount = 0
        for fName, data in pairs(lineFrames) do
            if Config[fName] and Config[fName]['Enabled'] then
                data.frame.Visible = true
                visibleCount = visibleCount + 1
                if activeStates[fName] then
                    data.stateLbl.Text = "[ACTIVE]"; data.stateLbl.TextColor3 = Color3.fromRGB(50, 205, 50)
                else
                    data.stateLbl.Text = "[IDLE]"; data.stateLbl.TextColor3 = Color3.fromRGB(100, 100, 100)
                end
            else
                data.frame.Visible = false
            end
        end
        
        hudFrame.Size = UDim2.new(0, 180, 0, 35 + (visibleCount * 20))
    end))
end)

print("NeoServices Loaded. Press " .. Config['Settings']['Menu Toggle Key'] .. " to toggle menu.")

end)
if not scriptOk then warn("[NeoServices] Load Error: " .. tostring(scriptErr)) end
