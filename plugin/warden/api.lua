---@module "warden.api"

---@class Warden
local M = {}

local assert = require "warden.assert"
local compile = require "warden.compile"
local types = require "warden.types"

M.assert = assert

M.any = types.any
M.boolean = types.boolean
M.string = types.string
M.number = types.number
M.integer = types.integer
M.table = types.table
M.array = types.array
M.tuple = types.tuple
M.map = types.map
M.record = types.record
M.object = types.object
M.enum = types.enum
M.literal = types.literal
M.union = types.union
M.compile = compile.compile

return M
