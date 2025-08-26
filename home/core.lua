-- TemOS Core System Functions
local component = require("component")
local computer = require("computer")
local event = require("event")

local core = {}

-- Получение информации о системе
function core.getSystemInfo()
    return {
        memory = computer.totalMemory(),
        freeMemory = computer.freeMemory(),
        uptime = computer.uptime(),
        address = computer.address()
    }
end

-- Управление питанием
function core.reboot()
    computer.shutdown(true)
end

function core.shutdown()
    computer.shutdown()
end

-- Работа с компонентами
function core.listComponents(typeFilter)
    local components = {}
    for address, ctype in component.list(typeFilter) do
        table.insert(components, {
            address = address,
            type = ctype,
            proxy = component.proxy(address)
        })
    end
    return components
end

return core
