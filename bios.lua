local cursorX = 1
local cursorY = 1
local screenWidth = 80
local screenHeight = 25
local sys = {}
local settings = {
    textColor = 0xFFFFFF,      
    bgColor = 0x000000,        
    fontSize = 1,              
    beepEnabled = true,        
    autoBoot = false           
}

function initialize()
    for address, type in component.list() do
        if type == "gpu" then
            sys.gpu = component.proxy(address)
            break
        end
    end
    
    if sys.gpu then
        for address, type in component.list() do
            if type == "screen" then
                if pcall(function() sys.gpu.bind(address) end) then
                    sys.screen = address
                    screenWidth, screenHeight = sys.gpu.maxResolution()
                    sys.gpu.setResolution(screenWidth, screenHeight)
                    sys.gpu.setBackground(settings.bgColor)
                    sys.gpu.setForeground(settings.textColor)
                    sys.gpu.fill(1, 1, screenWidth, screenHeight, " ")
                    break
                end
            end
        end
    end
    
    for address, type in component.list() do
        if type == "beep" then
            sys.beep = component.proxy(address)
            break
        end
    end
    
    for address, type in component.list() do
        if type == "keyboard" then
            sys.keyboard = address
            break
        end
    end
    
    loadSettings()
    
    return true
end

function string.trim(s)
    return s:match("^%s*(.-)%s*$")
end

function loadSettings()
    if fileExists("/bios/settings.cfg") then
        local content = loadFile("/bios/settings.cfg")
        for line in content:gmatch("[^\r\n]+") do
            local key, value = line:match("^([^=]+)=(.+)$")
            if key and value then
                key = key:trim()
                value = value:trim()
                
                if key == "textColor" or key == "bgColor" then
                    settings[key] = tonumber(value) or settings[key]
                elseif key == "fontSize" then
                    settings[key] = math.max(1, math.min(6, tonumber(value) or settings[key]))
                elseif key == "beepEnabled" or key == "autoBoot" then
                    settings[key] = (value:lower() == "true")
                end
            end
        end
        applySettings()
    end
end

function saveSettings()
    local content = ""
    for key, value in pairs(settings) do
        if type(value) == "boolean" then
            content = content .. key .. "=" .. tostring(value) .. "\n"
        else
            content = content .. key .. "=" .. tostring(value) .. "\n"
        end
    end
    
    for address, type in component.list() do
        if type == "filesystem" then
            local fs = component.proxy(address)
            if fs.makeDirectory and not (fs.exists("/bios") and not fs.isDirectory("/bios")) then
                if not fs.exists("/bios") then
                    fs.makeDirectory("/bios")
                end
            end
        end
    end
    
    for address, type in component.list() do
        if type == "filesystem" then
            local fs = component.proxy(address)
            if fs.open and fs.write then
                local handle, reason = fs.open("/bios/settings.cfg", "w")
                if handle then
                    fs.write(handle, content)
                    fs.close(handle)
                    return true
                end
            end
        end
    end
    return false
end

function applySettings()
    if sys.gpu then
        sys.gpu.setBackground(settings.bgColor)
        sys.gpu.setForeground(settings.textColor)
        if sys.gpu.setFont then
            pcall(function() 
                local maxFont = 1
                for i = 1, 6 do
                    if pcall(function() return sys.gpu.setFont(i) end) then
                        maxFont = i
                    else
                        break
                    end
                end
                settings.fontSize = math.min(settings.fontSize, maxFont)
                sys.gpu.setFont(settings.fontSize) 
            end)
        end
    end
end

function print(text)
    if not sys.gpu then
        return false
    end
    
    local textStr = tostring(text)
    
    if cursorX + #textStr > screenWidth then
        newline()
    end
    
    sys.gpu.set(cursorX, cursorY, textStr)
    cursorX = cursorX + #textStr
    
    return true
end

function newline()
    cursorX = 1
    cursorY = cursorY + 1
    
    if cursorY > screenHeight then
        cursorY = screenHeight
        if sys.gpu then
            sys.gpu.copy(1, 2, screenWidth, screenHeight - 1, 0, -1)
            sys.gpu.fill(1, screenHeight, screenWidth, 1, " ")
        end
    end
end

function clear()
    if sys.gpu then
        sys.gpu.fill(1, 1, screenWidth, screenHeight, " ")
        cursorX = 1
        cursorY = 1
    end
end

function fileExists(path)
    for address, type in component.list() do
        if type == "filesystem" then
            local fs = component.proxy(address)
            if fs.exists and fs.isDirectory then
                if pcall(function() return fs.exists(path) end) then
                    return fs.exists(path) and not fs.isDirectory(path)
                end
            end
        end
    end
    return false
end

function dirExists(path)
    for address, type in component.list() do
        if type == "filesystem" then
            local fs = component.proxy(address)
            if fs.exists and fs.isDirectory then
                if pcall(function() return fs.exists(path) and fs.isDirectory(path) end) then
                    return true
                end
            end
        end
    end
    return false
end

function loadFile(path)
    for address, type in component.list() do
        if type == "filesystem" then
            local fs = component.proxy(address)
            if fs.open and fs.read then
                local handle, reason = fs.open(path, "r")
                if handle then
                    local content = ""
                    while true do
                        local chunk = fs.read(handle, math.huge)
                        if not chunk then break end
                        content = content .. chunk
                    end
                    fs.close(handle)
                    return content
                end
            end
        end
    end
    error("Невозможно прочитать файл: " .. path)
end

function writeFile(path, content)
    for address, type in component.list() do
        if type == "filesystem" then
            local fs = component.proxy(address)
            if fs.open and fs.write then
                local handle, reason = fs.open(path, "w")
                if handle then
                    fs.write(handle, content)
                    fs.close(handle)
                    return true
                end
            end
        end
    end
    return false
end

function listFiles(path)
    local files = {}
    for address, type in component.list() do
        if type == "filesystem" then
            local fs = component.proxy(address)
            if fs.list and fs.isDirectory then
                if pcall(function() return fs.isDirectory(path) end) then
                    local list = fs.list(path)
                    for _, file in ipairs(list) do
                        table.insert(files, file)
                    end
                    return files
                end
            end
        end
    end
    return files
end

function dofile(path)
    local content = loadFile(path)
    local func, reason = load(content, "=" .. path)
    if not func then
        error("Ошибка загрузки или выполнения файла: " .. tostring(reason))
    end
    return func()
end

function getDiskInfo()
    local disks = {}
    
    for address, type in component.list() do
        if type == "filesystem" then
            local fs = component.proxy(address)
            if fs.spaceTotal and fs.spaceUsed then
                local total = fs.spaceTotal()
                local used = fs.spaceUsed()
                local free = total - used
                local label = fs.getLabel() or "Диск " .. address:sub(1, 6)
                
                table.insert(disks, {
                    address = address,
                    label = label,
                    total = total,
                    used = used,
                    free = free,
                    percent = total > 0 and math.floor((used / total) * 100) or 0
                })
            end
        end
    end
    
    return disks
end

function showDiskInfo()
    local disks = getDiskInfo()
    
    if #disks == 0 then
        print("Диски не найдены")
        newline()
        return
    end
    
    print("Дисковые пространства:")
    newline()
    
    for i, disk in ipairs(disks) do
        print("  " .. disk.label .. ":")
        print(string.format("    Использовано: %d/%d байт (%d%%)", 
            disk.used, disk.total, disk.percent))
        print(string.format("    Доступно: %d байт", disk.free))
        newline()
    end
end

function showInfo()
    clear()
    print("BIOS")
    newline()
    print("Память: " .. computer.totalMemory() .. "K")
    print("Заряд: " .. math.floor(computer.energy()))
    newline()
    
    if sys.gpu then
        print("Размер экрана: " .. screenWidth .. "x" .. screenHeight)
        newline()
    end
    
    print("Установленные компоненты:")
    newline()
    for address, type in component.list() do
        print("  " .. type)
        newline()
    end
    
    newline()
    showDiskInfo()
end

-- Функция для отображения меню настроек
function showSettingsMenu()
    local currentOption = 1
    local options = {
        "Цвет текста: " .. string.format("#%06X", settings.textColor),
        "Цвет фона: " .. string.format("#%06X", settings.bgColor),
        "Размер шрифта: " .. settings.fontSize,
        "Звуковые эффекты: " .. (settings.beepEnabled and "Вкл" or "Выкл"),
        "Автозагрузка ОС: " .. (settings.autoBoot and "Вкл" or "Выкл"),
        "Сохранить и выйти",
        "Выход без сохранения"
    }
    
    while true do
        clear()
        print("=== Настройки BIOS ===")
        newline()
        
        for i, option in ipairs(options) do
            if i == currentOption then
                print("> " .. option)
            else
                print("  " .. option)
            end
            newline()
        end
        
        newline()
        print("Стрелки - навигация, Пробел - изменить, Enter - выбрать")
        print("Esc - выход")
        
        local event = {computer.pullSignal()}
        if event[1] == "key_down" then
            local key = event[4]
            
            -- Правильные коды стрелок для OpenComputers
            if key == 208 then -- Стрелка вверх
                currentOption = currentOption > 1 and currentOption - 1 or #options
                if settings.beepEnabled and sys.beep then
                    sys.beep.beep(800, 0.05)
                end
                
            elseif key == 200 then -- Стрелка вниз
                currentOption = currentOption < #options and currentOption + 1 or 1
                if settings.beepEnabled and sys.beep then
                    sys.beep.beep(800, 0.05)
                end
                
            elseif key == 57 then -- Пробел (изменить настройку)
                if currentOption == 1 then
                    changeColorSetting("textColor")
                elseif currentOption == 2 then
                    changeColorSetting("bgColor")
                elseif currentOption == 3 then
                    changeFontSize()
                elseif currentOption == 4 then
                    settings.beepEnabled = not settings.beepEnabled
                    if settings.beepEnabled and sys.beep then
                        sys.beep.beep(1000, 0.1)
                    end
                elseif currentOption == 5 then
                    settings.autoBoot = not settings.autoBoot
                    if settings.beepEnabled and sys.beep then
                        sys.beep.beep(1000, 0.1)
                    end
                end
                
            elseif key == 28 then -- Enter (выбрать пункт)
                if currentOption == 6 then
                    if saveSettings() then
                        applySettings()
                        if settings.beepEnabled and sys.beep then
                            sys.beep.beep(1200, 0.1)
                        end
                        return true
                    else
                        print("Ошибка сохранения настроек!")
                        newline()
                        print("Нажмите любую клавишу...")
                        computer.pullSignal()
                    end
                elseif currentOption == 7 then
                    applySettings() -- Восстанавливаем старые настройки
                    return false
                end
                
            elseif key == 1 then -- Esc
                applySettings()
                return false
            end
        end
    end
end

-- Функция для изменения цвета
function changeColorSetting(settingType)
    local colors = {
        {name = "Белый", value = 0xFFFFFF},
        {name = "Черный", value = 0x000000},
        {name = "Красный", value = 0xFF0000},
        {name = "Зеленый", value = 0x00FF00},
        {name = "Синий", value = 0x0000FF},
        {name = "Желтый", value = 0xFFFF00},
        {name = "Голубой", value = 0x00FFFF},
        {name = "Пурпурный", value = 0xFF00FF}
    }
    
    local currentIndex = 1
    for i, color in ipairs(colors) do
        if color.value == settings[settingType] then
            currentIndex = i
            break
        end
    end
    
    while true do
        clear()
        print("Выберите цвет для " .. (settingType == "textColor" and "текста" or "фона"))
        newline()
        
        for i, color in ipairs(colors) do
            if i == currentIndex then
                print("> " .. color.name)
            else
                print("  " .. color.name)
            end
            newline()
        end
        
        newline()
        print("Стрелки - выбор, Enter - подтвердить, Esc - отмена")
        
        -- Временно применяем выбранный цвет для предпросмотра
        local tempValue = colors[currentIndex].value
        if settingType == "textColor" then
            sys.gpu.setForeground(tempValue)
        else
            sys.gpu.setBackground(tempValue)
        end
        
        local event = {computer.pullSignal()}
        if event[1] == "key_down" then
            local key = event[4]
            
            if key == 208 then -- Стрелка вверх
                currentIndex = currentIndex > 1 and currentIndex - 1 or #colors
                if settings.beepEnabled and sys.beep then
                    sys.beep.beep(800, 0.05)
                end
                
            elseif key == 200 then -- Стрелка вниз
                currentIndex = currentIndex < #colors and currentIndex + 1 or 1
                if settings.beepEnabled and sys.beep then
                    sys.beep.beep(800, 0.05)
                end
                
            elseif key == 28 then -- Enter
                settings[settingType] = colors[currentIndex].value
                applySettings()
                if settings.beepEnabled and sys.beep then
                    sys.beep.beep(1200, 0.1)
                end
                return
                
            elseif key == 1 then -- Esc
                applySettings()
                return
            end
        end
    end
end

-- Функция для изменения размера шрифта
function changeFontSize()
    while true do
        clear()
        print("Выберите размер шрифта (1-6)")
        newline()
        print("Текущий размер: " .. settings.fontSize)
        newline()
        print("Стрелки влево/вправо - изменить")
        newline()
        print("Enter - подтвердить, Esc - отмена")
        
        -- Проверяем поддержку шрифтов
        local maxSupported = 1
        if sys.gpu and sys.gpu.setFont then
            for i = 1, 6 do
                if pcall(function() return sys.gpu.setFont(i) end) then
                    maxSupported = i
                else
                    break
                end
            end
        end
        
        if maxSupported == 1 then
            newline()
            print("Смена шрифтов не поддерживается!")
            newline()
        end
        
        local event = {computer.pullSignal()}
        if event[1] == "key_down" then
            local key = event[4]
            
            if key == 203 then -- Стрелка влево
                settings.fontSize = math.max(1, settings.fontSize - 1)
                applySettings()
                if settings.beepEnabled and sys.beep then
                    sys.beep.beep(700, 0.05)
                end
                
            elseif key == 205 then -- Стрелка вправо
                settings.fontSize = math.min(6, math.min(maxSupported, settings.fontSize + 1))
                applySettings()
                if settings.beepEnabled and sys.beep then
                    sys.beep.beep(700, 0.05)
                end
                
            elseif key == 28 then -- Enter
                if settings.beepEnabled and sys.beep then
                    sys.beep.beep(1200, 0.1)
                end
                return
                
            elseif key == 1 then -- Esc
                return
            end
        end
    end
end

-- Упрощенная командная строка
function simpleCommandLine()
    clear()
    print("=== ROOT Управление ===")
    newline()
    print("Введите команду ниже (или юзайте exit для выхода):")
    newline()
    
    while true do
        print("ROOT> ")
        local currentCommand = ""
        local inputX = cursorX  -- Запоминаем позицию X после "BIOS> "
        local inputY = cursorY  -- Запоминаем позицию Y
        
        while true do
            local event = {computer.pullSignal()}
            if event[1] == "key_down" then
                local key = event[4]
                local char = event[3] -- Символ в OpenComputers находится в event[3]
                
                if key == 28 then -- Enter
                    if currentCommand:lower() == "exit" then
                        return
                    end
                    newline()  -- Переходим на новую строку перед выводом результата
                    executeCommand(currentCommand)
                    newline()
                    break  -- Выходим из внутреннего цикла для нового ввода
                    
                elseif key == 14 then -- Backspace
                    if #currentCommand > 0 then
                        currentCommand = currentCommand:sub(1, -2)
                        -- Очищаем только область ввода и перерисовываем
                        sys.gpu.fill(inputX, inputY, screenWidth - inputX + 1, 1, " ")
                        sys.gpu.set(inputX, inputY, currentCommand)
                        cursorX = inputX + #currentCommand
                        cursorY = inputY
                    end
                    
                elseif char and char >= 32 and char <= 126 then
                    currentCommand = currentCommand .. string.char(char)
                    sys.gpu.set(inputX + #currentCommand - 1, inputY, string.char(char))
                    cursorX = inputX + #currentCommand
                    cursorY = inputY
                end
            end
        end
    end
end

-- Выполнение команды
function executeCommand(cmd)
    local args = {}
    for arg in cmd:gmatch("%S+") do
        table.insert(args, arg)
    end
    
    if #args == 0 then
        return
    end
    
    local command = args[1]:lower()
    
    if command == "help" then
        print("Справка по командам:")
        newline()
        newline()
        newline()
        print("help    - показать эти кмд")
        newline()
        print("cls     - очистить экран фулл")
        newline()
        print("dir     - список файлов в этой папке")
        newline()
        print("dir <path> - список файлов в указанной папке")
        newline()
        print("type <file> - чекнуть содержимое файла")
        newline()
        print("info    - инфа о системе")
        newline()
        print("disks   - инфа о дисках")
        newline()
        print("beep    - тест звук сигнала (не доработнано)")
        newline()
        print("reboot  - релог пк")
        newline()
        print("shutdown - вырубить пк")
        newline()
        print("exit    - лив из рут")
        
    elseif command == "cls" then
        clear()
        return
        
    elseif command == "dir" then
        local path = args[2] or "/"
        print("содержимое " .. path .. ":")
        newline()
        
        if dirExists(path) then
            local files = listFiles(path)
            for _, file in ipairs(files) do
                local fullPath = path .. (path:sub(-1) == "/" and "" or "/") .. file
                if dirExists(fullPath) then
                    print("[DIR]  " .. file)
                else
                    print("       " .. file)
                end
            end
        else
            print("указанное тобой не существует: " .. path)
        end
        
    elseif command == "type" then
        if #args < 2 then
            print("Ошибка: укажите имя файла")
            return
        end
        
        local filename = args[2]
        
        if fileExists(filename) then
            local content = loadFile(filename)
            print("содержимое файла " .. filename .. ":")
            newline()
            print(content)
        else
            print("файла  не существует: " .. filename)
        end
        
    elseif command == "info" then
        showInfo()
        
    elseif command == "disks" then
        showDiskInfo()
        
    elseif command == "beep" then
        if sys.beep then
            sys.beep.beep(1000, 0.3)
            print("звук. сигнал воспроизведен")
        else
            print("звук. устройства нет")
        end
        
    elseif command == "reboot" then
        computer.shutdown(true)
        
    elseif command == "shutdown" then
        computer.shutdown()
        
    elseif command == "exit" then
        return true
        
    else
        print("твоя команда не найдена: " .. command)
        print("введи help для списка команд")
    end
    
    newline()
    print("Нажмите любую клавишу для продолжения...")
    computer.pullSignal()
    return false
end

---- ВАЖНО ----
---
---
---
--- САМА СТРОКА
function chatCommandLine()
    clear()
    print("=== Чат ===")
    newline()
    print("Введите команду ниже (или юзайте exit для выхода):")
    newline()
    
    while true do
        print("YOU: ")
        local command = russianInput()
        
        if command:lower() == "exit" then
            return
        end
        
        newline()
        chatCommand(command)
        newline()
    end
end

-- Альтернативная функция для ввода с поддержкой русских символов
function russianInput(prompt)
    if prompt then
        print(prompt)
    end
    
    local input = ""
    local inputX = cursorX
    local inputY = cursorY
    
    -- Таблица преобразования кодов клавиш в русские символы (раскладка ЙЦУКЕН)
    local russianLayout = {
        [16] = "й", [17] = "ц", [18] = "у", [19] = "к", [20] = "е", [21] = "н",
        [22] = "г", [23] = "ш", [24] = "щ", [25] = "з", [26] = "х", [27] = "ъ",
        [30] = "ф", [31] = "ы", [32] = "в", [33] = "а", [34] = "п", [35] = "р",
        [36] = "о", [37] = "л", [38] = "д", [39] = "ж", [40] = "э",
        [44] = "я", [45] = "ч", [46] = "с", [47] = "м", [48] = "и", [49] = "т",
        [50] = "ь", [51] = "б", [52] = "ю",
        
        -- Заглавные буквы с Shift
        [112] = "Й", [113] = "Ц", [114] = "У", [115] = "К", [116] = "Е", [117] = "Н",
        [118] = "Г", [119] = "Ш", [120] = "Щ", [121] = "З", [122] = "Х", [123] = "Ъ",
        [126] = "Ф", [127] = "Ы", [128] = "В", [129] = "А", [130] = "П", [131] = "Р",
        [132] = "О", [133] = "Л", [134] = "Д", [135] = "Ж", [136] = "Э",
        [140] = "Я", [141] = "Ч", [142] = "С", [143] = "М", [144] = "И", [145] = "Т",
        [146] = "Ь", [147] = "Б", [148] = "Ю"
    }
    
    while true do
        local event = {computer.pullSignal()}
        
        if event[1] == "key_down" then
            local key = event[4]
            local char = event[3]
            local shift = event[2] == 42 or event[2] == 54
            
            if key == 28 then -- Enter
                return input
                
            elseif key == 14 then -- Backspace
                if #input > 0 then
                    input = input:sub(1, -2)
                    sys.gpu.fill(inputX, inputY, screenWidth - inputX + 1, 1, " ")
                    sys.gpu.set(inputX, inputY, input)
                    cursorX = inputX + #input
                    cursorY = inputY
                end
                
            elseif russianLayout[key] then
                -- Русские символы
                input = input .. russianLayout[key]
                sys.gpu.set(inputX + #input - 1, inputY, russianLayout[key])
                cursorX = inputX + #input
                cursorY = inputY
                
            elseif char and (char >= 32 and char <= 126) then
                -- Английские символы
                input = input .. string.char(char)
                sys.gpu.set(inputX + #input - 1, inputY, string.char(char))
                cursorX = inputX + #input
                cursorY = inputY
            end
            
        elseif event[1] == "clipboard" or event[1] == "paste" then
            -- Вставка текста из буфера обмена
            local text = event[3]
            if text then
                input = input .. text
                sys.gpu.set(inputX, inputY, input)
                cursorX = inputX + #input
                cursorY = inputY
            end
        end
    end
end

---
---
---
-- Выполнение команды
function chatCommand(cmd)
    local args = {}
    for arg in cmd:gmatch("%S+") do
        table.insert(args, arg)
    end
    
    if #args == 0 then
        return
    end
    
    local command = cmd:lower()
    local firstWord = args[1]:lower() 
    
    if firstWord == "привет" then
        print("BOT: Привет!")
    elseif firstWord == "хай" then
        print("BOT: Хай!")

    elseif command == "как дела" or command == "как дела?" then
        print("BOT: Идеально.")

    elseif command == "русский алфавит" then
        print("BOT: Я что тебе блять!? Сказочник петушарочник?!")
        newline()
        print("BOT: Какого хера я тебе должен это говорить! Петушара ебаная!")
    
    elseif firstWord == "питон" then
        print("BOT: Python - язык программирования.")

    elseif firstWord == "python" then
        print("BOT: Python - язык программирования.")

    elseif command == "ты говно" then
        print("BOT: иди нахуй бро...")
        newline()
        print("BOT: а хотя...")
        newline()
        print("BOT: 3")
        newline()
        print("BOT: 2...")
        newline()
        print("BOT: 1...")
        newline()
        print("BOT: пизда твоему компу.")
        crashSystem()
    
    elseif firstWord == "очистка" then
        clear()
        return
    
    else
        print("BOT: Я еще не знаю как на это ответить!")
    end    
end
---- ВАЖНО ----

-- Функция для создания системной ошибки
function crashSystem()
    -- Сохраняем текущие настройки экрана
    local oldBackground = sys.gpu.getBackground()
    local oldForeground = sys.gpu.getBackground()
    
    -- Устанавливаем красный фон и белый текст для ошибки
    sys.gpu.setBackground(0xFF0000)
    sys.gpu.setForeground(0xFFFFFF)
    clear()
    
    -- Выводим сообщение об ошибке
    print("Поздравляю! Ты за свой базар словил слет твоего компьютера.")
    newline()
    computer.pullSignal(1)
    print("Чисто по приколу, мы тебе крашнули память с ядром")
    newline()
    print("Адрес памяти: 0x" .. string.format("%08X", math.random(0, 0xFFFFFFFF)))
    newline()
    print("Код ошибки: 0x" .. string.format("%04X", math.random(0, 0xFFFF)))
    computer.pullSignal(1)
    newline()
    computer.pullSignal(1)
    print("Так же пару ошибок: Stack overflow в модуле kernel32.ocm")
    print("Невозможно продолжить выполнение системы")
    computer.pullSignal(1)
    newline()
    print("AS: Дамп памяти.")
    
    for i = 1, 10 do
        local line = ""
        for j = 1, 8 do
            line = line .. string.format("%04X ", math.random(0, 0xFFFF))
        end
        print("0x" .. string.format("%04X", i * 0x100) .. ": " .. line)
    end

    computer.pullSignal(1)
    newline()
    print("--- Работа завершена. За ваш базар, ваш ПК выебан.")
    
    while true do
        sys.gpu.set(1, cursorY, "_")
        sys.gpu.set(1, cursorY, " ")
    end
    
    sys.gpu.setBackground(oldBackground)
    sys.gpu.setForeground(oldForeground)
end

function showMenu()
    clear()
    print("BIOS")
    newline()
    newline()
    newline()
    newline()
    print("1. Запуск OS из диска (/boot/init.lua)")
    newline()
    print("2. Показать системную информацию")
    newline()
    print("3. Показать дисковую информацию")
    newline()
    print("4. Настройки BIOS")
    newline()
    print("5. ROOT-управление (не доработано)")
    newline()
    print("6. Чат")
    newline()
    print("7. Перезапуск")
    newline()
    print("8. Выход из системы")
    newline()
    newline()
    newline()
    newline()
    print("Выберите опцию (1-8): ")
    
    local selected = nil
    while not selected do
        local event = {computer.pullSignal()}
        if event[1] == "key_down" then
            local key = event[4]
            if key >= 2 and key <= 9 then -- 1-7 keys
                selected = key - 1
                if settings.beepEnabled and sys.beep then
                    sys.beep.beep(1000, 0.1)
                end
            end
        end
    end
    
    return selected
end

-- Загрузка ОС (опциональная)
function bootOS()
    if not fileExists("/init.lua") then
        clear()
        print("OS не найдена: /init.lua")
        newline()
        print("Нажмите на любую кнопку для того что бы вернуться в меню...")
        
        -- Ожидание клавиши
        while true do
            local event = {computer.pullSignal()}
            if event[1] == "key_down" then
                break
            end
        end
        return false
    end
    
    -- Загрузка ОС
    local ok, err = pcall(dofile, "/init.lua")
    if not ok then
        clear()
        print("Ошибка OS:")
        print(err)
        newline()
        print("Нажмите на любую кнопку для того что бы вернуться в меню...")
        while true do
            local event = {computer.pullSignal()}
            if event[1] == "key_down" then
                break
            end
        end
        return false
    end
    
    return true
end

-- Главная функция
function main()
    -- Инициализация системы
    if not initialize() then
        return
    end
    
    -- Автозагрузка ОС если включена
    if settings.autoBoot then
        if bootOS() then
            return
        end
    end
    
    -- Короткий звук при запуске
    if settings.beepEnabled and sys.beep then
        sys.beep.beep(1500, 0.1)
    end
    
    -- Главный цикл меню
    while true do
        local choice = showMenu()
        
        if choice == 1 then
            -- Попытка загрузки ОС
            if bootOS() then
                break -- Выход из цикла если ОС загрузилась успешно
            end
            
        elseif choice == 2 then
            showInfo()
            newline()
            print("Нажмите на любую кнопку для того что бы вернуться в меню...")
            while true do
                local event = {computer.pullSignal()}
                if event[1] == "key_down" then
                    break
                end
            end
            
        elseif choice == 3 then
            clear()
            showDiskInfo()
            newline()
            print("Нажмите на любую кнопку для того что бы вернуться в меню...")
            while true do
                local event = {computer.pullSignal()}
                if event[1] == "key_down" then
                    break
                end
            end
            
        elseif choice == 4 then
            showSettingsMenu()
            
        elseif choice == 5 then
            simpleCommandLine()
        
        elseif choice == 6 then
            chatCommandLine()
        
        elseif choice == 7 then
            computer.shutdown(true)
            
        elseif choice == 8 then
            computer.shutdown()
        end
    end
end

-- Обработчик ошибок
function handleError(err)
    if sys.beep then
        sys.beep.beep(300, 0.5)
    end
    if sys.gpu then
        clear()
        print("Ошибка BIOS:")
        print(err)
        newline()
        print("Система остановлена.")
    end
    while true do
        computer.pullSignal()
    end
end

-- Запуск
local ok, err = pcall(main)
if not ok then
    handleError(err)
end
