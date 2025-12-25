--!strict
local Scope = require("./Scope")

type Listener = {
    Callback: (...any) -> (),
    Connected: boolean
}

export type Connection = {
    Connected: boolean,
    Disconnect: (self: Connection) -> ()
}

export type Signal<T...> = {
    Connect: (
        self: Signal<T...>,
        FiredCallback: (T...) -> (),
        Scope: Scope.Implementation?
    ) -> Connection,

    Once: (
        self: Signal<T...>,
        FiredCallback: (T...) -> (),
        Scope: Scope.Implementation?
    ) -> Connection,

    Fire: (self: Signal<T...>, T...) -> (),
    Wait: (self: Signal<T...>) -> (T...),
    DisconnectAll: (self: Signal<T...>) -> (),
    Destroy: (self: Signal<T...>) -> (),
    ListenerCount: (self: Signal<T...>) -> (number),
}

-- Signal Module
local Module = {}

local function MakeConnection(self: any, listener: Listener): Connection
    local Conn = {} :: any
    
    Conn.Connected = true
    function Conn:Disconnect()
        if not Conn.Connected then
            return
        end

        Conn.Connected = false
        listener.Connected = false
    end

    return (Conn :: any) :: Connection
end

function Module.new<T...>(): Signal<T...>
    local self = {
        Listeners = {} :: { Listener },
        WaitQueue = {} :: { ((T...) -> ()) },
        Destroyed = false,
    }

    return (setmetatable(self, Module) :: any) :: Signal<T...>
end

function Module:Connect<T...>(
    FiredCallback: (T...) -> (),
    Scope: Scope.Implementation?
): Connection
    if self.Destroyed then
        return nil :: any
    end

    local listener: Listener = {
        Callback = FiredCallback,
        Connected = true
    }

    table.insert(self.Listeners, listener)
    local Conn = MakeConnection(self, listener)

    if Scope then
        Scope:Add(Conn)
    end

    return Conn
end

function Module:Once<T...>(
    FiredCallback: (T...) -> (),
    Scope: Scope.Implementation?
): Connection
   local Conn: Connection = nil
   
   Conn = self:Connect(function(...: T...)
        if Conn then
            Conn:Disconnect()
        end

        FiredCallback(...)
    end, Scope)

    return Conn
end

function Module:Fire( ... )
    if self.Destroyed then
        return
    end

    -- resume waiting queue
    local Waiting: {thread} = self.WaitQueue
    self.WaitQueue = {}

    if #Waiting > 0 then
        for _, YieldingThread in Waiting do
            task.defer(coroutine.resume, YieldingThread, ... )
        end
    end

    -- call remaining listeners
    local Listeners: { Listener } = self.Listeners

    for _, listener in Listeners do
        if not listener.Connected then
            continue
        end

        task.spawn(pcall, listener.Callback, ... )
    end
end

function Module:Wait()
    if self.Destroyed then
        return nil :: any
    end

    local Thread = coroutine.running()
    table.insert(self.WaitQueue, Thread)
    return coroutine.yield()
end

function Module:Await()
    -- unimplemented until Promises are added
end

function Module:DisconnectAll()
    for _, listener in self.Listeners do
        listener.Connected = false
    end

    self.Listeners = {}
end

function Module:Destroy()
    if self.Destroyed then
        return
    end

    self:DisconnectAll()
    self.Destroyed = true

    -- resume waiting queue
    local Waiting: {thread} = self.WaitQueue

    for _, YieldingThread in Waiting do
        task.defer(coroutine.resume, YieldingThread)
    end
end

function Module:ListenerCount(): number
    local Count = 0

    for _, listener in self.Listeners do
        if not listener.Connected then
            continue
        end

        Count += 1
    end

    return Count
end

return Module
