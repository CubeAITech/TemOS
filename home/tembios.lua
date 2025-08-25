local unicode = unicode or utf8;
local invoke = component.invoke;
local cp = component.proxy;
local cl = component.list;
local component_screen = cl("screen")();
local component_gpu = cl("gpu")();

if not component_screen then
    error("Not found monitor");
elseif not component_gpu then
    error("Not found gpu");
end

local gpu = cp(component_gpu);
gpu.bind(component_screen);
local gpuX, gpuY = gpu.maxResolution();

-- GPU max resolution:
error("Ti loh")
-- .. tostring(gpuX) .. "x" .. tostring(gpuY)

--[[
local internet = component.list("internet")();
local screen = component.list("screen")();
local gpuC = component.list("gpu")();
local event = component.list("event");
local ignore = true;

-- Поиск основных компонентов
if not screen then
    error("Подключите монитор");
elseif not gpuC then
    error("Подключите видеокарту");
elseif not internet then
    error("Подключите сетевую карту");
end

-- Инициализация
local gpu = component.proxy(gpuC);
local gpuX, gpuY = gpu.maxResolution();
gpu.bind(screen);

-- Запуск
local function error_page(title, text, color)
    gpu.setBackground(color);
    gpu.fill(1, 1, gpuX, gpuY, " ");
    gpu.set(math.floor((gpuX - unicode.len(title)) / 2), math.floor(gpuY / 2), title);
    gpu.set(math.floor((gpuX - unicode.len(text)) / 2), math.floor((gpuY + 2) / 2), text);
end

local function prompt(text, gpu, address)
    gpu.setBackground(0x000000);
    gpu.fill(1, 1, gpuX, gpuY, " ");
    gpu.set(1, 1, text .. " [Y/n]: ");
    gpu.set(1, 2, "Адрес диска: " .. address);
    while true do
        local _, _, _, key = computer.pullSignal("key_down");
        if key == 21 then
            return true;
        elseif key == 49 then
            return false;
        else
            gpu.set(1, 3, "Необходимо ввести Y или n");
        end
    end
end

local function connect(url)
    local request, err = component.proxy(internet).request(url);
    local response = "";
    if not request then
        error("Ошибка запроса: " .. tostring(err), 0);
    end
    while true do
        local chunk, err = request.read();
        if not chunk then
            if err then
                error("Ошибка чтения: " .. tostring(err), 0);
            else
                break;
            end
        end
        response = response .. chunk;
    end
    return response;
end

local function start()
    local filesystems = component.list("filesystem");
    local disks = {};
    for address in filesystems do
        local fs_proxy = component.proxy(address);
        if fs_proxy.getLabel() == "tmpfs" then
            goto continue;
        end
        local file_handle = fs_proxy.open("init.lua", "r");
        local type = false;
        if file_handle then
            type = true;
        end
        table.insert(disks, { address = address, label = fs_proxy.getLabel(), type = type });
        ::continue::
    end

    if #disks == 0 then
        error_page("WARN BIOS", "Чтобы установить boot файл, требуется диск", 0xC8C800);
    else
        for _, disk in ipairs(disks) do
            if disk.label == "delay" then
                local disk = component.proxy(disk.address);
                local file_handle, err = disk.open("init.lua", "r");
                local content = "";
                if not file_handle then
                    error("Не удалось прочитать boot файл: " .. tostring(err));
                end
                while true do
                    local chunk = disk.read(file_handle, math.huge);
                    if not chunk then break; end
                    content = content .. chunk;
                end
                disk.close(file_handle);
                local code, err = load(content, "=init.lua", "t", _G);
                if not code then
                    error("Не удалось загрузить код: " .. tostring(err));
                end
                local success, result = pcall(code);
                if not success then
                    error("Ошибка при запуске: " .. tostring(result));
                end
                return;
            end
        end
        if ignore then
            local total = 0;
            for _, disk in ipairs(disks) do
                if disk.type then
                    total = total + 1;
                end
                if total == #disks then
                    gpu.set(1, 1, "Не найдено свободного диска!");
                    gpu.set(1, 2, "Чтобы игнорировать существование init.lua");
                    gpu.set(1, 3, "Перепрошить биос с параметром local ignore=true");
                    return;
                end
            end
        end
        for _, disk in ipairs(disks) do
            local output = prompt("Вы хотите использовать этот диск для установки системы?", gpu, disk.address);
            if not output then computer.shutdown(); end
            local content = connect("http://kotik.ddns.net:7000/delay/init.lua");
            local file_handle, err = component.proxy(disk.address).open("init.lua", "w");
            if not file_handle then
                error("Не удалось создать файл для записи" .. tostring(err));
            end
            local success, err = component.proxy(disk.address).write(file_handle, content);
            if not success then
                error("Не удалось записать boot файл: " .. tostring(err));
            end
            component.proxy(disk.address).close(file_handle);
            component.proxy(disk.address).setLabel("delay");
            computer.shutdown(true);
            break;
        end
    end
end

-- Обработка ошибки
local status, err = pcall(start)
if not status then
    error_page("ERROR BIOS", tostring(err), 0x0000FF);
end

while true do
    computer.pullSignal();
end
]]--
