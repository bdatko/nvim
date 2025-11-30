require("editorconfig").properties.sql_dialect = function(bufnr, val, opts)
  vim.b[bufnr].sql_dialect = val
end

local function setup_sql_formatter()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.b[bufnr].sql_dialect == nil then
    return "sql-formatter"
  end
  local valid_dialects = { "bigquery", "db2", "db2i", "hive", "mariadb", "mysql", "n1ql", "plsql", "postgresql",
    "redshift", "singlestoredb", "snowflake", "spark", "sql", "sqlite", "tidb", "transactsql", "trino", "tsql" }
  local sql_dialect = vim.b[bufnr].sql_dialect
  local found = false
  for _, value in ipairs(valid_dialects) do
    if sql_dialect == value then
      found = true
      break
    end
  end
  if not found then
    error("invalid choice: " .. sql_dialect .. " for -l option of 'sql-formatter'", 1)
  end
  return "sql-formatter\\ -l\\ " .. sql_dialect
end

vim.bo.formatprg = setup_sql_formatter()
