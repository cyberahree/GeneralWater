--!strict
local Module = {}
Module.__index = Module

export type DisposableObject = 
    RBXScriptConnection | thread | Instance | (() -> nil) | { Disconnect: (self: any) -> () }

export type Implementation = {
    Disposables: {DisposableObject},
    Alive: boolean,
    DestructionConnection: RBXScriptConnection?,

    Destroy: (self: Implementation) -> (),
    Add: (self: Implementation, Disposable: DisposableObject) -> (),
    LinkToInstance: (self: Implementation, Instance: Instance) -> (),
}

function Module:Add(Disposable: DisposableObject)
    -- Adds a disposible task that will get cleaned when the scope is destroyed
    if not self.Alive then
        return
    end

    table.insert(self.Disposables, Disposable)
end

function Module:Destroy()
    -- Destroy linked tasks and instances
    if not self.Alive then
        return
    end

    self.Alive = false

    if self.DestructionConnection then
        self.DestructionConnection:Disconnect()
    end

    for _, disposable in self.Disposables do
        local State, Response = pcall(function()
            local Type = typeof(disposable)

            if Type == "RBXScriptConnection" then
                disposable:Disconnect()
            elseif Type == "thread" then
                task.cancel(disposable)
            elseif Type == "Instance" then
                disposable:Destroy()
            elseif Type == "function" then
                disposable()
            elseif Type == "table" and disposable.Disconnect ~= nil then
                disposable:Disconnect()
            end
        end)

        if not State then
            warn(`Failed to dispose of item {tostring(disposable)}: {Response}`)
        end
    end

    self.Disposables = nil
end

function Module:LinkToInstance(Instance: Instance)
    if not self.Alive then
        return
    end

    if self.DestructionConnection then
        warn("Scope is already linked to an instance, overwriting previous link.")
        self.DestructionConnection:Disconnect()
    end

    self.DestructionConnection = Instance.AncestryChanged:Connect(function(_, Parent)
        if not Parent then
            self:Destroy()
        end
    end)
end

function Module.new()
    local self = {
        Disposables = {},
        Alive = true,
    }

    return (setmetatable(self, Module) :: any) :: Implementation
end

return Module
