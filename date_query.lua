---@class DateQuery
local M = {}

---@class dq.DateComponents
---@field year integer
---@field month integer
---@field day integer

---@class dq.Context
---@field now integer
---@field today dq.DateComponents
---@field today_epoch integer
---@field weekday integer 1=Sun, 7=Sat

---@class dq.Parsed
---@field offset integer
---@field label string
---@field display_label? string
---@field explicit_date? boolean

---@class dq.Result
---@field raw string
---@field offset integer
---@field label string
---@field display_date string
---@field display_label? string
---@field explicit_date boolean
---@field start_epoch integer
---@field end_epoch integer

local aliases = {
  tomorrow = 1,
  tmr = 1,
  today = 0,
}

local weekdays = {
  sun = { index = 1, label = "Sunday" },
  mon = { index = 2, label = "Monday" },
  tue = { index = 3, label = "Tuesday" },
  wed = { index = 4, label = "Wednesday" },
  thu = { index = 5, label = "Thursday" },
  fri = { index = 6, label = "Friday" },
  sat = { index = 7, label = "Saturday" },
}

---@param value? string
---@return string
local function trim(value)
  local s = (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

---@param year integer
---@param month integer
---@param day integer
---@return integer
local function midnight_epoch(year, month, day)
  return os.time({
    year = year,
    month = month,
    day = day,
    hour = 0,
    min = 0,
    sec = 0,
  })
end

---@param now? integer
---@return dq.Context
local function build_context(now)
  now = now or os.time()
  local today = {
    year = tonumber(os.date("%Y", now)),
    month = tonumber(os.date("%m", now)),
    day = tonumber(os.date("%d", now)),
  }
  return {
    now = now,
    today = today,
    today_epoch = midnight_epoch(today.year, today.month, today.day),
    weekday = tonumber(os.date("%w", now)) + 1,
  }
end

---@param year integer
---@param month integer
---@param day integer
---@return boolean
local function valid_date(year, month, day)
  local epoch = midnight_epoch(year, month, day)
  local normalized = os.date("*t", epoch)
  return normalized.year == year and normalized.month == month and normalized.day == day
end

---@param offset integer
---@return string
local function offset_label(offset)
  if offset == 0 then return "today" end
  if offset == 1 then return "tomorrow" end
  if offset == -1 then return "yesterday" end
  if offset < 0 then return math.abs(offset) .. " days ago" end
  return "in " .. offset .. " days"
end

---@param arg string
---@return string?
local function weekday_token(arg)
  local token = arg:lower():match("^([a-z][a-z][a-z])%w*%.?.*$")
  return token
end

---@param day integer
---@param month integer
---@param year integer
---@param ctx dq.Context
---@return dq.Parsed?
local function date_result(day, month, year, ctx)
  if not valid_date(year, month, day) then
    return nil
  end
  local target_epoch = midnight_epoch(year, month, day)
  local offset = math.floor((target_epoch - ctx.today_epoch) / 86400)
  return {
    offset = offset,
    label = string.format("on %02d.%02d.%04d", day, month, year),
    explicit_date = true,
  }
end

---@param day integer
---@param month integer
---@param ctx dq.Context
---@return integer?
local function nearest_year_for(day, month, ctx)
  for year = ctx.today.year, ctx.today.year + 8 do
    if valid_date(year, month, day) then
      local target_epoch = midnight_epoch(year, month, day)
      if target_epoch >= ctx.today_epoch then
        return year
      end
    end
  end
  return nil
end

---@param arg string
---@return dq.Parsed?
local function parse_empty(arg)
  if arg == "" then
    return { offset = 0, label = "today" }
  end
  return nil
end

---@param arg string
---@return dq.Parsed?
local function parse_alias(arg)
  local offset = aliases[arg]
  if offset == nil then
    return nil
  end
  return { offset = offset, label = offset_label(offset) }
end

---@param arg string
---@param ctx dq.Context
---@return dq.Parsed?
local function parse_weekday(arg, ctx)
  local weekday = weekdays[weekday_token(arg) or ""]
  if not weekday then
    return nil
  end
  return {
    offset = (weekday.index - ctx.weekday) % 7,
    label = weekday.label,
    display_label = weekday.label,
  }
end

---@param arg string
---@return dq.Parsed?
local function parse_offset(arg)
  local offset = tonumber(arg)
  if not offset or offset ~= math.floor(offset) then
    return nil
  end
  return { offset = offset, label = offset_label(offset) }
end

---@param arg string
---@param ctx dq.Context
---@return dq.Parsed?
local function parse_full_date(arg, ctx)
  local d, m, y = arg:match("^(%d%d?)%.(%d%d?)%.(%d%d%d%d)$")
  if not d then
    return nil
  end
  local day = tonumber(d) --[[@as integer]]
  local month = tonumber(m) --[[@as integer]]
  local year = tonumber(y) --[[@as integer]]
  return date_result(day, month, year, ctx)
end

---@param arg string
---@param ctx dq.Context
---@return dq.Parsed?
local function parse_day_month(arg, ctx)
  local d, m = arg:match("^(%d%d?)%.(%d%d?)$")
  if not d then
    return nil
  end
  local day = tonumber(d) --[[@as integer]]
  local month = tonumber(m) --[[@as integer]]
  local year = nearest_year_for(day, month, ctx)
  if not year then
    return nil
  end
  return date_result(day, month, year, ctx)
end

---@alias dq.Parser fun(arg: string, ctx: dq.Context): dq.Parsed?

---@type dq.Parser[]
local parsers = {
  parse_empty,
  parse_alias,
  parse_weekday,
  parse_offset,
  parse_full_date,
  parse_day_month,
}

---@param arg string
---@param parsed dq.Parsed
---@param ctx dq.Context
---@return dq.Result
local function finalize(arg, parsed, ctx)
  local offset = parsed.offset
  if offset == nil then
    offset = 0
    parsed = { offset = 0, label = "today" }
  end

  local start_epoch = midnight_epoch(ctx.today.year, ctx.today.month, ctx.today.day + offset)
  local end_epoch = midnight_epoch(ctx.today.year, ctx.today.month, ctx.today.day + offset + 1)
  local start = os.date("*t", start_epoch)
  local display_date = string.format("%02d.%02d.%04d", start.day, start.month, start.year)
  local display_label = parsed.display_label
  if offset == 0 then
    display_label = "Today"
  elseif offset == 1 then
    display_label = "Tomorrow"
  end

  return {
    raw = arg,
    offset = offset,
    label = parsed.label,
    display_date = display_date,
    display_label = display_label,
    explicit_date = parsed.explicit_date or false,
    start_epoch = start_epoch,
    end_epoch = end_epoch,
  }
end

---@param raw? string
---@param now? integer
---@return dq.Result
function M.parse(raw, now)
  local arg = trim(raw)
  local ctx = build_context(now)

  for _, parser in ipairs(parsers) do
    local parsed = parser(arg, ctx)
    if parsed then
      return finalize(arg, parsed, ctx)
    end
  end

  return finalize(arg, { offset = 0, label = "today" }, ctx)
end

return M
