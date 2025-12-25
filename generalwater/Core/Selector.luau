--!strict
export type Selector<I, O> = (I) -> O

local Module = {}

function Module.new<A, B, I, O>(
    A: Selector<I, A>,
    B: Selector<I, B>,
    Combine: (A, B) -> O
): Selector<I, O>
    local LastA: A? = nil
    local LastB: B? = nil
    local LastOutput: O? = nil
    local Changed: boolean = false

    return function(Input: I): O
        local NewA = A(Input)
        local NewB = B(Input)

        if Changed and (NewA == LastA) and (NewB == LastB) then
            return LastOutput :: O
        end

        LastA = NewA
        LastB = NewB
        LastOutput = Combine(NewA, NewB)
        Changed = true
        
        return LastOutput :: O
    end
end

return Module
