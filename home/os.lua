-- ==============================================
-- GraphOS - Продвинутая ОС с GUI для OpenComputers
-- Версия 2.0 (Исправленная)
-- ==============================================

local component = require("component")
local computer = require("computer")
local event = require("event")
local filesystem = require("filesystem")
local serialization = require("serialization")
local shell = require("shell")
local term = require("term")
local unicode = require("unicode")

-- Проверка компонентов
if not component.isAvailable("gpu") then
    error("Требуется видеокарта!")
end
if not component.isAvailable("screen") then
    error("Требуется монитор!")
end

local gpu = component.gpu
local screen = component.screen

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
        version = "2.0",
        resolution = {80, 25}
    }
}

-- Глобальные переменные
local desktop = {}
local windows = {}
local activeWindow = nil
local mouseX, mouseY = 0, 0
local taskbarHeight = 3
local desktopIcons = {}
local runningProcesses = {}
local fileSystem = {
    ["/"] = {type = "dir", name = "root", content = {}},
    ["/bin"] = {type = "dir", name = "bin", content = {}},
    ["/home"] = {type = "dir", name = "home", content = {}},
    ["/home/user"] = {type = "dir", name = "user", content = {
        documents = {type = "dir", name = "Documents", content = {}},
        pictures = {type = "dir", name = "Pictures", content = {}},
        downloads = {type = "dir", name = "Downloads", content = {}}
    }},
    ["/etc"] = {type = "dir", name = "etc", content = {
        config = {type = "file", name = "config.cfg", content = "theme=dark\nresolution=80x25"}
    }}
}

-- Утилиты
function printf(format, ...)
    print(string.format(format, ...))
end

function splitString(input, sep)
    sep = sep or "%s"
    local t = {}
    for str in string.gmatch(input, "([^"..sep.."]+)") do
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

function drawBox(x, y, width, height, color, borderColor)
    gpu.setBackground(color)
    gpu.fill(x, y, width, height, " ")
    
    if borderColor then
        gpu.setBackground(borderColor)
        gpu.fill(x, y, width, 1, " ") -- Верхняя граница
        gpu.fill(x, y + height - 1, width, 1, " ") -- Нижняя граница
        gpu.fill(x, y, 1, height, " ") -- Левая граница
        gpu.fill(x + width - 1, y, 1, height, " ") -- Правая граница
    end
end

function drawText(x, y, text, fgColor, bgColor)
    if fgColor then gpu.setForeground(fgColor) end
    if bgColor then gpu.setBackground(bgColor) end
    gpu.set(x, y, text)
    if fgColor or bgColor then
        gpu.setForeground(config.theme.text)
        gpu.setBackground(config.theme.background)
    end
end

function centerText(text, y)
    local w, h = gpu.getResolution()
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

-- Файловая система
function fsList(path)
    path = path or "/"
    if fileSystem[path] and fileSystem[path].type == "dir" then
        local items = {}
        for name, item in pairs(fileSystem[path].content) do
            table.insert(items, {
                name = name,
                type = item.type,
                size = item.content and tostring(#item.content) or "0"
            })
        end
        return items
    end
    return {}
end

function fsCreateFile(path, content)
    local dir = string.match(path, "^(.*/)[^/]*$") or "/"
    local filename = string.match(path, "/([^/]*)$") or path
    
    if fileSystem[dir] and fileSystem[dir].type == "dir" then
        fileSystem[dir].content[filename] = {
            type = "file",
            name = filename,
            content = content or ""
        }
        return true
    end
    return false
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
            drawText(self.x + 2, self.y, "📁 " .. self.title, config.theme.text, config.theme.accent)
            
            -- Кнопка закрытия
            drawBox(self.x + self.width - 3, self.y, 3, 1, config.theme.error)
            drawText(self.x + self.width - 2, self.y, "✕", config.theme.text, config.theme.error)
            
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
    local w, h = gpu.getResolution()
    local width, height = 40, 8
    local x, y = math.floor((w - width) / 2), math.floor((h - height) / 2)
    
    local window = createWindow(title, x, y, width, height)
    
    -- Добавляем содержимое через content
    window.content = {
        function()
            -- Разбиваем сообщение на строки
            local lines = {}
            local currentLine = ""
            for word in message:gmatch("%S+") do
                if #currentLine + #word + 1 > width - 4 then
                    table.insert(lines, currentLine)
                    currentLine = word
                else
                    if currentLine ~= "" then
                        currentLine = currentLine .. " " .. word
                    else
                        currentLine = word
                    end
                end
            end
            if currentLine ~= "" then
                table.insert(lines, currentLine)
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
    local w, h = gpu.getResolution()
    local window = createWindow("Системная информация", 10, 5, 60, 15)
    
    window.content = {
        function()
            local info = {
                "ОС: GraphOS v" .. config.system.version,
                "Пользователь: " .. config.user.name,
                "Хост: " .. config.system.hostname,
                "Разрешение: " .. w .. "x" .. h,
                "Память: " .. math.floor(computer.totalMemory()/1024) .. "K/" .. 
                            math.floor(computer.freeMemory()/1024) .. "K свободно",
                "Время работы: " .. math.floor(computer.uptime()) .. " сек"
            }
            
            if component.isAvailable("eeprom") then
                table.insert(info, "Энергия: " .. string.format("%.1f", computer.energy()) .. "/" .. 
                                 string.format("%.1f", computer.maxEnergy()))
            end
            
            for i, line in ipairs(info) do
                if window.y + 2 + i <= window.y + window.height - 2 then
                    drawText(window.x + 2, window.y + 2 + i, "• " .. line)
                end
            end
        end
    }
    
    window:addButton(20, window.height - 2, 20, "Закрыть", function()
        window.open = false
    end)
end

function fileManager()
    local w, h = gpu.getResolution()
    local window = createWindow("Файловый менеджер", 5, 3, 70, 18)
    local currentPath = "/"
    local files = fsList(currentPath)
    
    window.content = {
        function()
            drawText(window.x + 2, window.y + 2, "Текущая папка: " .. currentPath)
            
            local maxLines = window.height - 6
            for i = 1, math.min(#files, maxLines) do
                local file = files[i]
                local icon = file.type == "dir" and "📁 " or "📄 "
                if window.y + 4 + i <= window.y + window.height - 2 then
                    drawText(window.x + 2, window.y + 4 + i, icon .. file.name)
                end
            end
            
            if #files > maxLines then
                drawText(window.x + 2, window.y + window.height - 2, "... и еще " .. (#files - maxLines) .. " файлов")
            end
        end
    }
    
    window:addButton(2, window.height - 2, 15, "Создать файл", function()
        showMessageBox("Создание файла", "Функция в разработке")
    end)
    
    window:addButton(20, window.height - 2, 15, "Новая папка", function()
        showMessageBox("Создание папка", "Функция в разработке")
    end)
    
    window:addButton(38, window.height - 2, 15, "Закрыть", function()
        window.open = false
    end)
end

function calculatorApp()
    local window = createWindow("Калькулятор", 20, 5, 40, 15)
    local display = "0"
    local memory = 0
    
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
        {"C", "M+", "M-", "MR"}
    }
    
    for row, rowButtons in ipairs(buttons) do
        for col, btn in ipairs(rowButtons) do
            local btnX = 2 + (col-1) * 9
            local btnY = 6 + (row-1) * 2
            window:addButton(btnX, btnY, 8, btn, function()
                if btn == "C" then
                    display = "0"
                elseif btn == "=" then
                    local success, result = pcall(function()
                        return load("return " .. display)()
                    end)
                    if success then
                        display = tostring(result)
                    else
                        display = "Error"
                    end
                elseif btn == "M+" then
                    memory = tonumber(display) or 0
                elseif btn == "M-" then
                    memory = 0
                elseif btn == "MR" then
                    display = tostring(memory)
                else
                    if display == "0" or display == "Error" then
                        display = btn
                    else
                        display = display .. btn
                    end
                end
            end)
        end
    end
end

function textEditor()
    local window = createWindow("Текстовый редактор", 5, 3, 60, 20)
    local text = ""
    local cursorPos = 0
    
    window.content = {
        function()
            drawBox(window.x + 2, window.y + 2, window.width - 4, window.height - 6, config.theme.panel)
            
            -- Отображаем текст построчно
            local lines = {}
            local currentLine = ""
            for char in text:gmatch(".") do
                if char == "\n" or unicode.len(currentLine) >= window.width - 6 then
                    table.insert(lines, currentLine)
                    currentLine = char == "\n" and "" or char
                else
                    currentLine = currentLine .. char
                end
            end
            if currentLine ~= "" then
                table.insert(lines, currentLine)
            end
            
            for i, line in ipairs(lines) do
                if i <= window.height - 7 then
                    drawText(window.x + 3, window.y + 2 + i, line)
                end
            end
        end
    }
    
    window:addButton(2, window.height - 2, 12, "Сохранить", function()
        showMessageBox("Сохранение", "Файл сохранен!")
    end)
    
    window:addButton(16, window.height - 2, 12, "Открыть", function()
        showMessageBox("Открытие", "Выберите файл...")
    end)
    
    window:addButton(30, window.height - 2, 12, "Закрыть", function()
        window.open = false
    end)
end

function paintApp()
    local window = createWindow("Рисовалка", 10, 3, 50, 20)
    local canvas = {}
    local brushColor = config.theme.accent
    
    -- Инициализация холста
    for y = 1, 16 do
        canvas[y] = {}
        for x = 1, 46 do
            canvas[y][x] = {char = " ", color = config.theme.panel}
        end
    end
    
    window.content = {
        function()
            drawBox(window.x + 2, window.y + 2, 46, 16, config.theme.panel)
            
            for y = 1, 16 do
                for x = 1, 46 do
                    local pixel = canvas[y][x]
                    gpu.setForeground(pixel.color)
                    gpu.set(window.x + 2 + x, window.y + 2 + y, pixel.char)
                end
            end
            gpu.setForeground(config.theme.text)
        end
    }
    
    window:addButton(2, window.height - 2, 10, "Очистить", function()
        for y = 1, 16 do
            for x = 1, 46 do
                canvas[y][x] = {char = " ", color = config.theme.panel}
            end
        end
    end)
    
    window:addButton(15, window.height - 2, 10, "Закрыть", function()
        window.open = false
    end)
end

-- Игры
function snakeGame()
    local window = createWindow("Змейка", 15, 5, 40, 20)
    
    window.content = {
        function()
            drawBox(window.x + 1, window.y + 1, 38, 18, config.theme.panel)
            drawText(window.x + 15, window.y + 9, "🎮 Змейка", config.theme.accent)
            drawText(window.x + 12, window.y + 11, "В разработке...", config.theme.warning)
        end
    }
    
    window:addButton(15, window.height - 2, 10, "Закрыть", function()
        window.open = false
    end)
end

function minesweeperGame()
    local window = createWindow("Сапер", 10, 3, 40, 20)
    
    window.content = {
        function()
            drawText(window.x + 15, window.y + 9, "🎮 Сапер", config.theme.accent)
            drawText(window.x + 10, window.y + 11, "В разработке...", config.theme.warning)
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
            icon = "💻", name = "Система",
            onClick = systemInfo
        },
        {
            x = 2, y = 4,
            icon = "📁", name = "Файлы",
            onClick = fileManager
        },
        {
            x = 2, y = 6,
            icon = "🧮", name = "Калькулятор",
            onClick = calculatorApp
        },
        {
            x = 2, y = 8,
            icon = "📝", name = "Текстовый редактор",
            onClick = textEditor
        },
        {
            x = 2, y = 10,
            icon = "🎨", name = "Рисовалка",
            onClick = paintApp
        },
        {
            x = 2, y = 12,
            icon = "🎮", name = "Игры",
            onClick = function()
                local w, h = gpu.getResolution()
                local menu = createWindow("Игры", w-20, 2, 18, 8)
                menu:addButton(1, 2, 16, "Змейка", snakeGame)
                menu:addButton(1, 4, 16, "Сапер", minesweeperGame)
                menu:addButton(1, 6, 16, "Закрыть", function() menu.open = false end)
            end
        }
    }
end

function drawDesktop()
    local w, h = gpu.getResolution()
    
    -- Фон
    drawBox(1, 1, w, h, config.theme.background)
    
    -- Обои (упрощенные)
    for y = 1, h - taskbarHeight, 2 do
        for x = 1, w, 2 do
            if (x + y) % 4 == 0 then
                drawText(x, y, "░", config.theme.panel)
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
    drawBox(1, h - taskbarHeight + 1, 10, taskbarHeight, config.theme.accent)
    drawText(3, h - taskbarHeight + 2, "🚀")
    
    -- Время
    local timeText = os.date("%H:%M:%S")
    drawText(w - unicode.len(timeText) - 1, h - taskbarHeight + 2, timeText)
    
    -- Открытые окна на панели задач
    local taskX = 11
    for i, window in ipairs(windows) do
        if window.open and taskX < w - 20 then
            local title = window.title
            if unicode.len(title) > 10 then
                title = unicode.sub(title, 1, 10) .. ".."
            end
            
            drawBox(taskX, h - taskbarHeight + 1, 14, taskbarHeight, 
                   activeWindow == window.id and config.theme.button_hover or config.theme.button)
            drawText(taskX + 2, h - taskbarHeight + 2, title)
            taskX = taskX + 15
        end
    end
end

function showStartMenu()
    local w, h = gpu.getResolution()
    local menu = createWindow("", 1, h - taskbarHeight - 15, 25, 16)
    
    menu.content = {
        function()
            local items = {
                "🚀 GraphOS v" .. config.system.version,
                "💻 Система",
                "📁 Файловый менеджер",
                "🧮 Калькулятор",
                "📝 Текстовый редактор",
                "🎨 Рисовалка",
                "🎮 Игры",
                "⚙️ Настройки",
                "❓ Справка",
                "⏻ Выключение"
            }
            
            for i, item in ipairs(items) do
                if menu.y + 1 + i <= menu.y + menu.height - 1 then
                    drawText(menu.x + 2, menu.y + 1 + i, item)
                end
            end
        end
    }
    
    -- Добавляем обработчики для пунктов меню
    menu:addButton(1, 3, 23, "", function() systemInfo() end)
    menu:addButton(1, 4, 23, "", function() fileManager() end)
    menu:addButton(1, 5, 23, "", function() calculatorApp() end)
    menu:addButton(1, 6, 23, "", function() textEditor() end)
    menu:addButton(1, 7, 23, "", function() paintApp() end)
    menu:addButton(1, 8, 23, "", function() 
        local gameMenu = createWindow("Игры", w-20, 2, 18, 8)
        gameMenu:addButton(1, 2, 16, "Змейка", snakeGame)
        gameMenu:addButton(1, 4, 16, "Сапер", minesweeperGame)
    end)
end

function handleDesktopClick(x, y)
    local w, h = gpu.getResolution()
    
    -- Панель задач
    if y > h - taskbarHeight then
        -- Кнопка Пуск
        if x <= 10 then
            showStartMenu()
            return true
        end
        
        -- Окна на панели задач
        local taskX = 11
        for i, window in ipairs(windows) do
            if window.open and x >= taskX and x <= taskX + 14 then
                activeWindow = window.id
                return true
            end
            taskX = taskX + 15
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
    
    -- Окна (обрабатываем с конца для верхних окон)
    for i = #windows, 1, -1 do
        local window = windows[i]
        if window.open and window.handleClick(x, y) then
            activeWindow = window.id
            return true
        end
    end
    
    -- Клик по пустому месту на рабочем столе
    return false
end

-- Основной цикл
function main()
    -- Инициализация
    local w, h = gpu.getResolution()
    if w < 80 or h < 25 then
        gpu.setResolution(80, 25)
        w, h = 80, 25
    end
    
    gpu.setBackground(config.theme.background)
    gpu.setForeground(config.theme.text)
    term.clear()
    
    -- Загрузочный экран
    drawBox(1, 1, w, h, config.theme.background)
    centerText("🚀 GraphOS v" .. config.system.version, math.floor(h/2) - 2)
    centerText("Загрузка системы...", math.floor(h/2))
    
    -- Простая анимация загрузки
    for i = 1, 20 do
        local progress = string.rep("█", i) .. string.rep("░", 20 - i)
        centerText(progress, math.floor(h/2) + 1)
        os.sleep(0.1)
    end
    
    os.sleep(1)
    
    setupDesktop()
    
    -- Главный цикл
    while true do
        drawDesktop()
        
        -- Отрисовка окон
        for _, window in ipairs(windows) do
            window:draw()
        end
        
        -- Обработка событий
        local e, _, x, y, button = event.pull(0.1, "touch", "key_down")
        
        if e == "touch" then
            mouseX, mouseY = x, y
            handleDesktopClick(x, y)
        elseif e == "key_down" then
            if button == 88 then -- F12
                systemInfo()
            elseif button == 14 then -- Backspace
                -- Ничего не делаем, чтобы не падать
            end
        end
        
        -- Удаление закрытых окон
        for i = #windows, 1, -1 do
            if not windows[i].open then
                table.remove(windows, i)
            end
        end
        
        -- Ограничение количества окон
        if #windows > 5 then
            table.remove(windows, 1)
        end
        
        -- Обновляем активное окно
        if activeWindow and activeWindow > #windows then
            activeWindow = #windows > 0 and #windows or nil
        end
    end
end

-- Запуск системы
local success, err = pcall(main)
if not success then
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFF0000)
    term.clear()
    print("💥 Критическая ошибка системы:")
    print(err)
    print("")
    print("Нажмите R для перезагрузки...")
    
    while true do
        local e, _, code = event.pull("key_down")
        if code == 19 then -- R key
            computer.shutdown(true)
        end
    end
end
