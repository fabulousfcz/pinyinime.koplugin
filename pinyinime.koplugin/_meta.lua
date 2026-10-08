local _ = require("gettext")
local source = debug.getinfo(1, "S").source:gsub("^@", "")
local root = source:match("^(.*)/_meta%.lua$") or "plugins/pinyinime.koplugin"
local PluginVersion = dofile(root .. "/lib/plugin_version.lua")

return {
    name = "pinyinime",
    fullname = _("拼音输入法"),
    description = _("本地拼音与英文补全输入法，支持行内预编辑、双拼和适合电子墨水屏的候选栏。"),
    version = PluginVersion,
}
