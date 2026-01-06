-- Неймспейс аддона
local AddonName, Addon = ...

-- Локальные ссылки на часто используемые данные
local db, absorbFrame

-- Функция инициализации локальных ссылок
local function InitModuleReferences()
    db = Addon.db
    absorbFrame = Addon.absorbFrame
end

-- ---------------------------------------------------------------------------
-- GUI Настроек (Options Frame)
-- ---------------------------------------------------------------------------

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

function Addon.CreateConfigFrame()
    InitModuleReferences()

    -- Создаём фрейм
    local f = CreateFrame("Frame", "SimpleAbsorbConfigFrame", UIParent, "BackdropTemplate")
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

    -- Весь фрейм можно перетаскивать
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

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
            Addon.UpdateBackgroundColor()  -- Обновляем фон при изменении состояния блокировки
        end
    end)
    f.lockCheck = lockCheck

    -- Поле ввода X с поддержкой отрицательных чисел
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

    -- Поле ввода Y с поддержкой отрицательных чисел
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

    -- Лейбл для шрифтов
    local fontLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fontLabel:SetPoint("TOPLEFT", yLabel, "BOTTOMLEFT", 0, -20)
    fontLabel:SetText("Font:")

    -- Дропдаун шрифтов
    local fontDropdown = CreateFrame("Frame", "SimpleAbsorbFontDropdown", f, "UIDropDownMenuTemplate")
    fontDropdown:SetPoint("LEFT", fontLabel, "BOTTOMLEFT", -20, -20)

    local function OnSelect(self)
        db.font = self.value
        UIDropDownMenu_SetSelectedValue(fontDropdown, self.value)
        UIDropDownMenu_SetText(fontDropdown, self.value)
        Addon.UpdateFont()
    end

    local function InitializeDropdown()
        local info = UIDropDownMenu_CreateInfo()
        local fonts = {}

        if Addon.LSM then
            local list = Addon.LSM:List("font")
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

    UIDropDownMenu_Initialize(fontDropdown, InitializeDropdown)
    UIDropDownMenu_SetWidth(fontDropdown, 180)

    -- ИСПРАВЛЕНИЕ: Принудительная установка текста и значения после инициализации
    UIDropDownMenu_SetSelectedValue(fontDropdown, db.font)
    UIDropDownMenu_SetText(fontDropdown, db.font)

    f.dropdown = fontDropdown

    -- Лейбл для размера шрифта
    local fontSizeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fontSizeLabel:SetPoint("TOPLEFT", fontDropdown, "BOTTOMLEFT", 20, -10)
    fontSizeLabel:SetText("Font Size:")

    -- Поле ввода размера шрифта
    local fontSizeInput = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    fontSizeInput:SetSize(60, 20)
    fontSizeInput:SetPoint("LEFT", fontSizeLabel, "RIGHT", 10, 0)
    fontSizeInput:SetAutoFocus(false)
    fontSizeInput:SetText(tostring(db.fontSize or 24))

    -- Кастомная проверка для поддержки только чисел
    fontSizeInput:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            local text = self:GetText()
            -- Разрешаем только числа
            if text == "" or text:match("^%d+$") then
                self:GetParent().fontSizeInput.oldText = text
            else
                self:SetText(self.oldText or "")
            end
        end
    end)

    fontSizeInput:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if text == "" then
            text = "24"
            self:SetText("24")
        end

        local val = tonumber(text)
        if val then
            -- Ограничиваем разумными значениями
            val = math.max(8, math.min(72, val))  -- Минимум 8, максимум 72
            db.fontSize = val
            self:SetText(tostring(val))

            if Addon.UpdateFont then
                Addon.UpdateFont()
            end
        end
        self:ClearFocus()
    end)

    fontSizeInput:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(db.fontSize or 24))
        self:ClearFocus()
    end)

    f.fontSizeInput = fontSizeInput

    -- Слайдер для размера шрифта (опционально, но удобнее)
    local fontSizeSlider = CreateFrame("Slider", "SimpleAbsorbFontSizeSlider", f, "OptionsSliderTemplate")
    fontSizeSlider:SetPoint("LEFT", fontSizeInput, "RIGHT", 20, 0)
    fontSizeSlider:SetWidth(100)
    fontSizeSlider:SetMinMaxValues(8, 72)  -- Минимум 8, максимум 72
    fontSizeSlider:SetValueStep(1)
    fontSizeSlider:SetValue(db.fontSize or 24)
    _G[fontSizeSlider:GetName() .. "Low"]:SetText("8")
    _G[fontSizeSlider:GetName() .. "High"]:SetText("72")
    _G[fontSizeSlider:GetName() .. "Text"]:SetText(tostring(db.fontSize or 24))

    fontSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        db.fontSize = value
        _G[self:GetName() .. "Text"]:SetText(tostring(value))

        -- Обновляем текстовое поле
        if not fontSizeInput:HasFocus() then
            fontSizeInput:SetText(tostring(value))
            fontSizeInput.oldText = tostring(value)
        end

        if Addon.UpdateFont then
            Addon.UpdateFont()
        end
    end)

    -- Синхронизация слайдера и текстового поля
    fontSizeInput:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            local text = self:GetText()
            -- Разрешаем только числа
            if text == "" or text:match("^%d+$") then
                self:GetParent().fontSizeInput.oldText = text

                -- Обновляем слайдер
                local val = tonumber(text)
                if val then
                    val = math.max(8, math.min(72, val))
                    fontSizeSlider:SetValue(val)
                end
            else
                self:SetText(self.oldText or "")
            end
        end
    end)

    -- Color Picker для цвета текста
    local fontColorContainer, _, updateFontColorFunc = CreateColorPickerButton(f, "Font Color", db.fontColor, Addon.UpdateFont)
    fontColorContainer:SetPoint("TOPLEFT", fontSizeLabel, "BOTTOMLEFT", 0, -10)
    f._updateFontColor = updateFontColorFunc

    -- Color Picker для цвета бэкграунда
    local bgColorContainer, _, updateBgColorFunc = CreateColorPickerButton(f, "Background Color", db.bgColor, Addon.UpdateBackgroundColor)
    bgColorContainer:SetPoint("TOPLEFT", fontColorContainer, "BOTTOMLEFT", 0, -10)
    f._updateBgColor = updateBgColorFunc

    -- Чекбокс "Обесцветить когда 0"
    local desaturateCheck = CreateFrame("CheckButton", "SimpleAbsorbDesaturateCheck", f, "UICheckButtonTemplate")
    desaturateCheck:SetPoint("TOPLEFT", bgColorContainer, "BOTTOMLEFT", 0, -10)
    _G[desaturateCheck:GetName() .. "Text"]:SetText("Desaturate at 0")

    desaturateCheck:SetChecked(db.desaturateAtZero or false)
    desaturateCheck:SetScript("OnClick", function(self)
        db.desaturateAtZero = self:GetChecked()
    end)

    f.desaturateCheck = desaturateCheck

    -- Функция обновления полей ввода (используется вне этого файла)
    function f:UpdateInputs()
        if not self.xInput:HasFocus() then
            local newX = math.floor(db.x or 0)
            self.xInput:SetText(newX)
            self.xInput.oldText = newX
        end
        if not self.yInput:HasFocus() then
            local newY = math.floor(db.y or 0)
            self.yInput:SetText(newY)
            self.yInput.oldText = newY
        end
    end

    return f
end