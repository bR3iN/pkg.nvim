local _local_1_ = require("pkg.utils")
local scan_dir = _local_1_["scan-dir"]
local spawn_21 = _local_1_["spawn!"]
local nmap_21 = _local_1_["nmap!"]
local empty_3f = _local_1_["empty?"]
local dir_exists_3f = _local_1_["dir-exists?"]
local starts_with_3f = _local_1_["starts-with?"]
local git_repo_3f = _local_1_["git-repo?"]
local all = _local_1_["all"]
local any = _local_1_["any"]
local contains_3f = _local_1_["contains?"]
local table_3f = _local_1_["table?"]
local _local_2_ = vim
local keys = _local_2_["tbl_keys"]
local vals = _local_2_["tbl_values"]
local map = _local_2_["tbl_map"]
local filter = _local_2_["tbl_filter"]
local sort_21 = table.sort
local pkg_dir = (vim.env.HOME .. "/.local/share/nvim/site/pack/pkgs/start")
local pending_cbs = {}
local pkg_states = {}
local pkg_state = {downloading = 0, downloaded = 1}
local function url_3f(str)
  local function _3_(_241)
    return starts_with_3f(_241, str)
  end
  local function _4_(_241)
    return (_241 .. "://")
  end
  return any(map(_3_, map(_4_, {"https", "http", "ssh", "file"})))
end
local function rm_scheme(url)
  local _, _end = string.find(url, "://")
  return string.sub(url, (_end + 1))
end
local function pkg_name__3edir_name(pkg_name)
  local pkg_name0
  if url_3f(pkg_name) then
    pkg_name0 = rm_scheme(pkg_name)
  else
    pkg_name0 = pkg_name
  end
  local _6_, _7_ = string.gsub(string.gsub(pkg_name0, "/", "_"), "%.", "_")
  if ((nil ~= _6_) and true) then
    local dir_name = _6_
    local _ = _7_
    return dir_name
  else
    return nil
  end
end
local function pkg_name__3eurl(pkg_name)
  if url_3f(pkg_name) then
    return pkg_name
  else
    return ("https://github.com/" .. pkg_name)
  end
end
local function dir__3epath(dir_name)
  return (pkg_dir .. "/" .. dir_name)
end
local function pkg_name__3epath(pkg_name)
  return dir__3epath(pkg_name__3edir_name(pkg_name))
end
local function get_ready_cbs()
  local everything_downloaded
  local function _10_(_241)
    return (_241 == pkg_state.downloaded)
  end
  everything_downloaded = all(map(_10_, vals(pkg_states)))
  if everything_downloaded then
    vim.cmd.packloadall({bang = true})
    local function _11_(_241)
      return _241()
    end
    return map(_11_, keys(pending_cbs))
  else
    return nil
  end
end
local function dispatch_ready_cbs_21()
  for _, cb in ipairs(get_ready_cbs()) do
    pending_cbs[cb] = nil
    cb()
  end
  return nil
end
local function rm_cbs_waiting_on_21(pkg_name)
  local orphaned_cbs
  do
    local tbl_17_auto = {}
    local i_18_auto = #tbl_17_auto
    for cb, pkgs_waiting in pairs(pending_cbs) do
      local val_19_auto
      if contains_3f(pkg_name, pkgs_waiting) then
        val_19_auto = cb
      else
        val_19_auto = nil
      end
      if (nil ~= val_19_auto) then
        i_18_auto = (i_18_auto + 1)
        do end (tbl_17_auto)[i_18_auto] = val_19_auto
      else
      end
    end
    orphaned_cbs = tbl_17_auto
  end
  for _, cb in ipairs(orphaned_cbs) do
    pending_cbs[cb] = nil
  end
  return nil
end
local function rm_and_report_21(path)
  local function _15_(code)
    if (code == 0) then
      return print("Removed", path)
    else
      return print("Failed to remove", path)
    end
  end
  return spawn_21("rm", {args = {"-r", path}}, _15_)
end
local function gen_helptags_21(path)
  local doc_path = (path .. "/doc")
  if dir_exists_3f(doc_path) then
    return vim.cmd.helptags({args = {doc_path}})
  else
    return nil
  end
end
local function fetch_pkg_21(pkg_name, path)
  local url = pkg_name__3eurl(pkg_name)
  local function _18_(code)
    if (code == 0) then
      print(("Installed " .. pkg_name))
      do end (pkg_states)[pkg_name] = pkg_state.downloaded
      gen_helptags_21(path)
      return dispatch_ready_cbs_21()
    else
      print(("Failed to install " .. pkg_name))
      do end (pkg_states)[pkg_name] = nil
      return rm_cbs_waiting_on_21(pkg_name)
    end
  end
  return spawn_21("git", {args = {"clone", url, path}, env = {"GIT_TERMINAL_PROMPT=0"}}, _18_)
end
local function add_21(pkg_names, _3fsetup)
  local pkg_names0
  if table_3f(pkg_names) then
    pkg_names0 = pkg_names
  else
    pkg_names0 = {pkg_names}
  end
  local setup
  local function _21_()
  end
  setup = (_3fsetup or _21_)
  local blocked = false
  for _, pkg_name in ipairs(pkg_names0) do
    local _22_ = pkg_states[pkg_name]
    if (_22_ == pkg_state.downloaded) then
    elseif (_22_ == pkg_state.downloading) then
      blocked = true
    elseif (_22_ == nil) then
      local path = pkg_name__3epath(pkg_name)
      if dir_exists_3f(path) then
        pkg_states[pkg_name] = pkg_state.downloaded
      else
        blocked = true
        pkg_states[pkg_name] = pkg_state.downloading
        fetch_pkg_21(pkg_name, path)
      end
    else
    end
  end
  if blocked then
    pending_cbs[setup] = pkg_names0
    return nil
  else
    return setup()
  end
end
local function clean_21()
  local valid_dir_names = map(pkg_name__3edir_name, keys(pkg_states))
  local rm_3f
  local function _26_(_241)
    return not contains_3f(_241, valid_dir_names)
  end
  rm_3f = _26_
  local function _27_(filename, filetype)
    if ((filetype == "directory") and rm_3f(filename)) then
      return rm_and_report_21((pkg_dir .. "/" .. filename))
    else
      return nil
    end
  end
  return scan_dir(pkg_dir, _27_)
end
local function list_21()
  local pkg_names = keys(pkg_states)
  local sep = "\n  "
  sort_21(pkg_names)
  print(("Installed plugins:" .. sep .. table.concat(pkg_names, sep)))
  return vim.cmd("messages")
end
local function update_21()
  local function _29_(fname, ftype)
    local path = (pkg_dir .. "/" .. fname)
    if ((ftype == "directory") and git_repo_3f(path)) then
      local function _30_(code)
        if (code == 0) then
          return vim.cmd.packloadall({bang = true})
        else
          return gen_helptags_21(path)
        end
      end
      return spawn_21("git", {args = {"pull"}, cwd = path}, _30_)
    else
      return nil
    end
  end
  return scan_dir(pkg_dir, _29_)
end
local function checkout(pkg_name, branch_or_tag)
  local path = pkg_name__3epath(pkg_name)
  local function _33_(code)
    if (code == 0) then
      return print("Successfully checked out", branch_or_tag)
    else
      return print("Failed to check out", branch_or_tag)
    end
  end
  return spawn_21("git", {args = {"checkout", branch_or_tag}, cwd = path}, _33_)
end
local function init_21()
  pkg_states = {}
  pending_cbs = {}
  return vim.fn.mkdir(pkg_dir, "p")
end
local function _35_()
  return update_21()
end
nmap_21("<Plug>PkgUpdate", _35_)
local function _36_()
  return list_21()
end
nmap_21("<Plug>PkgList", _36_)
return {["add!"] = add_21, init = init_21, clean = clean_21, checkout = checkout}
