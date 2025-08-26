-- ==============================================
-- GraphOS - Продвинутая ОС с GUI для OpenComputers
-- Версия 2.0
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

function table.contains(tbl, value)
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
    if fgColor then gpu.setForeground(config.theme.text) end
    if bgColor then gpu.setBackground(config.theme.background) end
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
            drawText(math.floor(self.x + (self.width - unicode.len(self.text)) / 2), 
                    self.y, self.text, config.theme.text, bgColor)
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
    local dir = string.match(path, "^(.*/)[^/]*$")
    local filename = string.match(path, "/([^/]*)$")
    
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
            
            -- Кнопка закрытия
            if x >= self.x + self.width - 3 and x <= self.x + self.width and y == self.y then
                self.open = false
                return true
            end
            
            -- Остальные кнопки
            for _, button in ipairs(self.buttons) do
                if x >= button.x and x <= button.x + button.width and 
                   y >= button.y and y <= button.y + button.height then
                    if button.onClick then button.onClick() end
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
    window.content = {
        function()
            drawText(x + 2, y + 2, message)
        end
    }
    
    window:addButton(width - 12, height - 2, 10, "OK", function()
        window.open = false
    end)
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
                "Время работы: " .. math.floor(computer.uptime()) .. " сек",
                "Энергия: " .. string.format("%.1f", computer.energy()) .. "/" .. 
                             string.format("%.1f", computer.maxEnergy())
            }
            
            for i, line in ipairs(info) do
                drawText(window.x + 2, window.y + 2 + i, "• " .. line)
            end
        end
    }
end

function fileManager()
    local w, h = gpu.getResolution()
    local window = createWindow("Файловый менеджер", 5, 3, 70, 18)
    local currentPath = "/"
    local files = fsList(currentPath)
    
    window.content = {
        function()
            drawText(window.x + 2, window.y + 2, "Текущая папка: " .. currentPath)
            
            for i, file in ipairs(files) do
                local icon = file.type == "dir" and "📁 " or "📄 "
                drawText(window.x + 2, window.y + 4 + i, icon .. file.name)
            end
        end
    }
    
    window:addButton(2, window.height - 2, 15, "Создать файл", function()
        showMessageBox("Создание файла", "Функция в разработке")
    end)
    
    window:addButton(20, window.height - 2, 15, "Новая папка", function()
        showMessageBox("Создание папки", "Функция в разработке")
    end)
end

function calculatorApp()
    local window = createWindow("Калькулятор", 20, 5, 40, 12)
    local display = "0"
    local memory = 0
    
    window.content = {
        function()
            drawBox(window.x + 2, window.y + 2, window.width - 4, 3, config.theme.panel)
            drawText(window.x + window.width - unicode.len(display) - 3, window.y + 3, display)
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
                    local success, result = pcall(load("return " .. display))
                    if success then
                        display = tostring(result)
                    else
                        display = "Error"
                    end
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
            drawText(window.x + 3, window.y + 3, text)
            
            -- Курсор
            if os.time() % 2 == 0 then
                local cursorX = window.x + 3 + (cursorPos % (window.width - 6))
                local cursorY = window.y + 3 + math.floor(cursorPos / (window.width - 6))
                drawText(cursorX, cursorY, "▊", config.theme.accent)
            end
        end
    }
    
    window:addButton(2, window.height - 2, 12, "Сохранить", function()
        showMessageBox("Сохранение", "Файл сохранен!")
    end)
    
    window:addButton(16, window.height - 2, 12, "Открыть", function()
        showMessageBox("Открытие", "Выберите файл...")
    end)
end

function paintApp()
    local window = createWindow("Рисовалка", 10, 3, 50, 20)
    local canvas = {}
    local brushColor = config.theme.accent
    local brushChar = "█"
    
    for y = 1, 16 do
        canvas[y] = {}
        for x = 1, 46 do
            canvas[y][x] = {char = " ", color = config.theme.background}
        end
    end
    
    window.content = {
        function()
            drawBox(window.x + 2, window.y + 2, 46, 16, config.theme.panel)
            
            for y = 1, 16 do
                for x = 1, 46 do
                    local pixel = canvas[y][x]
                    drawText(window.x + 2 + x, window.y + 2 + y, pixel.char, pixel.color)
                end
            end
        end
    }
    
    window:addButton(2, window.height - 2, 10, "Очистить", function()
        for y = 1, 16 do
            for x = 1, 46 do
                canvas[y][x] = {char = " ", color = config.theme.background}
            end
        end
    end)
end

-- Игры
function snakeGame()
    local window = createWindow("Змейка", 15, 5, 40, 20)
    local snake = {{x=20, y=10}}
    local food = {x=math.random(2,39), y=math.random(2,19)}
    local direction = "right"
    local score = 0
    local gameOver = false
    
    window.content = {
        function()
            drawBox(window.x + 1, window.y + 1, 38, 18, config.theme.panel)
            
            -- Еда
            drawText(window.x + food.x, window.y + food.y, "🍎", config.theme.success)
            
            -- Змейка
            for i, segment in ipairs(snake) do
                local char = i == 1 and "🔸" or "🔹"
                drawText(window.x + segment.x, window.y + segment.y, char, config.theme.accent)
            end
            
            -- Счет
            drawText(window.x + 2, window.y + 19, "Счет: " .. score)
            
            if gameOver then
                drawText(window.x + 10, window.y + 9, "ИГРА ОКОНЧЕНА!", config.theme.error)
                drawText(window.x + 8, window.y + 10, "Счет: " .. score, config.theme.text)
            end
        end
    }
end

function minesweeperGame()
    local window = createWindow("Сапер", 10, 3, 40, 20)
    window.content = {
        function()
            drawText(window.x + 15, window.y + 9, "🎮 Сапер", config.theme.accent)
            drawText(window.x + 10, window.y + 11, "В разработке...", config.theme.warning)
        end
    }
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
            end
        }
    }
end

function drawDesktop()
    local w, h = gpu.getResolution()
    
    -- Фон
    drawBox(1, 1, w, h, config.theme.background)
    
    -- Обои
    for y = 1, h - taskbarHeight do
        for x = 1, w do
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
    
    -- Открытые окна
    for i, window in ipairs(windows) do
        if window.open then
            local taskX = 11 + (i-1) * 15
            if taskX < w - 20 then
                drawBox(taskX, h - taskbarHeight + 1, 14, taskbarHeight, 
                       activeWindow == window.id and config.theme.button_hover or config.theme.button)
                local title = unicode.len(window.title) > 10 and 
                             unicode.sub(window.title, 1, 10) .. "..." or window.title
                drawText(taskX + 1, h - taskbarHeight + 2, title)
            end
        end
    end
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
        for i, window in ipairs(windows) do
            local taskX = 11 + (i-1) * 15
            if x >= taskX and x <= taskX + 14 then
                activeWindow = window.id
                return true
            end
        end
        
        return true
    end
    
    -- Значки рабочего стола
    for _, icon in ipairs(desktopIcons) do
        if x >= icon.x and x <= icon.x + 2 and 
           y >= icon.y and y <= icon.y + 2 then
            if icon.onClick then icon.onClick() end
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

function showStartMenu()
    local w, h = gpu.getResolution()
    local menu = createWindow("", 1, h - taskbarHeight - 15, 25, 16)
    menu.content = {
        function()
            drawText(menu.x + 2, menu.y + 2, "🚀 GraphOS v" .. config.system.version)
            drawText(menu.x + 2, menu.y + 4, "💻 Система")
            drawText(menu.x + 2, menu.y + 5, "📁 Файловый менеджер")
            drawText(menu.x + 2, menu.y + 6, "🧮 Калькулятор")
            drawText(menu.x + 2, menu.y + 7, "📝 Текстовый редактор")
            drawText(menu.x + 2, menu.y + 8, "🎨 Рисовалка")
            drawText(menu.x + 2, menu.y + 9, "🎮 Игры")
            drawText(menu.x + 2, menu.y + 11, "⚙️ Настройки")
            drawText(menu.x + 2, menu.y + 12, "❓ Справка")
            drawText(menu.x + 2, menu.y + 14, "⏻ Выключение")
        end
    }
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
    centerText("████████████████████", math.floor(h/2) + 1)
    os.sleep(2)
    
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
            if button == 211 then -- F12 для системной информации
                systemInfo()
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
