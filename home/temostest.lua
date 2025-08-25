local commands = {
    help = {
        description = "commands",
        execute = function()
            print("седня вам доступно:")
            for cmd, info in pairs(commands) do
                print(string.format("  %-10s - %s", cmd, info.description))
            end
        end
    },
    time = {
        description = "время",
        execute = function()
            print("время: " .. os.date("%H:%M:%S"))
        end
    },
    date = {
        description = "дата",
        execute = function()
            print("сегодня: " .. os.date("%d.%m.%Y"))
        end
    },
    clear = {
        description = "уебашить всю консоль",
        execute = function()
            os.execute("cls || clear")
        end
    },
    echo = {
        description = "повторить веденное вами говно",
        execute = function(args)
            print("" .. table.concat(args, " "))
        end
    },
    exit = {
        description = "выйти (обязательно сломано)",
        execute = function()
            print("бб нахуй!")
            os.exit()
        end
    }
}

print("добро пожаловать мразь")
print("пропиши help мразь")

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
                print("ошибка братишка субо: " .. err)
            end
        else
            print("ало даун нет такой команды а именно " .. command)
            print("напиши help ебаный блять уебок")
        end
    end
end
