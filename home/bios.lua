local unicode = unicode or utf8
local component = component
local computer = computer
local event = require("event")
local invoke = component.invoke
local cp = component.proxy
local cl = component.list

-- Инициализация компонентов
local component_screen = cl("screen")()
local component_gpu = cl("gpu")()

-- Проверка наличия обязательных компонентов
if not component_screen then
    error("Не найден монитор")
elseif not component_gpu then
    error("Не найдена видеокарта")
end

-- Настройка GPU
local gpu = cp(component_gpu)
gpu.bind(component_screen)
local screen_width, screen_height = gpu.maxResolution()

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
    
    -- Кнопка установки
    local buttonWidth = 20
    local buttonX = math.floor((screen_width - buttonWidth) / 2)
    local buttonY = diskListY + 2 + #disks * 3 + 2
    
    drawButton(buttonX, buttonY, buttonWidth, 3, "УСТАНОВИТЬ", false)
    
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
local function connect(url)
    local internet = cl("internet")()
    if not internet then
        error("Не найдена сетевая карта")
    end
    
    local internet_proxy = cp(internet)
    local request, err = internet_proxy.request(url)
    
    if not request then
        error("Ошибка запроса: " .. tostring(err))
    end
    
    local response = ""
    while true do
        local chunk, err = request.read()
        if not chunk then
            if err then
                error("Ошибка чтения: " .. tostring(err))
            else
                break
            end
        end
        response = response .. chunk
    end
    
    return response
end

-- Основная функция запуска
local function start()
    local filesystems = cl("filesystem")
    local disks = {}
    
    -- Поиск доступных дисков
    for address in filesystems do
        local fs_proxy = cp(address)
        if fs_proxy.getLabel() ~= "tmpfs" then
            local file_handle = fs_proxy.open("init.lua", "r")
            local has_init = file_handle ~= nil
            if file_handle then fs_proxy.close(file_handle) end
            
            table.insert(disks, {
                address = address,
                label = fs_proxy.getLabel() or "Без названия",
                has_init = has_init,
                proxy = fs_proxy
            })
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
            local disk_proxy = cp(disk.address)
            local file_handle = disk_proxy.open("init.lua", "r")
            local content = ""
            
            while true do
                local chunk = disk_proxy.read(file_handle, math.huge)
                if not chunk then break end
                content = content .. chunk
            end
            disk_proxy.close(file_handle)
            
            local code, err = load(content, "=init.lua", "t", _G)
            if not code then
                error("Ошибка загрузки кода: " .. tostring(err))
            end
            
            local success, result = pcall(code)
            if not success then
                error("Ошибка выполнения: " .. tostring(result))
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
    local content = connect("https://raw.githubusercontent.com/CubeAITech/TemOS/refs/heads/main/home/init.lua")
    
    showProgress("Запись на диск...", 50)
    
    local disk_proxy = selectedDisk.proxy
    local file_handle, err = disk_proxy.open("init.lua", "w")
    
    if not file_handle then
        error("Ошибка создания файла: " .. tostring(err))
    end
    
    local success, err = disk_proxy.write(file_handle, content)
    if not success then
        error("Ошибка записи: " .. tostring(err))
    end
    
    disk_proxy.close(file_handle)
    disk_proxy.setLabel("delay")
    
    showProgress("Установка завершена!", 100)
    os.sleep(2)
    
    computer.shutdown(true)
end

-- Обработка ошибок
local status, err = pcall(start)
if not status then
    clearScreen()
    drawBox(1, 1, screen_width, 3, 0xFF0000, "Ошибка BIOS", 0xFFFFFF)
    gpu.setForeground(0xFFFFFF)
    gpu.set(math.floor((screen_width - unicode.len(tostring(err))) / 2), math.floor(screen_height/2), tostring(err))
    os.sleep(5)
    computer.shutdown()
end
