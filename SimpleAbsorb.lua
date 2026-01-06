-- Неймспейс аддона
local AddonName, SA = ...

-- Локальные переменные для быстрого доступа
local db, LSM
local absorbFrame, configFrame

-- Инициализация библиотеки LibSharedMedia
local function InitLibs()
    if LibStub then
        LSM = LibStub("LibSharedMedia-3.0", true)
    end
end

-- ---------------------------------------------------------------------------
-- Основной фрейм отображения (Текст абсорба)
-- ---------------------------------------------------------------------------

local function CreateAbsorbFrame()
    local f = CreateFrame("Frame", "SimpleAbsorbDisplayFrame", UIParent, "BackdropTemplate")
    f:SetSize(70, 70)
    f:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
    
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(not db.locked) 
    f:RegisterForDrag("LeftButton")

    local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    text:SetPoint("CENTER", f, "CENTER")
    text:SetText("0")
    f.text = text

    f:SetScript("OnDragStart", function(self)
        if db.locked then return end
        self:StartMoving()
    end)

    f:SetScript("OnDragStop", function(self)
        if db.locked then return end
        self:StopMovingOrSizing()
        
        local cx, cy = UIParent:GetCenter()
        local fx, fy = self:GetCenter()
        
        db.x = fx - cx
        db.y = fy - cy
        
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
        
        if configFrame and configFrame:IsShown() then
            configFrame:UpdateInputs()
        end
    end)

    f:SetScript("OnEvent", function(self, event, unit)
        if unit == "player" then
            local total = UnitGetTotalAbsorbs("player") or 0
            self.text:SetText(AbbreviateNumbers(total))
            self.text:Show()
        end
    end)

    f:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")

    return f
end

local function UpdateFont()
    if not absorbFrame or not absorbFrame.text then return end
    
    local fontPath
    if LSM and db.font then
        fontPath = LSM:Fetch("font", db.font, true)
    end
    
    if not fontPath then
        fontPath = STANDARD_TEXT_FONT
    end

    local size = db.fontSize or 24
    local flag = db.fontFlag or "OUTLINE"
    
    absorbFrame.text:SetFont(fontPath, size, flag)
    
    -- Применяем цвет
    if db.fontColor and type(db.fontColor) == "table" then
        absorbFrame.text:SetTextColor(unpack(db.fontColor))
    else
        absorbFrame.text:SetTextColor(1, 1, 1, 1)
    end

    -- Обновляем размер фрейма после изменения шрифта
    if absorbFrame.UpdateSize then
        absorbFrame:UpdateSize()
    end
end

local function UpdateBackgroundColor()
    if not absorbFrame then return end

    -- Устанавливаем бэкграунд
    absorbFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16
    })

    -- Применяем цвет из настроек
    if db.bgColor and type(db.bgColor) == "table" then
        local r = db.bgColor[1] or 1
        local g = db.bgColor[2] or 1
        local b = db.bgColor[3] or 1
        local a = db.bgColor[4] or 1
        absorbFrame:SetBackdropColor(r, g, b, a)
    else
        -- Цвет по умолчанию
        absorbFrame:SetBackdropColor(1, 1, 0, 1)
    end
end

-- ---------------------------------------------------------------------------
-- GUI Настроек (Options Frame)
-- ---------------------------------------------------------------------------

-- Helper: create color picker button (Аналогично SimpleSpellTimeline)
local function CreateColorPickerButton(parent, labelText, currentColor, callback)
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetSize(120, 40)

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    label:SetText(labelText)

    local colorButton = CreateFrame("Button", nil, container)
    colorButton:SetSize(60, 20)
    colorButton:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)

    -- Создаем текстуру для отображения цвета
    local colorSwatch = colorButton:CreateTexture(nil, "ARTWORK")
    colorSwatch:SetAllPoints(colorButton)

    -- Функция для обновления цвета на кнопке
    local function UpdateSwatchColor()
        if currentColor and type(currentColor) == "table" then
            local r = currentColor[1] or 1
            local g = currentColor[2] or 1
            local b = currentColor[3] or 1
            colorSwatch:SetColorTexture(r, g, b)
        else
            colorSwatch:SetColorTexture(1, 1, 1)
        end
    end

    UpdateSwatchColor()

    -- Рамка
    local border = colorButton:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", colorButton, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", colorButton, "BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0, 0, 0, 1)

    colorButton:EnableMouse(true)
    colorButton:SetScript("OnClick", function(self)
        if not currentColor or type(currentColor) ~= "table" then
            currentColor = {1, 1, 1, 1}
        end

        local r = currentColor[1] or 1
        local g = currentColor[2] or 1
        local b = currentColor[3] or 1
        local a = currentColor[4] or 1

        local function OnColorChanged()
            local newR, newG, newB = ColorPickerFrame:GetColorRGB()
            local newA = ColorPickerFrame:GetColorAlpha()
            currentColor[1] = newR
            currentColor[2] = newG
            currentColor[3] = newB
            currentColor[4] = newA
            UpdateSwatchColor()
            if callback then
                callback()
            end
        end

        ColorPickerFrame:SetupColorPickerAndShow({
            r = r,
            g = g,
            b = b,
            opacity = a,
            hasOpacity = true,  -- Включаем прозрачность для фона
            swatchFunc = OnColorChanged,
            opacityFunc = OnColorChanged,
            cancelFunc = function(previousValues)
                if previousValues then
                    currentColor[1] = previousValues.r or 1
                    currentColor[2] = previousValues.g or 1
                    currentColor[3] = previousValues.b or 1
                    currentColor[4] = previousValues.opacity or 1
                end
                UpdateSwatchColor()
            end,
        })
    end)

    return container, colorButton, UpdateSwatchColor
end

local function CreateConfigFrame()
    local f = CreateFrame("Frame", "SimpleAbsorbConfigFrame", UIParent, "BackdropTemplate")
    -- Увеличили высоту, чтобы влез Color Picker
    f:SetSize(300, 400)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    f:Hide()
    f:SetFrameStrata("DIALOG")

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    -- Весь фрейм можно перетаскивать
    f:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    -- Заголовок
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -15)
    title:SetText("SimpleAbsorb Settings")

    -- Кнопка Закрыть
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Чекбокс Lock
    local lockCheck = CreateFrame("CheckButton", "SimpleAbsorbLockCheck", f, "UICheckButtonTemplate")
    lockCheck:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -50)
    _G[lockCheck:GetName() .. "Text"]:SetText("Lock Position")

    lockCheck:SetChecked(db.locked)
    lockCheck:SetScript("OnClick", function(self)
        db.locked = self:GetChecked()
        if absorbFrame then
            absorbFrame:EnableMouse(not db.locked)
            UpdateBackgroundColor()  -- Обновляем фон при изменении состояния блокировки
        end
    end)
    f.lockCheck = lockCheck

    -- Поля ввода X и Y с поддержкой отрицательных чисел
    local xLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    xLabel:SetPoint("TOPLEFT", lockCheck, "BOTTOMLEFT", 5, -10)
    xLabel:SetText("X Position:")

    local xInput = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    xInput:SetSize(60, 20)
    xInput:SetPoint("LEFT", xLabel, "RIGHT", 10, 0)
    xInput:SetAutoFocus(false)
    xInput:SetText(math.floor(db.x or 0))

    -- Кастомная проверка для поддержки отрицательных чисел
    xInput:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            local text = self:GetText()
            -- Разрешаем: пустая строка, числа, отрицательные числа
            if text == "" or text == "-" or text:match("^%-?%d*%.?%d*$") then
                -- Валидный ввод
                self:GetParent().xInput.oldText = text
            else
                -- Невалидный ввод - восстанавливаем предыдущее значение
                self:SetText(self.oldText or "")
            end
        end
    end)

    xInput:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if text == "" or text == "-" then
            text = "0"
            self:SetText("0")
        end

        local val = tonumber(text)
        if val then
            db.x = math.floor(val)
            if absorbFrame then
                absorbFrame:ClearAllPoints()
                absorbFrame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
            end
        end
        self:ClearFocus()
    end)

    xInput:SetScript("OnEscapePressed", function(self)
        self:SetText(math.floor(db.x or 0))
        self:ClearFocus()
    end)

    f.xInput = xInput

    local yLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    yLabel:SetPoint("TOPLEFT", xLabel, "BOTTOMLEFT", 0, -20)
    yLabel:SetText("Y Position:")

    local yInput = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    yInput:SetSize(60, 20)
    yInput:SetPoint("LEFT", yLabel, "RIGHT", 10, 0)
    yInput:SetAutoFocus(false)
    yInput:SetText(math.floor(db.y or 0))

    -- Та же кастомная проверка для Y
    yInput:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            local text = self:GetText()
            if text == "" or text == "-" or text:match("^%-?%d*%.?%d*$") then
                self:GetParent().yInput.oldText = text
            else
                self:SetText(self.oldText or "")
            end
        end
    end)

    yInput:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if text == "" or text == "-" then
            text = "0"
            self:SetText("0")
        end

        local val = tonumber(text)
        if val then
            db.y = math.floor(val)
            if absorbFrame then
                absorbFrame:ClearAllPoints()
                absorbFrame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
            end
        end
        self:ClearFocus()
    end)

    yInput:SetScript("OnEscapePressed", function(self)
        self:SetText(math.floor(db.y or 0))
        self:ClearFocus()
    end)

    f.yInput = yInput

    local dropLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dropLabel:SetPoint("TOPLEFT", yLabel, "BOTTOMLEFT", 0, -20)
    dropLabel:SetText("Font:")

    -- Дропдаун шрифтов (Исправленная логика по аналогии с рабочим кодом)
    local dropdown = CreateFrame("Frame", "SimpleAbsorbFontDropdown", f, "UIDropDownMenuTemplate")
    dropdown:SetPoint("LEFT", dropLabel, "BOTTOMLEFT", -20, -20)

    -- ИСПРАВЛЕНИЕ: Функция OnClick обновляет БД, Текст Дропдауна и вызывает UpdateFont
    local function OnSelect(self)
        db.font = self.value
        UIDropDownMenu_SetSelectedValue(dropdown, self.value)
        UIDropDownMenu_SetText(dropdown, self.value)
        UpdateFont()
    end

    local function InitializeDropdown()
        local info = UIDropDownMenu_CreateInfo()
        local fonts = {}

        if LSM then
            local list = LSM:List("font")
            if list and #list > 0 then
                fonts = list
            end
        end

        if #fonts == 0 then
            fonts = { "Friz Quadrata TT", "Arial Narrow", "Skurri" }
        end

        -- Сортируем список шрифтов
        table.sort(fonts)

        for _, fontName in ipairs(fonts) do
            if fontName then
                info.text = fontName
                info.value = fontName
                info.func = OnSelect
                info.checked = (db.font == fontName)
                UIDropDownMenu_AddButton(info)
            end
        end
    end

    UIDropDownMenu_Initialize(dropdown, InitializeDropdown)
    UIDropDownMenu_SetWidth(dropdown, 180)

    -- ИСПРАВЛЕНИЕ: Принудительная установка текста и значения после инициализации
    UIDropDownMenu_SetSelectedValue(dropdown, db.font)
    UIDropDownMenu_SetText(dropdown, db.font)

    f.dropdown = dropdown

    -- Color Picker для цвета текста
    local fontColorContainer, _, updateFontColorFunc = CreateColorPickerButton(f, "Font Color", db.fontColor or {1,1,1}, UpdateFont)
    fontColorContainer:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 20, -10)
    f._updateFontColor = updateFontColorFunc

    local bgColorContainer, _, updateBgColorFunc = CreateColorPickerButton(f, "Background Color", db.bgColor, UpdateBackgroundColor)
    bgColorContainer:SetPoint("TOPLEFT", fontColorContainer, "BOTTOMLEFT", 0, -10)
    f._updateBgColor = updateBgColorFunc

    -- Функция обновления полей ввода
    function f:UpdateInputs()
        if not self.xInput:HasFocus() then
            self.xInput:SetText(math.floor(db.x or 0))
            self.xInput.oldText = math.floor(db.x or 0)
        end
        if not self.yInput:HasFocus() then
            self.yInput:SetText(math.floor(db.y or 0))
            self.yInput.oldText = math.floor(db.y or 0)
        end
    end

    return f
end

-- ---------------------------------------------------------------------------
-- Инициализация аддона
-- ---------------------------------------------------------------------------

local function OnAddonLoad(self, event, addonName)
    if addonName ~= AddonName then return end

    InitLibs()

    SimpleAbsorbDB = SimpleAbsorbDB or {}
    db = SimpleAbsorbDB
    
    if type(db.x) ~= "number" then db.x = 0 end
    if type(db.y) ~= "number" then db.y = 0 end
    
    if not db.font or type(db.font) ~= "string" then
        db.font = "Friz Quadrata TT"
        if LSM then
            local list = LSM:List("font")
            if list and list[1] then
                db.font = list[1]
            end
        end
    end

    -- Инициализация цвета по умолчанию, если нет
    if not db.fontColor or type(db.fontColor) ~= "table" then
        db.fontColor = {1, 1, 1, 1}
    end

    -- Инициализация цвета фона по умолчанию, если нет
    if not db.bgColor or type(db.bgColor) ~= "table" then
        db.bgColor = {1, 1, 0, 0.5}  -- Желтый с прозрачностью 50%
    end

    if db.locked == nil then db.locked = false end
    if type(db.fontSize) ~= "number" then db.fontSize = 24 end

    absorbFrame = CreateAbsorbFrame()
    configFrame = CreateConfigFrame()

    -- Обновляем цвета на кнопках при загрузке GUI
    if configFrame._updateFontColor then
        configFrame._updateFontColor()
    end
    if configFrame._updateBgColor then
        configFrame._updateBgColor()
    end

    UpdateFont()
    
    if absorbFrame then
        --[[absorbFrame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", tile = true, tileSize = 16 })
        absorbFrame:SetBackdropColor(1, 1, 0, 0.5)]]
        absorbFrame:EnableMouse(not db.locked)
        UpdateBackgroundColor()
    end

    SLASH_SIMPLEABSORB1 = "/sa"
    SlashCmdList["SIMPLEABSORB"] = function(msg)
        if configFrame:IsShown() then
            configFrame:Hide()
        else
            configFrame:Show()
        end
    end

    self:UnregisterEvent("ADDON_LOADED")
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", OnAddonLoad)
