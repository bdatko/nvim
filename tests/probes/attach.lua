local out = assert(vim.env.NVIM_TEST_ATTACH_OUT, "NVIM_TEST_ATTACH_OUT is not set")
local proj = assert(vim.env.NVIM_TEST_PROJECT, "NVIM_TEST_PROJECT is not set")

-- Drop anything captured during startup; this probe only cares about attach.
if _G.__test_capture then
  _G.__test_capture.deprecations = {}
end
vim.cmd("messages clear")

local fixtures = {
  { file = "a.awk", clients = { "awk_ls" } },
  { file = "a.lua", clients = { "lua_ls" } },
  { file = "a.py", clients = { "basedpyright", "ruff" } },
  { file = "a.go", clients = { "gopls" } },
  { file = "a.toml", clients = { "taplo" } },
  { file = "a.ts", clients = { "biome" } },
}

local function client_names(bufnr)
  local names = {}

  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    names[#names + 1] = client.name
  end

  table.sort(names)
  return names
end

local function has_all(names, expected)
  local present = {}

  for _, name in ipairs(names) do
    present[name] = true
  end

  for _, name in ipairs(expected) do
    if not present[name] then
      return false
    end
  end

  return true
end

local function desc_of(lhs)
  local mapping = vim.fn.maparg(lhs, "n", false, true)

  if type(mapping) == "table" then
    return mapping.desc
  end

  return nil
end

local results = {}

for _, fixture in ipairs(fixtures) do
  vim.cmd.edit(proj .. "/" .. fixture.file)

  local attached = vim.wait(15000, function()
    return has_all(client_names(0), fixture.clients)
  end, 100)

  results[#results + 1] = {
    file = fixture.file,
    ft = vim.bo.filetype,
    expected = fixture.clients,
    clients = client_names(0),
    attached = attached,
    keymaps = {
      grt = desc_of("grt"),
      grn = desc_of("grn"),
      gra = desc_of("gra"),
      grr = desc_of("grr"),
      gO = desc_of("gO"),
      grd = desc_of("grd"),
    },
  }
end

local configs = {}
for _, name in ipairs({
  "lua_ls",
  "biome",
  "awk_ls",
  "gopls",
  "taplo",
  "basedpyright",
  "ruff",
}) do
  configs[name] = {
    configured = vim.lsp.config[name] ~= nil,
    enabled = vim.lsp.is_enabled(name),
  }
end

local basedpyright = vim.lsp.config["basedpyright"]
local ruff = vim.lsp.config["ruff"]

local settings = {
  basedpyright_diagnostic_mode = basedpyright
      and basedpyright.settings
      and basedpyright.settings.basedpyright
      and basedpyright.settings.basedpyright.analysis
      and basedpyright.settings.basedpyright.analysis.diagnosticMode
    or false,
  ruff_ignore = ruff
      and ruff.init_options
      and ruff.init_options.settings
      and ruff.init_options.settings.lint
      and ruff.init_options.settings.lint.ignore
    or {},
  diagnostic_severity_sort = vim.diagnostic.config().severity_sort == true,
}

local deprecations = _G.__test_capture and _G.__test_capture.deprecations or {}
local messages = vim.api.nvim_exec2("messages", { output = true }).output or ""

vim.fn.writefile({
  vim.json.encode({
    fixtures = results,
    configs = configs,
    settings = settings,
    deprecations = deprecations,
    messages = messages,
  }),
}, out)

vim.cmd("qa!")
