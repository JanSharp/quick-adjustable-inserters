
local data_core = require("__quick-adjustable-inserters__.data_core")

---@class QAIDataAPI
local data_api = {
  include = data_core.include,
  exclude = data_core.exclude,
  is_ignored = data_core.is_ignored,
  to_plain_pattern = data_core.to_plain_pattern,
}
return data_api
