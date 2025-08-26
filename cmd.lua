local commands = {
    help = {
        description = "команды",
        execute = function()
            io.write("сегодня вам доступно\n")
            for cmd, info in pairs(commands) do
                io.write(string.format("  %-10s - %s\n", cmd, info.description))
            end
        end
    },
    time = {
        description = "время",
        execute = function()
            io.write("время: " .. os.date("%H:%M:%S") .. "\n")
        end
    },
    date = {
        description = "число седня",
        execute = function()
            io.write("сегодня: " .. os.date("%d.%m.%Y") .. "\n")
        end
    },
    clear = {
        description = "удалить все науй",
        execute = function()
            os.execute("cls || clear")
        end
    },
    echo = {
        description = "отправить говно текст за вас",
        execute = function(args)
            io.write("! " .. table.concat(args, " ") .. "\n")
        end
    },
    exit = {
        description = "выйти",
        execute = function()
            io.write("пока компьютер!\n")
            os.exit()
        end
    }
}

io.write("TemOS loaded\n")
io.write("введите 'help' для списка говно-команд\n")

while true do
    io.write("> ")
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
                io.write("ай бля ошибка: " .. err .. "\n")
            end
        else
            io.write("ойойой нет такой команды пошел науй: " .. command .. "\n")
            io.write("напомню 'help' введи даун\n")
        end
    end
end
