local M = {}

local function neoconf(config)
  pcall(function()
    require("neoconf.plugins").register({
      on_schema = function(schema)
        schema:import("luajava", config.defaults)
      end,
    })
  end)
end

---@param opts? LuaJavaOptions
function M.setup(opts)
  local config = require("luajava.config")
  config.setup(opts)

  neoconf(config)
end

return M
