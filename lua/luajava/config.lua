local M = {}

--- @class LuaJavaOptions
M.defaults = {
  library = {
    types = true, -- full signature, docs and completion of vim.api, vim.treesitter, vim.lsp and others
  },
}

--- @type LuaJavaOptions
M.options = {}

function M.setup(options)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, options or {})
end

function M.types()
  return M.root("/types/")
end

---@param root? string
function M.root(root)
  local f = debug.getinfo(1, "S").source:sub(2)
  return vim.loop.fs_realpath(vim.fn.fnamemodify(f, ":h:h:h") .. "/" .. (root or ""))
end

return M
