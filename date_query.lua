local M = {}

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

local function trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

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

local function valid_date(year, month, day)
  local epoch = midnight_epoch(year, month, day)
  local normalized = os.date("*t", epoch)
  return normalized.year == year and normalized.month == month and normalized.day == day
end

local function offset_label(offset)
  if offset == 0 then return "today" end
  if offset == 1 then return "tomorrow" end
  return "in " .. offset .. " days"
end

local function weekday_token(arg)
  local token = arg:lower():match("^([a-z][a-z][a-z])%w*%.?.*$")
  return token
end

local function date_result(day, month, year, ctx)
  if not valid_date(year, month, day) then
    return nil
  end
  local target_epoch = midnight_epoch(year, month, day)
  local offset = math.floor((target_epoch - ctx.today_epoch) / 86400)
  if offset < 0 then
    return nil
  end
  return {
    offset = offset,
    label = string.format("on %02d.%02d.%04d", day, month, year),
    explicit_date = true,
  }
end

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

local function parse_empty(arg)
  if arg == "" then
    return { offset = 0, label = "today" }
  end
  return nil
end

local function parse_alias(arg)
  local offset = aliases[arg]
  if offset == nil then
    return nil
  end
  return { offset = offset, label = offset_label(offset) }
end

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

local function parse_offset(arg)
  local offset = tonumber(arg)
  if not offset or offset < 0 or offset ~= math.floor(offset) then
    return nil
  end
  return { offset = offset, label = offset_label(offset) }
end

local function parse_full_date(arg, ctx)
  local day, month, year = arg:match("^(%d%d?)%.(%d%d?)%.(%d%d%d%d)$")
  if not day then
    return nil
  end
  return date_result(tonumber(day), tonumber(month), tonumber(year), ctx)
end

local function parse_day_month(arg, ctx)
  local day, month = arg:match("^(%d%d?)%.(%d%d?)$")
  if not day then
    return nil
  end
  day = tonumber(day)
  month = tonumber(month)
  local year = nearest_year_for(day, month, ctx)
  if not year then
    return nil
  end
  return date_result(day, month, year, ctx)
end

local parsers = {
  parse_empty,
  parse_alias,
  parse_weekday,
  parse_offset,
  parse_full_date,
  parse_day_month,
}

local function finalize(arg, parsed, ctx)
  local offset = parsed.offset
  if offset == nil or offset < 0 then
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
