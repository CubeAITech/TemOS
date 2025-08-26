-- ==============================================
-- GraphOS - Продвинутая ОС с GUI для OpenComputers
-- Версия 2.0 (Без require)
-- ==============================================

-- Проверка компонентов
if not component then
    error("Компоненты не доступны!")
end

local component = component
local computer = computer
local event = event
local term = term
local unicode = unicode
local os = os

-- Поиск компонентов
local gpu = component.list("gpu")()
local screen = component.list("screen")()

if not gpu then
    error("Требуется видеокарта!")
end
if not screen then
    error("Требуется монитор!")
end

gpu = component.proxy(gpu)
if screen then
    gpu.bind(screen)
end

-- Конфигурация системы
local config = {
    theme = {
        background = 0x1E1E2E,
        text = 0xCDD6F4,
        accent = 0x89B4FA,
        success = 0xA6E3A1,
        warning = 0xF9E2AF,
        error = 0xF38BA8,
        panel = 0x313244,
        button = 0x45475A,
        button_hover = 0x585B70,
        window = 0x1E1E2E,
        border = 0x45475A
    },
    user = {
        name = "user",
        home = "/home/user"
    },
    system = {
        hostname = "graphos-pc",
        version = "2.0"
    }
}

-- Глобальные переменные
local windows = {}
local activeWindow = nil
local mouseX, mouseY = 0, 0
local taskbarHeight = 3
local desktopIcons = {}

-- Утилиты
function printf(format, ...)
    local args = {...}
    local result = format:gsub("(%%%w)", function(match)
        if match == "%s" then
            return tostring(table.remove(args, 1) or "")
        elseif match == "%d" then
            return tostring(tonumber(table.remove(args, 1)) or 0)
        end
        return match
    end)
    print(result)
end

function splitString(input, sep)
    sep = sep or "%s"
    local t = {}
    for str in input:gmatch("([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

function stringSplit(input, sep)
    sep = sep or "%s"
    local t = {}
    for str in input:gmatch("([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

function tableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then return true end
    end
    return false
end

function getScreenSize()
    return gpu.getResolution()
end

function drawBox(x, y, width, height, color, borderColor)
    local oldBg = gpu.getBackground()
    gpu.setBackground(color)
    gpu.fill(x, y, width, height, " ")
    
    if borderColor then
        gpu.setBackground(borderColor)
        gpu.fill(x, y, width, 1, " ") -- Верхняя граница
        gpu.fill(x, y + height - 1, width, 1, " ") -- Нижняя граница
        gpu.fill(x, y, 1, height, " ") -- Левая граница
        gpu.fill(x + width - 1, y, 1, height, " ") -- Правая граница
    end
    
    gpu.setBackground(oldBg)
end

function drawText(x, y, text, fgColor, bgColor)
    local oldFg, oldBg = gpu.getForeground(), gpu.getBackground()
    if fgColor then gpu.setForeground(fgColor) end
    if bgColor then gpu.setBackground(bgColor) end
    gpu.set(x, y, text)
    if fgColor then gpu.setForeground(oldFg) end
    if bgColor then gpu.setBackground(oldBg) end
end

function centerText(text, y)
    local w, h = getScreenSize()
    local x = math.floor((w - unicode.len(text)) / 2)
    drawText(x, y, text)
    return x
end

function createButton(x, y, width, text, onClick)
    return {
        x = x, y = y, width = width, height = 1,
        text = text,
        onClick = onClick,
        draw = function(self)
            local isHover = mouseX >= self.x and mouseX <= self.x + self.width and 
                           mouseY >= self.y and mouseY <= self.y + self.height
            
            local bgColor = isHover and config.theme.button_hover or config.theme.button
            drawBox(self.x, self.y, self.width, self.height, bgColor, config.theme.border)
            local textX = math.floor(self.x + (self.width - unicode.len(self.text)) / 2)
            drawText(textX, self.y, self.text, config.theme.text, bgColor)
        end
    }
end

-- Графический интерфейс
function createWindow(title, x, y, width, height)
    local window = {
        id = #windows + 1,
        title = title,
        x = x, y = y, width = width, height = height,
        content = {},
        buttons = {},
        open = true,
        
        addButton = function(self, x, y, width, text, onClick)
            table.insert(self.buttons, createButton(self.x + x, self.y + y, width, text, onClick))
        end,
        
        draw = function(self)
            if not self.open then return end
            
            -- Окно
            drawBox(self.x, self.y, self.width, self.height, config.theme.window, config.theme.border)
            
            -- Заголовок
            drawBox(self.x, self.y, self.width, 1, config.theme.accent)
            drawText(self.x + 2, self.y, " " .. self.title, config.theme.text, config.theme.accent)
            
            -- Кнопка закрытия
            drawBox(self.x + self.width - 3, self.y, 3, 1, config.theme.error)
            drawText(self.x + self.width - 2, self.y, "X", config.theme.text, config.theme.error)
            
            -- Контент
            for _, item in ipairs(self.content) do
                if type(item) == "function" then
                    item()
                end
            end
            
            -- Кнопки
            for _, button in ipairs(self.buttons) do
                button:draw()
            end
        end,
        
        handleClick = function(self, x, y)
            if not self.open then return false end
            
            -- Проверяем, попадает ли клик в область окна
            if x < self.x or x > self.x + self.width or y < self.y or y > self.y + self.height then
                return false
            end
            
            -- Кнопка закрытия
            if x >= self.x + self.width - 3 and x <= self.x + self.width and y == self.y then
                self.open = false
                return true
            end
            
            -- Остальные кнопки
            for _, button in ipairs(self.buttons) do
                if x >= button.x and x <= button.x + button.width and 
                   y >= button.y and y <= button.y + button.height then
                    if button.onClick then 
                        button.onClick() 
                    end
                    return true
                end
            end
            
            return false
        end
    }
    
    table.insert(windows, window)
    activeWindow = window.id
    return window
end

function showMessageBox(title, message)
    local w, h = getScreenSize()
    local width, height = 40, 8
    local x, y = math.floor((w - width) / 2), math.floor((h - height) / 2)
    
    local window = createWindow(title, x, y, width, height)
    
    window.content = {
        function()
            -- Простой вывод сообщения
            local lines = {}
            local current = ""
            for word in message:gmatch("%S+") do
                if #current + #word + 1 > width - 4 then
                    table.insert(lines, current)
                    current = word
                else
                    current = current .. (current == "" and "" or " ") .. word
                end
            end
            if current ~= "" then
                table.insert(lines, current)
            end
            
            for i, line in ipairs(lines) do
                if i <= height - 4 then
                    drawText(window.x + 2, window.y + 2 + i, line)
                end
            end
        end
    }
    
    window:addButton(width - 12, height - 2, 10, "OK", function()
        window.open = false
    end)
    
    return window
end

-- Системные утилиты
function systemInfo()
    local w, h = getScreenSize()
    local window = createWindow("Системная информация", 10, 5, 60, 15)
    
    window.content = {
        function()
            local info = {
                "ОС: GraphOS v" .. config.system.version,
                "Пользователь: " .. config.user.name,
                "Хост: " .. config.system.hostname,
                "Разрешение: " .. w .. "x" .. h,
                "Память: " .. math.floor(computer.totalMemory()/1024) .. "K",
                "Время работы: " .. math.floor(computer.uptime()) .. " сек"
            }
            
            for i, line in ipairs(info) do
                if window.y + 2 + i <= window.y + window.height - 2 then
                    drawText(window.x + 2, window.y + 2 + i, "- " .. line)
                end
            end
        end
    }
    
    window:addButton(20, window.height - 2, 20, "Закрыть", function()
        window.open = false
    end)
end

function calculatorApp()
    local window = createWindow("Калькулятор", 20, 5, 40, 15)
    local display = "0"
    
    window.content = {
        function()
            drawBox(window.x + 2, window.y + 2, window.width - 4, 3, config.theme.panel)
            local displayText = display
            if unicode.len(displayText) > window.width - 6 then
                displayText = "..." .. unicode.sub(displayText, -window.width + 6)
            end
            drawText(window.x + window.width - unicode.len(displayText) - 3, window.y + 3, displayText)
        end
    }
    
    local buttons = {
        {"7", "8", "9", "/"},
        {"4", "5", "6", "*"},
        {"1", "2", "3", "-"},
        {"0", ".", "=", "+"},
        {"C", "(", ")", "<"}
    }
    
    for row, rowButtons in ipairs(buttons) do
        for col, btn in ipairs(rowButtons) do
            local btnX = 2 + (col-1) * 9
            local btnY = 6 + (row-1) * 2
            window:addButton(btnX, btnY, 8, btn, function()
                if btn == "C" then
                    display = "0"
                elseif btn == "<" then
                    display = display:sub(1, -2)
                    if display == "" then display = "0" end
                elseif btn == "=" then
                    -- Простые вычисления без load()
                    local result = simpleCalculate(display)
                    display = tostring(result)
                else
                    if display == "0" then
                        display = btn
                    else
                        display = display .. btn
                    end
                end
            end)
        end
    end
    
    window:addButton(2, window.height - 2, 10, "Закрыть", function()
        window.open = false
    end)
end

function simpleCalculate(expr)
    -- Простые вычисления без load()
    expr = expr:gsub("%s+", "")
    
    -- Сначала скобки
    while expr:find("%([^%(%)]*%)") do
        expr = expr:gsub("%(([^%(%)]*)%)", function(inner)
            return tostring(simpleCalculate(inner))
        end)
    end
    
    -- Умножение и деление
    while expr:find("[%d%.]+[%*/][%d%.]+") do
        expr = expr:gsub("([%d%.]+)([%*/])([%d%.]+)", function(a, op, b)
            a, b = tonumber(a), tonumber(b)
            if op == "*" then return a * b
            elseif op == "/" then return b ~= 0 and a / b or 0
            end
        end)
    end
    
    -- Сложение и вычитание
    while expr:find("[%d%.]+[%+%-][%d%.]+") do
        expr = expr:gsub("([%d%.]+)([%+%-])([%d%.]+)", function(a, op, b)
            a, b = tonumber(a), tonumber(b)
            if op == "+" then return a + b
            elseif op == "-" then return a - b
            end
        end)
    end
    
    return tonumber(expr) or 0
end

function textEditor()
    local window = createWindow("Текстовый редактор", 5, 3, 60, 20)
    local text = ""
    
    window.content = {
        function()
            drawBox(window.x + 2, window.y + 2, window.width - 4, window.height - 6, config.theme.panel)
            
            -- Простой вывод текста
            local lines = {}
            local current = ""
            for char in text:gmatch(".") do
                if #current >= window.width - 6 then
                    table.insert(lines, current)
                    current = char
                else
                    current = current .. char
                end
            end
            if current ~= "" then
                table.insert(lines, current)
            end
            
            for i, line in ipairs(lines) do
                if i <= window.height - 7 then
                    drawText(window.x + 3, window.y + 3 + i, line)
                end
            end
        end
    }
    
    window:addButton(2, window.height - 2, 12, "Сохранить", function()
        showMessageBox("Сохранение", "Текст сохранен в памяти")
    end)
    
    window:addButton(16, window.height - 2, 12, "Закрыть", function()
        window.open = false
    end)
end

function paintApp()
    local window = createWindow("Рисовалка", 10, 3, 50, 20)
    
    window.content = {
        function()
            drawBox(window.x + 2, window.y + 2, 46, 16, config.theme.panel)
            drawText(window.x + 15, window.y + 9, "Рисовалка", config.theme.accent)
            drawText(window.x + 12, window.y + 11, "В разработке", config.theme.warning)
        end
    }
    
    window:addButton(2, window.height - 2, 10, "Закрыть", function()
        window.open = false
    end)
end

-- Игры
function snakeGame()
    local window = createWindow("Змейка", 15, 5, 40, 20)
    
    window.content = {
        function()
            drawBox(window.x + 1, window.y + 1, 38, 18, config.theme.panel)
            drawText(window.x + 15, window.y + 9, "Змейка", config.theme.accent)
            drawText(window.x + 12, window.y + 11, "В разработке", config.theme.warning)
        end
    }
    
    window:addButton(15, window.height - 2, 10, "Закрыть", function()
        window.open = false
    end)
end

-- Рабочий стол
function setupDesktop()
    desktopIcons = {
        {
            x = 2, y = 2, 
            icon = "S", name = "Система",
            onClick = systemInfo
        },
        {
            x = 2, y = 4,
            icon = "F", name = "Файлы",
            onClick = function()
                showMessageBox("Файловый менеджер", "В разработке")
            end
        },
        {
            x = 2, y = 6,
            icon = "C", name = "Калькулятор",
            onClick = calculatorApp
        },
        {
            x = 2, y = 8,
            icon = "T", name = "Текст",
            onClick = textEditor
        },
        {
            x = 2, y = 10,
            icon = "P", name = "Рисование",
            onClick = paintApp
        },
        {
            x = 2, y = 12,
            icon = "G", name = "Игры",
            onClick = function()
                showMessageBox("Игры", "Выберите игру из меню")
            end
        }
    }
end

function drawDesktop()
    local w, h = getScreenSize()
    
    -- Фон
    drawBox(1, 1, w, h, config.theme.background)
    
    -- Простые обои
    for y = 1, h - taskbarHeight, 2 do
        for x = 1, w, 2 do
            if (x + y) % 4 == 0 then
                drawText(x, y, ".", config.theme.panel)
            end
        end
    end
    
    -- Значки рабочего стола
    for _, icon in ipairs(desktopIcons) do
        drawText(icon.x, icon.y, icon.icon, config.theme.accent)
        drawText(icon.x, icon.y + 1, icon.name)
    end
    
    -- Панель задач
    drawBox(1, h - taskbarHeight + 1, w, taskbarHeight, config.theme.panel)
    
    -- Кнопка Пуск
    drawBox(1, h - taskbarHeight + 1, 8, taskbarHeight, config.theme.accent)
    drawText(2, h - taskbarHeight + 2, "Start")
    
    -- Время
    local time = os.date("%H:%M:%S")
    drawText(w - #time - 1, h - taskbarHeight + 2, time)
end

function handleDesktopClick(x, y)
    local w, h = getScreenSize()
    
    -- Панель задач
    if y > h - taskbarHeight then
        -- Кнопка Пуск
        if x <= 8 then
            showMessageBox("Меню", "Главное меню системы")
            return true
        end
        return true
    end
    
    -- Значки рабочего стола
    for _, icon in ipairs(desktopIcons) do
        if x >= icon.x and x <= icon.x + 2 and 
           y >= icon.y and y <= icon.y + 2 then
            if icon.onClick then 
                icon.onClick() 
            end
            return true
        end
    end
    
    -- Окна
    for i = #windows, 1, -1 do
        local window = windows[i]
        if window.open and window.handleClick(x, y) then
            activeWindow = window.id
            return true
        end
    end
    
    return false
end

-- Основной цикл
function main()
    -- Инициализация
    local w, h = getScreenSize()
    if w < 80 or h < 25 then
        gpu.setResolution(80, 25)
        w, h = 80, 25
    end
    
    gpu.setBackground(config.theme.background)
    gpu.setForeground(config.theme.text)
    gpu.fill(1, 1, w, h, " ")
    
    -- Загрузочный экран
    drawBox(1, 1, w, h, config.theme.background)
    centerText("GraphOS v" .. config.system.version, math.floor(h/2) - 2)
    centerText("Загрузка...", math.floor(h/2))
    
    -- Простая анимация загрузки
    for i = 1, 3 do
        centerText(string.rep(".", i), math.floor(h/2) + 1)
        os.sleep(0.5)
    end
    
    setupDesktop()
    
    -- Главный цикл
    while true do
        drawDesktop()
        
        -- Отрисовка окон
        for _, window in ipairs(windows) do
            window:draw()
        end
        
        -- Обработка событий
        local e, _, x, y = event.pull(0.5, "touch")
        
        if e == "touch" then
            mouseX, mouseY = x, y
            handleDesktopClick(x, y)
        end
        
        -- Удаление закрытых окон
        for i = #windows, 1, -1 do
            if not windows[i].open then
                table.remove(windows, i)
            end
        end
    end
end

-- Запуск системы
local success, err = pcall(main)
if not success then
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
    gpu.fill(1, 1, 80, 25, " ")
    gpu.set(1, 1, "Ошибка системы:")
    gpu.set(1, 2, err)
    gpu.set(1, 4, "Перезагрузка...")
    os.sleep(3)
    computer.shutdown(true)
end
