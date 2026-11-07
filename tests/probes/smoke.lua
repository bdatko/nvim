-- Functional smoke probe. Each result maps to a row of the manual matrix.
-- Visual rendering stays manual; this probe asserts the data and state behind it.
local out = assert(vim.env.NVIM_TEST_SMOKE_OUT, "NVIM_TEST_SMOKE_OUT is not set")
local proj = assert(vim.env.NVIM_TEST_PROJECT, "NVIM_TEST_PROJECT is not set")
local standalone = assert(vim.env.NVIM_TEST_STANDALONE, "NVIM_TEST_STANDALONE is not set")

local CUSTOM_GRT_DESC = "[G]oing [R]ight into [T]ype definition"

local debug_enabled = vim.env.NVIM_TEST_SMOKE_DEBUG == "1"

local function debug(message)
  if debug_enabled then
    io.stderr:write("[smoke] " .. message .. "\n")
  end
end

local results = {}

local function add(id, ok, detail)
  results[#results + 1] = {
    id = id,
    ok = ok and true or false,
    detail = detail or "",
  }
end

local function client_names(bufnr)
  local names = {}

  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    names[#names + 1] = client.name
  end

  table.sort(names)
  return names
end

local function has_client(bufnr, name)
  for _, candidate in ipairs(client_names(bufnr)) do
    if candidate == name then
      return true
    end
  end

  return false
end

local function open(path, expected)
  vim.cmd.edit(path)

  local bufnr = vim.api.nvim_get_current_buf()
  local attached = vim.wait(20000, function()
    return expected == nil or has_client(bufnr, expected)
  end, 100)

  return bufnr, attached
end

local function diagnostics(bufnr)
  return vim.diagnostic.get(bufnr)
end

local function diagnostics_from(bufnr, needle)
  local found = {}

  for _, diagnostic in ipairs(diagnostics(bufnr)) do
    local source = string.lower(diagnostic.source or "")

    if source:find(needle, 1, true) then
      found[#found + 1] = diagnostic
    end
  end

  return found
end

local function wait_diagnostics(bufnr, needle, timeout)
  return vim.wait(timeout or 15000, function()
    if needle == nil then
      return #diagnostics(bufnr) > 0
    end

    return #diagnostics_from(bufnr, needle) > 0
  end, 100)
end

local function find_pos(bufnr, lnum, needle)
  local line = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1] or ""
  local start = line:find(needle, 1, true)

  if start == nil then
    return nil
  end

  return { line = lnum, character = start - 1 }
end

local function text_document(bufnr)
  return vim.lsp.util.make_text_document_params(bufnr)
end

local function request(bufnr, method, params, timeout)
  local responses = vim.lsp.buf_request_sync(bufnr, method, params, timeout or 10000)

  if responses == nil then
    return nil
  end

  for _, response in pairs(responses) do
    if response.result ~= nil then
      return response.result
    end
  end

  return nil
end

local function position_request(bufnr, method, pos, timeout)
  return request(bufnr, method, {
    textDocument = text_document(bufnr),
    position = pos,
  }, timeout)
end

local function nonempty(result)
  if result == nil then
    return false
  end

  if vim.islist(result) then
    return #result > 0
  end

  return result.uri ~= nil or result.targetUri ~= nil
end

local function supports(bufnr, client_name, method)
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client.name == client_name then
      return client:supports_method(method)
    end
  end

  return false
end

local function desc(lhs)
  local mapping = vim.fn.maparg(lhs, "n", false, true)

  if type(mapping) == "table" then
    return mapping.desc
  end

  return nil
end

local function to_lsp_diagnostic(diagnostic)
  if diagnostic.user_data and diagnostic.user_data.lsp then
    return diagnostic.user_data.lsp
  end

  return {
    range = {
      start = { line = diagnostic.lnum, character = diagnostic.col },
      ["end"] = { line = diagnostic.end_lnum, character = diagnostic.end_col },
    },
    severity = diagnostic.severity,
    source = diagnostic.source,
    message = diagnostic.message,
    code = diagnostic.code,
  }
end

local function code_action_titles(bufnr, diagnostic)
  local raw = to_lsp_diagnostic(diagnostic)
  local responses = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", {
    textDocument = text_document(bufnr),
    range = raw.range,
    context = { diagnostics = { raw } },
  }, 10000)

  local titles = {}

  for _, response in pairs(responses or {}) do
    for _, action in ipairs(response.result or {}) do
      titles[#titles + 1] = action.title or ""
    end
  end

  return titles
end

local function join(problems, fallback)
  if #problems == 0 then
    return fallback
  end

  return table.concat(problems, "; ")
end

debug("M8 start")
-- M8: awk_ls keeps Neovim's default grt mapping.
do
  local problems = {}
  local _, attached = open(proj .. "/a.awk", "awk_ls")

  if not attached then
    problems[#problems + 1] = "awk_ls did not attach"
  end

  local desc_grt = desc("grt")
  if desc_grt == nil then
    problems[#problems + 1] = "grt missing"
  elseif desc_grt == CUSTOM_GRT_DESC then
    problems[#problems + 1] = "custom grt applied"
  elseif not string.find(desc_grt, "type_definition", 1, true) then
    problems[#problems + 1] = "unexpected grt desc " .. desc_grt
  end

  add("M8", #problems == 0, join(problems, "awk_ls attach + default grt"))
end

debug("M1 start")
-- M1: lua_ls diagnostics, hover, definition, references, document symbols,
-- rename capability, and the Lua keymaps.
do
  local problems = {}
  local bufnr, attached = open(proj .. "/smoke.lua", "lua_ls")

  if not attached then
    problems[#problems + 1] = "lua_ls did not attach"
  end
  if not wait_diagnostics(bufnr, nil, 15000) then
    problems[#problems + 1] = "no diagnostic"
  end

  local add_pos = find_pos(bufnr, 4, "add")
  if add_pos == nil then
    problems[#problems + 1] = "fixture has no add call"
  else
    if not nonempty(request(bufnr, "textDocument/definition", {
      textDocument = text_document(bufnr),
      position = add_pos,
    })) then
      problems[#problems + 1] = "no definition"
    end

    if not nonempty(request(bufnr, "textDocument/references", {
      textDocument = text_document(bufnr),
      position = add_pos,
      context = { includeDeclaration = true },
    })) then
      problems[#problems + 1] = "no references"
    end
  end

  local def_pos = find_pos(bufnr, 0, "add")
  if def_pos ~= nil then
    local hover = position_request(bufnr, "textDocument/hover", def_pos)
    if hover == nil or hover.contents == nil then
      problems[#problems + 1] = "no hover"
    end
  end

  if not nonempty(request(bufnr, "textDocument/documentSymbol", {
    textDocument = text_document(bufnr),
  })) then
    problems[#problems + 1] = "no document symbols"
  end

  if not supports(bufnr, "lua_ls", "textDocument/rename") then
    problems[#problems + 1] = "no rename support"
  end

  for _, lhs in ipairs({ "grn", "gra", "grr", "grd", "gO" }) do
    if desc(lhs) == nil then
      problems[#problems + 1] = lhs .. " missing"
    end
  end

  add("M1", #problems == 0, join(problems, "lua_ls diagnostics, hover, defs, refs, symbols, keymaps"))
end

debug("M9 start")
-- M9: grt in a Lua buffer uses the custom Telescope picker.
do
  local desc_grt = desc("grt")
  add("M9", desc_grt == CUSTOM_GRT_DESC, "grt=" .. tostring(desc_grt))
end

debug("M2 start")
-- M2: basedpyright diagnostics, hover, document symbols, rename capability.
do
  local problems = {}
  local bufnr, attached = open(proj .. "/smoke.py", "basedpyright")

  if not attached then
    problems[#problems + 1] = "basedpyright did not attach"
  end
  if not wait_diagnostics(bufnr, "pyright", 20000) then
    problems[#problems + 1] = "no basedpyright diagnostic"
  end

  local add_pos = find_pos(bufnr, 3, "add")
  if add_pos ~= nil then
    local hover = position_request(bufnr, "textDocument/hover", add_pos)
    if hover == nil or hover.contents == nil then
      problems[#problems + 1] = "no hover"
    end
  end

  if not nonempty(request(bufnr, "textDocument/documentSymbol", {
    textDocument = text_document(bufnr),
  })) then
    problems[#problems + 1] = "no document symbols"
  end

  if not supports(bufnr, "basedpyright", "textDocument/rename") then
    problems[#problems + 1] = "no rename support"
  end

  for _, lhs in ipairs({ "grn", "gra", "gO" }) do
    if desc(lhs) == nil then
      problems[#problems + 1] = lhs .. " missing"
    end
  end

  add("M2", #problems == 0, join(problems, "basedpyright diagnostics, hover, symbols, keymaps"))
end

debug("M3 start")
-- M3: ruff diagnostics and a Ruff code action.
do
  local problems = {}
  local bufnr, attached = open(proj .. "/smoke.py", "ruff")

  if not attached then
    problems[#problems + 1] = "ruff did not attach"
  end
  if not wait_diagnostics(bufnr, "ruff", 20000) then
    problems[#problems + 1] = "no ruff diagnostic"
  end

  local ruff_diagnostic = diagnostics_from(bufnr, "ruff")[1]
  if ruff_diagnostic == nil then
    problems[#problems + 1] = "no ruff diagnostic"
  else
    local titles = code_action_titles(bufnr, ruff_diagnostic)
    local found_fix = false

    for _, title in ipairs(titles) do
      local lower = string.lower(title)

      if lower:find("ruff", 1, true) or lower:find("fix", 1, true) or lower:find("remove", 1, true) then
        found_fix = true
      end
    end

    if not found_fix then
      problems[#problems + 1] = "no ruff code action"
    end
  end

  add("M3", #problems == 0, join(problems, "ruff diagnostic + code action"))
end

debug("M4 start")
-- M4: gopls diagnostics, hover, references, document symbols.
do
  local problems = {}
  local bufnr, attached = open(proj .. "/smoke.go", "gopls")

  if not attached then
    problems[#problems + 1] = "gopls did not attach"
  end
  if not wait_diagnostics(bufnr, nil, 20000) then
    problems[#problems + 1] = "no diagnostic"
  end

  local add_pos = find_pos(bufnr, 4, "add")
  if add_pos ~= nil then
    local hover = position_request(bufnr, "textDocument/hover", add_pos)
    if hover == nil or hover.contents == nil then
      problems[#problems + 1] = "no hover"
    end

    if not nonempty(request(bufnr, "textDocument/references", {
      textDocument = text_document(bufnr),
      position = add_pos,
      context = { includeDeclaration = true },
    })) then
      problems[#problems + 1] = "no references"
    end
  end

  if not nonempty(request(bufnr, "textDocument/documentSymbol", {
    textDocument = text_document(bufnr),
  })) then
    problems[#problems + 1] = "no document symbols"
  end

  add("M4", #problems == 0, join(problems, "gopls diagnostics, hover, references, symbols"))
end

debug("M5 start")
-- M5: taplo diagnostic for malformed TOML.
do
  local problems = {}
  local bufnr, attached = open(proj .. "/a.toml", "taplo")

  if not attached then
    problems[#problems + 1] = "taplo did not attach"
  end
  if not wait_diagnostics(bufnr, nil, 15000) then
    problems[#problems + 1] = "no diagnostic"
  end

  add("M5", #problems == 0, join(problems, "taplo diagnostic"))
end

debug("M6 start")
-- M6: Biome inside a project: diagnostics and a code action.
do
  local problems = {}
  local bufnr, attached = open(proj .. "/smoke.ts", "biome")

  if not attached then
    problems[#problems + 1] = "biome did not attach"
  end
  if not wait_diagnostics(bufnr, nil, 20000) then
    problems[#problems + 1] = "no diagnostic"
  end

  local diagnostic = diagnostics(bufnr)[1]
  if diagnostic ~= nil then
    local titles = code_action_titles(bufnr, diagnostic)
    if #titles == 0 then
      problems[#problems + 1] = "no code action"
    end
  end

  add("M6", #problems == 0, join(problems, "biome project diagnostics + code action"))
end

debug("M7 start")
-- M7: Biome outside a project must not attach.
do
  local problems = {}
  local bufnr = open(standalone .. "/solo.ts", nil)

  -- Give the client a moment to start if it were going to.
  vim.wait(2500, function()
    return false
  end, 100)

  if has_client(bufnr, "biome") then
    problems[#problems + 1] = "biome attached without biome.json"
  end

  add("M7", #problems == 0, join(problems, "biome stays detached outside a project"))
end

debug("M10 start")
-- M10: diagnostic configuration values.
do
  local problems = {}
  local config = vim.diagnostic.config()

  if config.severity_sort ~= true then
    problems[#problems + 1] = "severity_sort off"
  end
  if type(config.underline) ~= "table" or config.underline.severity ~= vim.diagnostic.severity.ERROR then
    problems[#problems + 1] = "underline severity"
  end
  if type(config.virtual_text) ~= "table" or config.virtual_text.spacing ~= 2 then
    problems[#problems + 1] = "virtual_text spacing"
  end
  if vim.g.have_nerd_font and (type(config.signs) ~= "table" or config.signs.text == nil) then
    problems[#problems + 1] = "signs missing"
  end

  add("M10", #problems == 0, join(problems, "severity_sort, underline, virtual_text, signs"))
end

debug("M11 start")
-- M11: Telescope loads and exposes the expected pickers and keymaps.
do
  local problems = {}
  local ok, builtin = pcall(require, "telescope.builtin")

  if not ok then
    problems[#problems + 1] = "telescope.builtin missing"
  else
    for _, name in ipairs({ "find_files", "live_grep", "diagnostics" }) do
      if type(builtin[name]) ~= "function" then
        problems[#problems + 1] = name .. " missing"
      end
    end
  end

  if vim.fn.exists(":Telescope") ~= 2 then
    problems[#problems + 1] = ":Telescope command missing"
  end

  for lhs, expected in pairs({
    ["<leader>ff"] = "[F]ind [F]iles",
    ["<leader>dl"] = "[D]iagnostics [L]ist",
  }) do
    if desc(lhs) ~= expected then
      problems[#problems + 1] = lhs .. " mapping"
    end
  end

  add("M11", #problems == 0, join(problems, "telescope modules, command, keymaps"))
end

debug("M12 start")
-- M12: Treesitter parsers and highlight queries for Lua and TypeScript.
do
  local problems = {}

  for _, item in ipairs({
    { file = "smoke.lua", lang = "lua" },
    { file = "smoke.ts", lang = "typescript" },
  }) do
    local bufnr = open(proj .. "/" .. item.file, nil)
    local parser_ok, parser = pcall(vim.treesitter.get_parser, bufnr, item.lang)

    if not parser_ok or parser == nil then
      problems[#problems + 1] = item.lang .. ": no parser"
    else
      local tree_ok, trees = pcall(parser.parse, parser)

      if not tree_ok or trees == nil or #trees == 0 then
        problems[#problems + 1] = item.lang .. ": parse failed"
      end
    end

    local query_ok, query = pcall(vim.treesitter.query.get, item.lang, "highlights")

    if not query_ok or query == nil then
      problems[#problems + 1] = item.lang .. ": no highlights query"
    end
  end

  add("M12", #problems == 0, join(problems, "lua + typescript parsers and queries"))
end

debug("M13 start")
-- M13: colorscheme and the remaining plugins load and initialise.
do
  local problems = {}

  if not string.find(vim.g.colors_name or "", "tokyonight", 1, true) then
    problems[#problems + 1] = "colorscheme=" .. tostring(vim.g.colors_name)
  end

  if desc("<leader>u") ~= "Toggle [U]ndotree" then
    problems[#problems + 1] = "undotree mapping"
  end
  if vim.fn.exists(":UndotreeToggle") ~= 2 then
    problems[#problems + 1] = ":UndotreeToggle missing"
  else
    pcall(vim.cmd, "UndotreeToggle")

    local opened = false
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[bufnr].filetype == "undotree" then
        opened = true
        break
      end
    end

    if not opened then
      problems[#problems + 1] = "undotree did not open"
    else
      pcall(vim.cmd, "UndotreeHide")
    end
  end

  for _, module in ipairs({ "mini.ai", "mini.surround", "mini.statusline", "ibl", "ibl.config" }) do
    local ok = pcall(require, module)

    if not ok then
      problems[#problems + 1] = module .. " missing"
    end
  end

  add("M13", #problems == 0, join(problems, "tokyonight, undotree, mini, ibl"))
end

vim.fn.writefile({ vim.json.encode({ checks = results }) }, out)
vim.cmd("qa!")
