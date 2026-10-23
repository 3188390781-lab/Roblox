-- Roblox Delta (自带旧功能自动清理 + 其他人透视 + 自己血量左上角)
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

-- ==========================================
-- 【全局清理：清除上一次执行该脚本留下的所有东西】
-- ==========================================

-- 1. 清理并销毁左上角自己血量的旧 UI
if CoreGui:FindFirstChild("Self_Health_GUI") then
    pcall(function() CoreGui.Self_Health_GUI:Destroy() end)
end

-- 2. 清理所有其他玩家身上残余的旧透视组件和死循环线程
for _, player in ipairs(Players:GetPlayers()) do
    if player.Character then
        -- 销毁旧高亮框
        local oldHighlight = player.Character:FindFirstChild("White_Highlight")
        if oldHighlight then pcall(function() oldHighlight:Destroy() end) end
        
        -- 销毁旧头顶标签
        local oldBillboard = player.Character:FindFirstChild("White_Billboard")
        if oldBillboard then pcall(function() oldBillboard:Destroy() end) end
    end
end

-- 3. 释放之前脚本占用的全局变量/线程（如果存在）
if _G.OldESPConnections then
    for _, conn in ipairs(_G.OldESPConnections) do
        pcall(function() conn:Disconnect() end)
    end
end
_G.OldESPConnections = {} -- 创建全新的连接池存放本次的线程

-- ==========================================
-- 【重新构建功能 1：创建左上角自己血量小 UI】
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Self_Health_GUI"
screenGui.Parent = CoreGui
screenGui.ResetOnSpawn = false

local selfLabel = Instance.new("TextLabel")
selfLabel.Parent = screenGui
selfLabel.Size = UDim2.new(0, 120, 0, 20)
selfLabel.Position = UDim2.new(0, 15, 0, 45) -- 避开手机状态栏
selfLabel.BackgroundTransparency = 0.6
selfLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
selfLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
selfLabel.TextSize = 11
selfLabel.Font = Enum.Font.SourceSansBold
selfLabel.TextXAlignment = Enum.TextXAlignment.Left

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 4)
uiCorner.Parent = selfLabel

local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingLeft = UDim.new(0, 5)
uiPadding.Parent = selfLabel

-- 绑定自己血量的刷新线程，并存入连接池
local selfConnection = RunService.RenderStepped:Connect(function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        local myHumanoid = LocalPlayer.Character.Humanoid
        selfLabel.Text = string.format("💚 我的血量: %d/%d", math.floor(myHumanoid.Health), math.floor(myHumanoid.MaxHealth))
    else
        selfLabel.Text = "💚 我的血量: 载入中..."
    end
end)
table.insert(_G.OldESPConnections, selfConnection)

-- ==========================================
-- 【重新构建功能 2：其他人完整透视，自己无框】
-- ==========================================
local function createWhiteESP(player)
    if player == LocalPlayer then return end

    local function applyESP(character)
        if not character then return end
        
        local humanoid = character:WaitForChild("Humanoid", 15)
        local rootPart = character:WaitForChild("HumanoidRootPart", 15)
        if not humanoid or not rootPart then return end

        -- 再次确保单人身上无重复组件
        if character:FindFirstChild("White_Highlight") then character.White_Highlight:Destroy() end
        if character:FindFirstChild("White_Billboard") then character.White_Billboard:Destroy() end

        -- 1. 创建高亮外框
        local highlight = Instance.new("Highlight")
        highlight.Name = "White_Highlight"
        highlight.Parent = character
        highlight.Adornee = character
        highlight.FillColor = Color3.fromRGB(255, 255, 255)
        highlight.FillTransparency = 0.5
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.OutlineTransparency = 0

        -- 2. 创建头部信息标签
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "White_Billboard"
        billboard.Parent = character
        billboard.Adornee = rootPart
        billboard.Size = UDim2.new(0, 200, 0, 60)
        billboard.StudsOffset = Vector3.new(0, 3.5, 0)
        billboard.AlwaysOnTop = true

        local textLabel = Instance.new("TextLabel")
        textLabel.Parent = billboard
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        textLabel.TextSize = 14
        textLabel.Font = Enum.Font.SourceSansBold
        textLabel.TextStrokeTransparency = 0

        -- 3. 实时刷新其他玩家状态，并存入连接池
        local connection
        connection = RunService.RenderStepped:Connect(function()
            if not player or not player.Parent or not character or not character.Parent or not rootPart or not humanoid then
                if highlight then pcall(function() highlight:Destroy() end) end
                if billboard then pcall(function() billboard:Destroy() end) end
                if connection then connection:Disconnect() end
                return
            end

            local distance = 0
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                distance = math.floor((rootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude)
            end
            
            textLabel.Text = string.format("%s\n❤️ 血量: %d/%d\n📏 距离: %d 码", player.Name, math.floor(humanoid.Health), math.floor(humanoid.MaxHealth), distance)
        end)
        table.insert(_G.OldESPConnections, connection)

        humanoid.Died:Connect(function()
            if highlight then pcall(function() highlight:Destroy() end) end
            if billboard then pcall(function() billboard:Destroy() end) end
            if connection then connection:Disconnect() end
        end)
    end

    local charAddedConn = player.CharacterAdded:Connect(applyESP)
    table.insert(_G.OldESPConnections, charAddedConn)
    
    if player.Character then
        applyESP(player.Character)
    end
end

-- 遍历初始化
for _, player in ipairs(Players:GetPlayers()) do
    createWhiteESP(player)
end

local playerAddedConn = Players.PlayerAdded:Connect(createWhiteESP)
table.insert(_G.OldESPConnections, playerAddedConn)
