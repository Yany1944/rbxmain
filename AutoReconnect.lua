local DEFAULT_INTERVAL = 25 * 60

local function StartReconnectCountdown(State, Rejoin)
    local interval = State.ReconnectInterval or DEFAULT_INTERVAL
    local elapsed = 0
    
    while State.AutoReconnectEnabled do
        task.wait(1)
        elapsed = elapsed + 1
        
        if elapsed >= interval then
            Rejoin()
            return
        end
    end
end

return {
    HandleAutoReconnect = function(enabled, State, Rejoin)
        State.AutoReconnectEnabled = enabled
        
        if State.ReconnectThread then
            task.cancel(State.ReconnectThread)
            State.ReconnectThread = nil
        end
        
        if enabled then
            State.ReconnectThread = task.spawn(function()
                StartReconnectCountdown(State, Rejoin)
            end)
        end
    end,
    
    SetReconnectInterval = function(minutes, State)
        local mins = tonumber(minutes) or 25
        State.ReconnectInterval = mins * 60
        print(string.format("[Auto Reconnect] Interval: %d min (%d sec)", mins, State.ReconnectInterval))
    end
}
