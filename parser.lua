local lpeg = require "lpeg"

local lcLetter = lpeg.R("az")
local ucLetter = lpeg.R("AZ")
local digit = lpeg.R("09")

local alphaNumeric = lcLetter + ucLetter + digit

local name = lpeg.C((alphaNumeric)^1)
local token = lpeg.P("<") * name * lpeg.P(">")

local space = lpeg.P(" ")
local tab = lpeg.P("\t")
local whitespace = (space + tab)^1

local endline = whitespace^0 * lpeg.P("\n")^1

local state = lpeg.P("state") * whitespace * name * endline

local startState = lpeg.P("start") * whitespace * name * endline

local finalState = lpeg.P("final") * whitespace * name * endline

local tokenTransition = lpeg.Ct(lpeg.P("transition") * whitespace * lpeg.Cg(name, "from") * whitespace * lpeg.Cg(name, "to") * whitespace * lpeg.Cg(token, "token") * endline)

local epsilon = lpeg.Ct(lpeg.P("epsilon") * whitespace * lpeg.Cg(name, "from") * whitespace * lpeg.Cg(name, "to") * lpeg.Cg(lpeg.Cc(""), "token") * endline)

local transition = tokenTransition + epsilon

-- Stage 1, we create a table with keys as the names of states, and each value is just an empty table
-- We will back-capture this table repeatedly to evolve it into an interlinked state machine
local function createStateTable(table)
  local stateTable = {}
  for _, v in pairs(table) do
    stateTable[v] = {}
  end
  
  return stateTable
end

local states = lpeg.Cg(lpeg.Ct(state^1) / createStateTable, "states")

-- Stage 2, this function takes in the list of start states (by name) and the state table (backcaptured)
-- It just sets "start" to true for the states that are start states
local function setStarts(startStates, states)
  for _,name in pairs(startStates) do
    if states[name] == nil then
      assert(false, "Attempt to use a nondeclared state in start command : " .. name)
    end
    
    states[name].start = true
  end
  
  return states
end

local startStates = lpeg.Cg((lpeg.Ct(startState^1) * lpeg.Cb("states")) / setStarts, "states")

-- Stage 3, this function takes in the list of final states (by name) and the state table (backcaptured)
-- It just sets "final" to true for the states that are final states
local function setFinals(finalStates, states)
  for _, name in pairs(finalStates) do
    if states[name] == nil then
      assert(false, "Attempt to use a nondeclared state in state command : " .. name)
    end
    
    states[name].final = true
  end
  
  return states
end

local finalStates = lpeg.Cg((lpeg.Ct(finalState^1) * lpeg.Cb("states")) / setFinals, "states")

-- Stage 4, this function takes in the list of transitions and adds them to the appropriate state's transition tables
local function setTransitions(transitions, states)
  for _, transition in pairs(transitions) do
    assert(states[transition.from], "Attempt to use a nondeclared state as a transition source : " .. transition.from)
    assert(states[transition.to], "Attempt to use a nondeclared state as a transition destination : " .. transition.to)
    
    if states[transition.from].delta == nil then states[transition.from].delta = {} end
    if states[transition.from].delta[transition.token] == nil then states[transition.from].delta[transition.token] = {} end
    
    table.insert(states[transition.from].delta[transition.token], transition.to)
  end
  
  return states
end

local transitions = lpeg.Cg((lpeg.Ct(transition^0) * lpeg.Cb("states")) / setTransitions, "states")

local nfa = lpeg.Ct(states * startStates * finalStates * transitions)

local function tableSize(t)
  local i = 0
  for _,_ in pairs(t) do
    i = i + 1
  end
  return i
end

local function tableRunner(nfaStates)
  local states = nfaStates
  return coroutine.create( function ()
      -- Start in the start states
      local currentStates = {}
      for k,v in pairs(states) do
        print("putting state ", k, v, v.start)
        if v.start then currentStates[k] = true end
      end
      
      -- Lazy inefficent epsilon transform
        -- Applies epsilon "character" n times, where n is the number of states
        for i = 0,tableSize(states) do
          for k,v in pairs(states) do
            if currentStates[k] then
              if v.delta[""] then
                for _,state in pairs(v.delta[""]) do
                  print(state, " is a next state via epsilon")
                  nextStates[state] = true
                end
              end
            end
          end
        end
      
      while true do
        local inFinal = nil
        for k,_ in pairs(currentStates) do
          print("checking state ", k)
          inFinal = inFinal or states[k].final
        end
        local nextToken = coroutine.yield(currentStates, inFinal)
        assert(type(nextToken) == "string", "Tokens must be strings")
        
        if nextToken == "" then return inFinal end
        
        local nextStates = {}
        
        -- Apply the transition for the next token
        for k,v in pairs(states) do
          if currentStates[k] then
            if v.delta and v.delta[nextToken] then
              for _,state in pairs(v.delta[nextToken]) do
                print(state, " is a next state")
                nextStates[state] = true
              end
            end
          end
        end
        
        -- Lazy inefficent epsilon transform
        -- Applies epsilon "character" n times, where n is the number of states
        for i = 0,tableSize(states) do
          for k,v in pairs(states) do
            if nextStates[k] then
              if v.delta and v.delta[""] then
                for _,state in pairs(v.delta[""]) do
                  print(state, " is a next state via epsilon")
                  nextStates[state] = true
                end
              end
            end
          end
        end
        
        currentStates = nextStates
        listEntries(currentStates)
      end
    end)
end

function buildNFA(nfaFile)
  local nfaTable = lpeg.match(nfa, nfaFile)
  
  nfaTable.initialize = function ()
    nfaTable.runner = tableRunner(nfaTable.states)
    local success = nil
    success, nfaTable.currentStates, nfaTable.inFinal = coroutine.resume(nfaTable.runner)
    return nfaTable.currentStates, nfaTable.inFinal
  end
  
  nfaTable.step = function (token)
    local success = nil
    success, nfaTable.currentStates, nfaTable.inFinal = coroutine.resume(nfaTable.runner, token)
    return nfaTable.currentStates, nfaTable.inFinal
  end
  
  nfaTable.finalize = function ()
    local success = nil
    success, nfaTable.inFinal = coroutine.resume(nfaTable.runner, "")
    return nfaTable.inFinal
  end
  
  return nfaTable
end

function buildNFAFromFile(nfaFileName)
  local f = assert(io.open(nfaFileName, "r"))
  local s = f:read("*all")
  f:close()
  return buildNFA(s)
end