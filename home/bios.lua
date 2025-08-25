local unicode = unicode or utf8
local component = component
local computer = computer
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
local gpuX, gpuY = gpu.maxResolution()

-- Функция отображения страницы ошибки
local function error_page(title, text, color)
    gpu.setBackground(color)
    gpu.fill(1, 1, gpuX, gpuY, " ")
    gpu.set(math.floor((gpuX - unicode.len(title)) / 2), math.floor(gpuY / 2), title)
    gpu.set(math.floor((gpuX - unicode.len(text)) / 2), math.floor((gpuY + 2) / 2), text)
end

-- Функция запроса подтверждения
local function prompt(text, address)
    gpu.setBackground(0x000000)
    gpu.fill(1, 1, gpuX, gpuY, " ")
    gpu.set(1, 1, text .. " [Y/n]: ")
    gpu.set(1, 2, "Адрес диска: " .. address)
    
    while true do
        local _, _, _, key = computer.pullSignal("key_down")
        if key == 21 then -- Y
            return true
        elseif key == 49 then -- N
            return false
        else
            gpu.set(1, 3, "Нажмите Y для подтверждения или N для отмены")
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
                label = fs_proxy.getLabel(),
                has_init = has_init
            })
        end
    end
    
    if #disks == 0 then
        error_page("WARN BIOS", "Для установки системы требуется диск", 0xC8C800)
        return
    end
    
    -- Проверка существующей системы
    for _, disk in ipairs(disks) do
        if disk.label == "delay" and disk.has_init then
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
    
    -- Установка новой системы
    for _, disk in ipairs(disks) do
        if not disk.has_init then
            local confirmed = prompt("Использовать этот диск для установки системы?", disk.address)
            if not confirmed then
                computer.shutdown()
                return
            end
            
            local content = connect("http://kotik.ddns.net:7000/delay/init.lua")
            local disk_proxy = cp(disk.address)
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
            computer.shutdown(true)
            break
        end
    end
    
    error_page("INFO", "Все диски уже содержат систему", 0x00FF00)
end

-- Обработка ошибок
local status, err = pcall(start)
if not status then
    error_page("ERROR BIOS", tostring(err), 0xFF0000)
end

-- Основной цикл
while true do
    computer.pullSignal()
end
