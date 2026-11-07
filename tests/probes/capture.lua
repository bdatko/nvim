-- Installed with --cmd before init.lua so it observes startup warnings.
-- State lives in a Lua global: vim.g returns a table copy, so inserts there
-- are silently lost.
_G.__test_capture = { notifications = {}, deprecations = {} }

local cap = _G.__test_capture

local orig_notify = vim.notify
vim.notify = function(msg, level, opts)
  table.insert(cap.notifications, {
    msg = tostring(msg),
    level = level or vim.log.levels.INFO,
  })
  return orig_notify(msg, level, opts)
end

local orig_deprecate = vim.deprecate
vim.deprecate = function(name, alternative, version, plugin, backtrace)
  table.insert(cap.deprecations, {
    name = tostring(name),
    alternative = tostring(alternative),
    version = tostring(version),
    plugin = tostring(plugin),
  })
  return orig_deprecate(name, alternative, version, plugin, backtrace)
end
