-- TemOS GUI Library
local component = require("component")
local computer = require("computer")
local event = require("event")
local unicode = require("unicode")

local gui = {}

-- Основные компоненты
local gpu = component.list("gpu")()
local screen = component.list("screen")()
local gpu_proxy = gpu and component.proxy(gpu) or nil

-- Цветовая схема
gui.colors = {
    background = 0x1E1E1E,
    header_bg = 0x2D2D2D,
    header_text = 0xFFFFFF,
    text = 0xCCCCCC,
    accent = 0x0078D7,
    button = 0x0078D7,
    button_hover = 0x106EBE,
    button_text = 0xFFFFFF,
    input_bg = 0x3C3C3C,
    input_text = 0xFFFFFF,
    error = 0xFF4444,
    success = 0x00AA00,
    warning = 0xFFAA00
}

-- Текущее состояние GUI
gui.state = {
    screen_width = 80,
    screen_height = 25,
    focused_element = nil,
    hover_element = nil
}

-- Инициализация GUI
function gui.initialize()
    if not gpu or not screen then
        return false, "Требуется GPU и экран"
    end
    
    if not pcall(gpu_proxy.bind, screen) then
        return false, "Не удалось подключить GPU к экрану"
    end
    
    gpu_proxy.setResolution(gpu_proxy.maxResolution())
    gui.state.screen_width, gui.state.screen_height = gpu_proxy.getResolution()
    
    return true
end

-- Базовые функции отрисовки
function gui.setColor(foreground, background)
    if gpu_proxy then
        if foreground then gpu_proxy.setForeground(foreground) end
        if background then gpu_proxy.setBackground(background) end
    end
end

function gui.drawRect(x, y, width, height, color)
    if gpu_proxy then
        gui.setColor(nil, color)
        gpu_proxy.fill(x, y, width, height, " ")
    end
end

function gui.drawText(x, y, text, color)
    if gpu_proxy then
        gui.setColor(color, nil)
        gpu_proxy.set(x, y, text)
    end
end

function gui.clearScreen(color)
    color = color or gui.colors.background
    gui.drawRect(1, 1, gui.state.screen_width, gui.state.screen_height, color)
end

-- Элементы GUI
function gui.createWindow(title, x, y, width, height)
    local window = {
        type = "window",
        x = x or 2,
        y = y or 2,
        width = width or (gui.state.screen_width - 4),
        height = height or (gui.state.screen_height - 4),
        title = title or "Окно",
        elements = {},
        visible = true
    }
    
    function window:draw()
        if not self.visible then return end
        
        -- Фон окна
        gui.drawRect(self.x, self.y, self.width, self.height, gui.colors.background)
        
        -- Заголовок окна
        gui.drawRect(self.x, self.y, self.width, 1, gui.colors.header_bg)
        local title_text = " " .. self.title
        if unicode.len(title_text) > self.width - 2 then
            title_text = unicode.sub(title_text, 1, self.width - 5) .. "..."
        end
        gui.drawText(self.x + 1, self.y, title_text, gui.colors.header_text)
        
        -- Рамка окна
        gui.setColor(gui.colors.accent, nil)
        gpu_proxy.set(self.x, self.y, "┌")
        gpu_proxy.set(self.x + self.width - 1, self.y, "┐")
        gpu_proxy.set(self.x, self.y + self.height - 1, "└")
        gpu_proxy.set(self.x + self.width - 1, self.y + self.height - 1, "┘")
        
        -- Вертикальные линии
        for i = 1, self.height - 2 do
            gpu_proxy.set(self.x, self.y + i, "│")
            gpu_proxy.set(self.x + self.width - 1, self.y + i, "│")
        end
        
        -- Горизонтальные линии
        for i = 1, self.width - 2 do
            gpu_proxy.set(self.x + i, self.y, "─")
            gpu_proxy.set(self.x + i, self.y + self.height - 1, "─")
        end
        
        -- Отрисовка дочерних элементов
        for _, element in ipairs(self.elements) do
            if element.draw then
                element:draw()
            end
        end
    end
    
    function window:addElement(element)
        table.insert(self.elements, element)
        element.parent = self
        return element
    end
    
    function window:handleEvent(event, ...)
        if not self.visible then return false end
        
        for _, element in ipairs(self.elements) do
            if element.handleEvent and element:handleEvent(event, ...) then
                return true
            end
        end
        return false
    end
    
    return window
end

function gui.createButton(parent, text, x, y, width, height, onClick)
    local button = {
        type = "button",
        x = x or 1,
        y = y or 1,
        width = width or 10,
        height = height or 1,
        text = text or "Кнопка",
        onClick = onClick,
        enabled = true,
        hover = false,
        parent = parent
    }
    
    function button:draw()
        if not self.parent.visible then return end
        
        local abs_x = self.parent.x + self.x
        local abs_y = self.parent.y + self.y
        
        local bg_color = self.enabled and 
                        (self.hover and gui.colors.button_hover or gui.colors.button) or
                        0x555555
        
        gui.drawRect(abs_x, abs_y, self.width, self.height, bg_color)
        
        -- Центрирование текста
        local text_x = abs_x + math.floor((self.width - unicode.len(self.text)) / 2)
        local text_y = abs_y + math.floor(self.height / 2)
        gui.drawText(text_x, text_y, self.text, gui.colors.button_text)
    end
    
    function button:handleEvent(event, ...)
        if not self.enabled then return false end
        
        if event == "touch" then
            local _, _, x, y = ...
            local abs_x = self.parent.x + self.x
            local abs_y = self.parent.y + self.y
            
            if x >= abs_x and x < abs_x + self.width and
               y >= abs_y and y < abs_y + self.height then
                if self.onClick then
                    self.onClick(self)
                end
                return true
            end
        elseif event == "hover" then
            local _, _, x, y = ...
            local abs_x = self.parent.x + self.x
            local abs_y = self.parent.y + self.y
            
            local was_hover = self.hover
            self.hover = (x >= abs_x and x < abs_x + self.width and
                         y >= abs_y and y < abs_y + self.height)
            
            if was_hover ~= self.hover then
                self:draw()
            end
        end
        
        return false
    end
    
    if parent then
        parent:addElement(button)
    end
    
    return button
end

function gui.createLabel(parent, text, x, y, color)
    local label = {
        type = "label",
        x = x or 1,
        y = y or 1,
        text = text or "",
        color = color or gui.colors.text,
        parent = parent
    }
    
    function label:draw()
        if not self.parent.visible then return end
        
        local abs_x = self.parent.x + self.x
        local abs_y = self.parent.y + self.y
        
        gui.drawText(abs_x, abs_y, self.text, self.color)
    end
    
    if parent then
        parent:addElement(label)
    end
    
    return label
end

function gui.createInput(parent, x, y, width, placeholder, onEnter)
    local input = {
        type = "input",
        x = x or 1,
        y = y or 1,
        width = width or 20,
        height = 1,
        text = "",
        placeholder = placeholder or "",
        focused = false,
        onEnter = onEnter,
        parent = parent
    }
    
    function input:draw()
        if not self.parent.visible then return end
        
        local abs_x = self.parent.x + self.x
        local abs_y = self.parent.y + self.y
        
        local bg_color = self.focused and 0x4A4A4A or gui.colors.input_bg
        gui.drawRect(abs_x, abs_y, self.width, 1, bg_color)
        
        local display_text = self.text
        if display_text == "" and not self.focused then
            display_text = self.placeholder
            gui.drawText(abs_x, abs_y, display_text, 0x888888)
        else
            if unicode.len(display_text) > self.width - 1 then
                display_text = unicode.sub(display_text, -self.width + 2)
            end
            if self.focused then
                display_text = display_text .. "_"
            end
            gui.drawText(abs_x, abs_y, display_text, gui.colors.input_text)
        end
    end
    
    function input:handleEvent(event, ...)
        if event == "touch" then
            local _, _, x, y = ...
            local abs_x = self.parent.x + self.x
            local abs_y = self.parent.y + self.y
            
            if x >= abs_x and x < abs_x + self.width and
               y >= abs_y and y < abs_y + 1 then
                self.focused = true
                gui.state.focused_element = self
                self:draw()
                return true
            elseif self.focused then
                self.focused = false
                gui.state.focused_element = nil
                self:draw()
            end
        elseif event == "key_down" and self.focused then
            local _, _, char, code = ...
            
            if code == 13 then -- Enter
                if self.onEnter then
                    self.onEnter(self.text)
                end
                self.focused = false
                gui.state.focused_element = nil
            elseif code == 8 then -- Backspace
                self.text = unicode.sub(self.text, 1, -2)
            elseif char >= 32 and char <= 126 then -- Printable characters
                self.text = self.text .. string.char(char)
            end
            
            self:draw()
            return true
        end
        
        return false
    end
    
    if parent then
        parent:addElement(input)
    end
    
    return input
end

-- Диалоговые окна
function gui.showMessage(title, message, buttons)
    local window = gui.createWindow(title or "Сообщение", 
        math.floor((gui.state.screen_width - 40) / 2),
        math.floor((gui.state.screen_height - 10) / 2),
        40, 10)
    
    local label = gui.createLabel(window, message, 2, 3)
    label.width = 36
    
    local result = nil
    local button_width = math.floor(36 / (#buttons or 1))
    
    for i, button_text in ipairs(buttons or {"OK"}) do
        gui.createButton(window, button_text, 
            math.floor((40 - button_width) / 2) + (i-1)*button_width, 
            7, button_width - 1, 1,
            function()
                result = button_text
            end)
    end
    
    while result == nil do
        gui.handleEvents()
        computer.pullSignal(0.1)
    end
    
    return result
end

function gui.showInputDialog(title, message, default)
    local window = gui.createWindow(title or "Ввод", 
        math.floor((gui.state.screen_width - 40) / 2),
        math.floor((gui.state.screen_height - 8) / 2),
        40, 8)
    
    gui.createLabel(window, message, 2, 2)
    
    local input = gui.createInput(window, 2, 4, 36, "Введите текст...")
    if default then
        input.text = default
    end
    
    local result = nil
    
    gui.createButton(window, "OK", 15, 6, 10, 1, function()
        result = input.text
    end)
    
    gui.createButton(window, "Отмена", 27, 6, 10, 1, function()
        result = nil
    end)
    
    while result == nil do
        gui.handleEvents()
        computer.pullSignal(0.1)
    end
    
    return result
end

-- Основной цикл обработки событий
function gui.handleEvents()
    local event_data = {event.pull(0.1)}
    if #event_data > 0 then
        local event_name = event_data[1]
        
        -- Обработка hover событий
        if event_name == "touch" or event_name == "drag" then
            event.push("hover", event_data[2], event_data[3], event_data[4])
        end
        
        -- Передача событий активным окнам
        for _, window in ipairs(gui.windows or {}) do
            if window:handleEvent(unpack(event_data)) then
                break
            end
        end
    end
end

-- Управление окнами
gui.windows = {}

function gui.addWindow(window)
    table.insert(gui.windows, window)
    window:draw()
end

function gui.removeWindow(window)
    for i, win in ipairs(gui.windows) do
        if win == window then
            table.remove(gui.windows, i)
            break
        end
    end
    gui.clearScreen()
    for _, win in ipairs(gui.windows) do
        win:draw()
    end
end

-- Утилиты
function gui.centeredText(text, y, color)
    local x = math.floor((gui.state.screen_width - unicode.len(text)) / 2)
    gui.drawText(x, y, text, color or gui.colors.text)
end

function gui.progressBar(x, y, width, height, progress, text)
    progress = math.max(0, math.min(100, progress or 0))
    
    -- Фон
    gui.drawRect(x, y, width, height, gui.colors.progress_bg or 0x444444)
    
    -- Заполненная часть
    local fill_width = math.max(1, math.floor(width * progress / 100))
    if fill_width > 0 then
        gui.drawRect(x, y, fill_width, height, gui.colors.progress_fg or 0x00AA00)
    end
    
    -- Текст
    if text then
        local text_x = x + math.floor((width - unicode.len(text)) / 2)
        local text_y = y + math.floor(height / 2)
        gui.drawText(text_x, text_y, text, gui.colors.text)
    end
end

-- Экран загрузки
function gui.showLoadingScreen(message)
    gui.clearScreen()
    gui.centeredText("TemOS v1.0", math.floor(gui.state.screen_height / 2) - 2, gui.colors.header_text)
    
    if message then
        gui.centeredText(message, math.floor(gui.state.screen_height / 2), gui.colors.text)
    end
    
    gui.progressBar(
        math.floor((gui.state.screen_width - 40) / 2),
        math.floor(gui.state.screen_height / 2) + 2,
        40, 2, 0, "Загрузка..."
    )
end

return gui
