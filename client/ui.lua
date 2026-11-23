UI = { focus = {}, rpc = {}, ready = false, queue = {}, closers = {} }

function UI.Send(app, action, data)
    local message = { app = app, action = action, data = data }
    if not UI.ready then
        UI.queue[#UI.queue + 1] = message
        return
    end
    SendNUIMessage(message)
end

local function applyFocus()
    local want, cursor = false, false
    for _, f in pairs(UI.focus) do
        want = true
        if f.cursor then cursor = true end
    end
    SetNuiFocus(want, cursor)
end

function UI.Focus(owner, on)
    if on then UI.focus[owner] = { cursor = true } else UI.focus[owner] = nil end
    applyFocus()
end

function UI.Handle(name, fn)
    UI.rpc[name] = fn
end

function UI.OnClose(app, fn)
    UI.closers[app] = fn
end

RegisterNUICallback('ready', function(_, cb)
    UI.ready = true
    for _, message in ipairs(UI.queue) do SendNUIMessage(message) end
    UI.queue = {}
    cb(true)
end)

RegisterNUICallback('rpc', function(data, cb)
    local handler = type(data) == 'table' and UI.rpc[data.name] or nil
    if not handler then
        cb({ ok = false, error = 'That did not go through.' })
        return
    end
    local ok, a, b = pcall(handler, data.payload or {})
    if not ok then
        print(('^1[XS-AirDrops]^0 NUI %s failed: %s'):format(tostring(data.name), tostring(a)))
        cb({ ok = false, error = 'That did not go through.' })
        return
    end
    if a == false then
        cb({ ok = false, error = b or 'That did not go through.' })
    else
        cb({ ok = true, data = a == true and b or a })
    end
end)

RegisterNUICallback('close', function(data, cb)
    local app = type(data) == 'table' and data.app or nil
    if app and UI.closers[app] then
        pcall(UI.closers[app])
    else
        UI.focus = {}
        applyFocus()
    end
    cb(true)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if next(UI.focus) then SetNuiFocus(false, false) end
end)
