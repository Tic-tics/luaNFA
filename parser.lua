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

local startStates = lpeg.Cg(((lpeg.Ct(startState^1) * lpeg.Cb("states")) / setStarts), "states")

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

local finalStates = lpeg.Cg(((lpeg.Ct(finalState^1) * lpeg.Cb("states")) / setFinals), "states")

local transitions = lpeg.Cg(lpeg.Ct(transition^0), "transitions")

local nfa = lpeg.Ct(states * startStates * finalStates * transitions)

function buildNFA(nfaFile)
  return lpeg.match(nfa, nfaFile)
end

function buildNFAFromFile(nfaFileName)
  local f = assert(io.open(nfaFileName, "r"))
  local s = f:read("*all")
  f:close()
  return buildNFA(s)
end