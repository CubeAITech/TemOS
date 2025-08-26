-- Получаем адрес GPU и создаем proxy
local bootAddress = computer.getBootAddress()
local gpu = component.proxy(component.list("gpu")())

local commands = {
    help = {
        description = "команды",
        execute = function()
            write("сегодня вам доступно\n")
            for cmd, info in pairs(commands) do
                write(string.format("  %-10s - %s\n", cmd, info.description))
            end
        end
    },
    time = {
        description = "время",
        execute = function()
            write("время: " .. os.date("%H:%M:%S") .. "\n")
        end
    },
    date = {
        description = "число седня",
        execute = function()
            write("сегодня: " .. os.date("%d.%m.%Y") .. "\n")
        end
    },
    clear = {
        description = "удалить все науй",
        execute = function()
            gpu.fill(1, 1, 80, 25, " ")
            gpu.setCursor(1, 1)
        end
    },
    echo = {
        description = "отправить говно текст за вас",
        execute = function(args)
            write("! " .. table.concat(args, " ") .. "\n")
        end
    },
    exit = {
        description = "выйти",
        execute = function()
            write("пока компьютер!\n")
            computer.shutdown()
        end
    }
}

-- Функция для вывода текста через GPU
function write(text)
    local w, h = gpu.getResolution()
    local x, y = gpu.getCursor()
    
    for i = 1, #text do
        local char = text:sub(i, i)
        if char == "\n" then
            y = y + 1
            x = 1
            if y > h then
                y = h
                gpu.copy(1, 2, w, h - 1, 0, -1)
                gpu.fill(1, h, w, 1, " ")
            end
        else
            gpu.set(x, y, char)
            x = x + 1
            if x > w then
                x = 1
                y = y + 1
                if y > h then
                    y = h
                    gpu.copy(1, 2, w, h - 1, 0, -1)
                    gpu.fill(1, h, w, 1, " ")
                end
            end
        end
        gpu.setCursor(x, y)
    end
end

-- Инициализация
gpu.setResolution(80, 25)
gpu.fill(1, 1, 80, 25, " ")
gpu.setCursor(1, 1)

write("TemOS loaded\n")
write("введите 'help' для списка говно-команд\n")

while true do
    write("> ")
    local input = io.read():gsub("^%s*(.-)%s*$", "%1")
    
    if input ~= "" then
        local parts = {}
        for part in input:gmatch("%S+") do
            table.insert(parts, part)
        end
        
        local command = parts[1]:lower()
        table.remove(parts, 1)
        
        if commands[command] then
            local success, err = pcall(function()
                commands[command].execute(parts)
            end)
            
            if not success then
                write("ай бля ошибка: " .. err .. "\n")
            end
        else
            write("ойойой нет такой команды пошел науй: " .. command .. "\n")
            write("напомню 'help' введи даун\n")
        end
    end
end
