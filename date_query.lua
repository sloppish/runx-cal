local M = {}

local aliases = {
  tomorrow = 1,
  tmr = 1,
  today = 0,
}

local function trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function today_parts(now)
  return {
    year = tonumber(os.date("%Y", now)),
    month = tonumber(os.date("%m", now)),
    day = tonumber(os.date("%d", now)),
  }
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

local function valid_date(year, month, day)
  local epoch = midnight_epoch(year, month, day)
  local normalized = os.date("*t", epoch)
  return normalized.year == year and normalized.month == month and normalized.day == day
end

function M.parse(raw, now)
  now = now or os.time()
  local arg = trim(raw)

  local offset = nil
  local label = nil
  local explicit_date = false

  if arg == "" then
    offset = 0
    label = "today"
  elseif aliases[arg] ~= nil then
    offset = aliases[arg]
    label = offset == 0 and "today" or "tomorrow"
  else
    local number = tonumber(arg)
    if number and number >= 0 and number == math.floor(number) then
      offset = number
      if offset == 0 then
        label = "today"
      elseif offset == 1 then
        label = "tomorrow"
      else
        label = "in " .. offset .. " days"
      end
    else
      local day, month, year = arg:match("^(%d%d?)%.(%d%d?)%.(%d%d%d%d)$")
      if day then
        day = tonumber(day)
        month = tonumber(month)
        year = tonumber(year)
      else
        day, month = arg:match("^(%d%d?)%.(%d%d?)$")
        day = tonumber(day)
        month = tonumber(month)
        local today = today_parts(now)
        year = today.year
        if day and month then
          local today_epoch = midnight_epoch(today.year, today.month, today.day)
          for candidate_year = today.year, today.year + 8 do
            if valid_date(candidate_year, month, day) then
              local target_epoch = midnight_epoch(candidate_year, month, day)
              if target_epoch >= today_epoch then
                year = candidate_year
                break
              end
            end
          end
        end
      end
      if day and month and year and valid_date(year, month, day) then
        local today = today_parts(now)
        local today_epoch = midnight_epoch(today.year, today.month, today.day)
        local target_epoch = midnight_epoch(year, month, day)
        offset = math.floor((target_epoch - today_epoch) / 86400)
        label = string.format("on %02d.%02d.%04d", day, month, year)
        explicit_date = true
      end
    end
  end

  if not offset or offset < 0 then
    offset = 0
    label = "today"
  end

  local today = today_parts(now)
  local start_epoch = midnight_epoch(today.year, today.month, today.day + offset)
  local end_epoch = midnight_epoch(today.year, today.month, today.day + offset + 1)

  return {
    raw = arg,
    offset = offset,
    label = label,
    explicit_date = explicit_date,
    start_epoch = start_epoch,
    end_epoch = end_epoch,
  }
end

return M
