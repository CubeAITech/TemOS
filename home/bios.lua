local unicode = unicode or require("unicode") or utf8
local component = component
local computer = computer
local event = require("event")
local filesystem = require("filesystem")
local shell = require("shell")

-- Инициализация компонентов
local component_screen
local component_gpu

-- Поиск основных компонентов
for address, type in component.list("screen") do
    component_screen = address
    break
end

for address, type in component.list("gpu") do
    component_gpu = address
    break
end

-- Проверка наличия обязательных компонентов
if not component_screen then
    error("Не найден монитор")
elseif not component_gpu then
    error("Не найдена видеокарта")
end

-- Настройка GPU
local gpu = component.proxy(component_gpu)
local screen_connected, reason = gpu.bind(component_screen)
if not screen_connected then
    error("Не удалось подключить GPU к экрану: " .. tostring(reason))
end

gpu.setResolution(gpu.maxResolution())
local screen_width, screen_height = gpu.getResolution()

-- Цветовая схема
local colors = {
    background = 0x1E1E1E,
    header_bg = 0x2D2D2D,
    text = 0xFFFFFF,
    accent = 0x0078D7,
    button = 0x0078D7,
    button_hover = 0x106EBE,
    button_text = 0xFFFFFF,
    disk_normal = 0x3C3C3C,
    disk_selected = 0x0078D7,
    disk_text = 0xFFFFFF
}

-- Очистка экрана
local function clearScreen()
    gpu.setBackground(colors.background)
    gpu.setForeground(colors.text)
    gpu.fill(1, 1, screen_width, screen_height, " ")
end

-- Рисование прямоугольника с текстом
local function drawBox(x, y, width, height, bgColor, text, textColor)
    gpu.setBackground(bgColor)
    gpu.fill(x, y, width, height, " ")
    if text then
        gpu.setForeground(textColor or colors.text)
        local textX = math.floor(x + (width - unicode.len(text)) / 2)
        local textY = math.floor(y + height / 2)
        gpu.set(textX, textY, text)
    end
end

-- Рисование кнопки
local function drawButton(x, y, width, height, text, isHovered)
    local bgColor = isHovered and colors.button_hover or colors.button
    drawBox(x, y, width, height, bgColor, text, colors.button_text)
end

-- Рисование элемента диска
local function drawDiskItem(x, y, width, disk, isSelected, index)
    local bgColor = isSelected and colors.disk_selected or colors.disk_normal
    local text = disk.label .. " (" .. disk.address:sub(1, 8) .. ")"
    if disk.has_init then
        text = text .. " [Установлено]"
    end
    drawBox(x, y, width, 3, bgColor, text, colors.disk_text)
end

-- Основной интерфейс установки
local function showInstallationScreen(disks)
    clearScreen()
    
    -- Заголовок
    drawBox(1, 1, screen_width, 3, colors.header_bg, "TemOS - Установка операционной системы", colors.text)
    
    -- Информация о системе
    local infoText = "Добро пожаловать в установку TemOS v1.0"
    gpu.setForeground(colors.text)
    gpu.set(math.floor((screen_width - unicode.len(infoText)) / 2), 5, infoText)
    
    -- Список дисков
    local diskListWidth = math.min(40, screen_width - 10)
    local diskListX = math.floor((screen_width - diskListWidth) / 2)
    local diskListY = 7
    
    gpu.setForeground(colors.text)
    gpu.set(diskListX, diskListY, "Выберите диск для установки:")
    
    -- Автоматический выбор если только один диск
    local selectedDisk = #disks == 1 and 1 or nil
    
    -- Отрисовка списка дисков
    for i, disk in ipairs(disks) do
        drawDiskItem(diskListX, diskListY + 2 + (i-1)*3, diskListWidth, disk, selectedDisk == i, i)
    end
    
    -- Кнопка установки (только если выбран диск)
    local buttonWidth = 20
    local buttonX = math.floor((screen_width - buttonWidth) / 2)
    local buttonY = diskListY + 2 + #disks * 3 + 2
    
    if selectedDisk then
        drawButton(buttonX, buttonY, buttonWidth, 3, "УСТАНОВИТЬ", false)
    end
    
    -- Обработка событий
    if #disks == 1 then
        -- Автоматическая установка при одном диске
        os.sleep(2)
        return disks[1]
    else
        -- Ручной выбор при нескольких дисках
        while true do
            local e, _, x, y = event.pull("touch")
            if e == "touch" then
                -- Проверка клика по диску
                for i = 1, #disks do
                    local diskY = diskListY + 2 + (i-1)*3
                    if y >= diskY and y < diskY + 3 and x >= diskListX and x < diskListX + diskListWidth then
                        selectedDisk = i
                        -- Перерисовка с новым выбором
                        for j = 1, #disks do
                            drawDiskItem(diskListX, diskListY + 2 + (j-1)*3, diskListWidth, disks[j], selectedDisk == j, j)
                        end
                        -- Перерисовка кнопки
                        if selectedDisk then
                            drawButton(buttonX, buttonY, buttonWidth, 3, "УСТАНОВИТЬ", false)
                        end
                        break
                    end
                end
                
                -- Проверка клика по кнопке
                if selectedDisk and y >= buttonY and y < buttonY + 3 and x >= buttonX and x < buttonX + buttonWidth then
                    return disks[selectedDisk]
                end
            end
        end
    end
end

-- Функция отображения прогресса
local function showProgress(message, progress)
    clearScreen()
    drawBox(1, 1, screen_width, 3, colors.header_bg, "TemOS - Установка", colors.text)
    
    gpu.setForeground(colors.text)
    gpu.set(math.floor((screen_width - unicode.len(message)) / 2), math.floor(screen_height/2) - 1, message)
    
    if progress then
        local barWidth = math.min(40, screen_width - 10)
        local barX = math.floor((screen_width - barWidth) / 2)
        local barY = math.floor(screen_height/2) + 1
        
        -- Фон прогрессбара
        drawBox(barX, barY, barWidth, 3, colors.disk_normal, nil, nil)
        
        -- Заполненная часть
        local fillWidth = math.floor(barWidth * progress / 100)
        if fillWidth > 0 then
            drawBox(barX, barY, fillWidth, 3, colors.accent, math.floor(progress) .. "%", colors.button_text)
        end
    end
end

-- Функция HTTP запроса
local function httpRequest(url)
    local internetComponent = component.list("internet")()
    if not internetComponent then
        error("Не найдена сетевая карта")
    end
    
    local internet = component.proxy(internetComponent)
    local success, handle = pcall(internet.request, url)
    if not success or not handle then
        error("Ошибка HTTP запроса: " .. tostring(handle))
    end
    
    local response = ""
    while true do
        local chunk, err = handle.read()
        if chunk then
            response = response .. chunk
        elseif err then
            handle.close()
            error("Ошибка чтения: " .. tostring(err))
        else
            handle.close()
            break
        end
    end
    
    return response
end

-- Основная функция запуска
local function start()
    local disks = {}
    
    -- Поиск доступных дисков
    for address, type in component.list("filesystem") do
        if type == "filesystem" then
            local fs_proxy = component.proxy(address)
            local label = fs_proxy.getLabel() or "Без названия"
            
            -- Пропускаем tmpfs и read-only файловые системы
            if label ~= "tmpfs" and not fs_proxy.isReadOnly() then
                local has_init = fs_proxy.exists("init.lua")
                
                table.insert(disks, {
                    address = address,
                    label = label,
                    has_init = has_init,
                    proxy = fs_proxy
                })
            end
        end
    end
    
    if #disks == 0 then
        showProgress("Ошибка: Для установки системы требуется диск", 0)
        os.sleep(3)
        computer.shutdown()
        return
    end
    
    -- Проверка существующей системы
    for _, disk in ipairs(disks) do
        if disk.label == "delay" and disk.has_init then
            -- Загрузка существующей системы
            showProgress("Загрузка существующей системы...", 0)
            os.sleep(1)
            
            -- Монтируем диск как основную файловую систему
            filesystem.mount(disk.proxy, "/")
            
            -- Запускаем init.lua
            local success, result = pcall(function()
                os.execute("/init.lua")
            end)
            
            if not success then
                error("Ошибка загрузки системы: " .. tostring(result))
            end
            return
        end
    end
    
    -- Показать интерфейс установки
    local selectedDisk = showInstallationScreen(disks)
    
    if not selectedDisk then
        computer.shutdown()
        return
    end
    
    -- Процесс установки
    showProgress("Загрузка системы...", 25)
    
    -- Загрузка с URL
    local content = httpRequest("https://raw.githubusercontent.com/CubeAITech/TemOS/main/home/init.lua")
    
    showProgress("Запись на диск...", 50)
    
    local disk_proxy = selectedDisk.proxy
    
    -- Создаем файл init.lua
    local file_handle, err = disk_proxy.open("init.lua", "w")
    if not file_handle then
        error("Ошибка создания файла: " .. tostring(err))
    end
    
    local success, err = disk_proxy.write(file_handle, content)
    if not success then
        disk_proxy.close(file_handle)
        error("Ошибка записи: " .. tostring(err))
    end
    
    disk_proxy.close(file_handle)
    
    -- Устанавливаем метку диска
    local success, err = pcall(disk_proxy.setLabel, "delay")
    if not success then
        showProgress("Предупреждение: Не удалось установить метку диска", 75)
        os.sleep(2)
    end
    
    showProgress("Установка завершена!", 100)
    os.sleep(2)
    
    computer.shutdown(true)
end

-- Обработка ошибок
local status, err = pcall(start)
if not status then
    pcall(clearScreen)
    pcall(function()
        gpu.setBackground(0xFF0000)
        gpu.fill(1, 1, screen_width, 3, " ")
        gpu.setForeground(0xFFFFFF)
        gpu.set(math.floor((screen_width - 10) / 2), 2, "Ошибка BIOS")
        
        gpu.setForeground(0xFFFFFF)
        gpu.setBackground(colors.background)
        
        -- Вывод ошибки с переносами
        local errorMsg = tostring(err)
        local y = math.floor(screen_height/2) - 2
        for line in errorMsg:gmatch("[^\n]+") do
            if unicode.len(line) > screen_width then
                -- Разбиваем длинные строки
                for i = 1, math.ceil(unicode.len(line) / screen_width) do
                    local startPos = (i-1) * screen_width + 1
                    local endPos = math.min(i * screen_width, unicode.len(line))
                    local subLine = unicode.sub(line, startPos, endPos)
                    gpu.set(1, y, subLine)
                    y = y + 1
                end
            else
                gpu.set(math.floor((screen_width - unicode.len(line)) / 2), y, line)
                y = y + 1
            end
        end
    end)
    os.sleep(5)
    computer.shutdown()
end
