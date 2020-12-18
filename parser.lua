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

local transition = lpeg.Ct(lpeg.P("transition") * whitespace * lpeg.Cg(name, "from") * whitespace * lpeg.Cg(name, "to") * whitespace * lpeg.Cg(token, "token") * endline)

local epsilon = lpeg.Ct(lpeg.P("epsilon") * whitespace * lpeg.Cg(name, "from") * whitespace * lpeg.Cg(name, "to") * lpeg.Cg(lpeg.Cc(""), "token") * endline)
 
local states = lpeg.Cg(lpeg.Ct(state^1), "states")
local startStates = lpeg.Cg(lpeg.Ct(startState^1), "startStates")
local finalStates = lpeg.Cg(lpeg.Ct(finalState^1), "finalStates")
local transitions = lpeg.Cg(lpeg.Ct(transition^0), "transitions")
local epsilons = lpeg.Cg(lpeg.Ct(epsilon^0), "epsilons")

local nfa = lpeg.Ct(states * startStates * finalStates * transitions * epsilons)

function buildNFA(nfaFile)
  return lpeg.match(nfa, nfaFile)
end

function buildNFAFromFile(nfaFileName)
  local f = assert(io.open(nfaFileName, "r"))
  local s = f:read("*all")
  f:close()
  return buildNFA(s)
end