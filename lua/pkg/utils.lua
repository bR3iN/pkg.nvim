local uv = vim.loop
local M = {}
M["dir-exists?"] = function(path)
  return (vim.fn.isdirectory(path) ~= 0)
end
M["git-repo?"] = function(path)
  return M["dir-exists?"]((path .. "/.git"))
end
M.all = function(bools)
  local res = true
  for _, bool in ipairs(bools) do
    if not res then break end
    res = bool
  end
  return res
end
M.any = function(bools)
  local res = false
  for _, bool in ipairs(bools) do
    if res then break end
    res = bool
  end
  return res
end
M["contains?"] = function(target, vals)
  return vim.tbl_contains(vals, target)
end
M["empty?"] = function(tbl)
  return (0 == #tbl)
end
M["table?"] = function(val)
  return (type(val) == "table")
end
M["nmap!"] = function(keys, cb)
  return vim.keymap.set("n", keys, cb, {noremap = true, silent = true})
end
M["starts-with?"] = function(prefix, str)
  return (string.sub(str, 1, #prefix) == prefix)
end
local function parse_cmd(_1_)
  local _arg_2_ = _1_
  local file = _arg_2_[1]
  local args = (function (t, k, e) local mt = getmetatable(t) if 'table' == type(mt) and mt.__fennelrest then return mt.__fennelrest(t, k) elseif e then local rest = {} for k, v in pairs(t) do if not e[k] then rest[k] = v end end return rest else return {(table.unpack or unpack)(t, k)} end end)(_arg_2_, 2)
  return file, args
end
M.spawn = function(cmd, cb, _3fopts)
  local file, args = parse_cmd(cmd)
  local opts
  do
    local _3_ = (_3fopts or {})
    do end (_3_)["args"] = args
    opts = _3_
  end
  return uv.spawn(file, opts, vim.schedule_wrap(cb))
end
M["scan-dir"] = function(path, cb)
  local wrapped_cb
  local function _4_(entry)
    return cb(entry.name, entry.type)
  end
  wrapped_cb = vim.schedule_wrap(_4_)
  local function _5_(err_3_auto, dir)
    assert(not err_4_auto, err_4_auto)
    local function iter()
      local function _6_(err_3_auto0, entries)
        assert(not err_4_auto, err_4_auto)
        if entries then
          vim.tbl_map(wrapped_cb, entries)
          return iter()
        else
          return dir:closedir()
        end
      end
      return dir:readdir(_6_)
    end
    return iter()
  end
  return uv.fs_opendir(path, _5_)
end
return M
