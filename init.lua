---@diagnostic disable: undefined-global

local SNAPSHOT_DAYS = 31
local SNAPSHOT_KEY = "events:snapshot"

local function trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function ensure_app()
  local app = runx.plugin_dir .. "/CalEvents.app"
  local binary = app .. "/Contents/MacOS/cal-events"
  local source = runx.plugin_dir .. "/cal-events.swift"
  local exists = pcall(runx.exec_status, "test", { "-x", binary })
  local stale = pcall(runx.exec_status, "test", { source, "-nt", binary })
  if not exists or stale then
    runx.exec_status("bash", { runx.plugin_dir .. "/build-app.sh" })
  end
  return app
end

local day_aliases = {
  tomorrow = 1,
  tmr = 1,
  today = 0,
}

local function run_cal_binary(app)
  local binary = app .. "/Contents/MacOS/cal-events"
  return runx.exec_json(binary, { "--days", tostring(SNAPSHOT_DAYS) })
end

local function run_cal_app(app)
  local tmp = os.tmpname()
  local open_args = { "-W", "-g", app, "--args", "--output", tmp, "--days", tostring(SNAPSHOT_DAYS) }
  runx.exec_status("open", open_args)
  local f = io.open(tmp, "r")
  if not f then return { error = "no_output" } end
  local json_str = f:read("*a")
  f:close()
  os.remove(tmp)
  return runx.json_decode(json_str)
end

local function load_snapshot()
  local cached = runx.session_get(SNAPSHOT_KEY)
  if type(cached) == "table" then
    return cached
  end

  local app = ensure_app()

  -- Fast path: run binary directly (works if TCC already granted)
  local ok, result = pcall(run_cal_binary, app)
  if ok and type(result) == "table" and result.error == "denied" then
    -- Slow path: launch as app so macOS can show TCC prompt
    result = run_cal_app(app)
  elseif not ok then
    result = run_cal_app(app)
  end

  if type(result) == "table" and result.error == nil then
    runx.session_set(SNAPSHOT_KEY, result)
  end

  return result
end

local function query_day_offset(raw)
  local arg = trim(raw)
  if arg == "" then return 0 end
  if day_aliases[arg] ~= nil then return day_aliases[arg] end
  local offset = tonumber(arg)
  if offset and offset >= 0 and offset == math.floor(offset) then
    return offset
  end
  return 0
end

local function day_bounds(offset)
  local today = {
    year = tonumber(os.date("%Y")),
    month = tonumber(os.date("%m")),
    day = tonumber(os.date("%d")),
  }
  local start_epoch = os.time({
    year = today.year,
    month = today.month,
    day = today.day + offset,
    hour = 0,
    min = 0,
    sec = 0,
  })
  if offset == 0 then
    start_epoch = os.time()
  end
  local end_epoch = os.time({
    year = today.year,
    month = today.month,
    day = today.day + offset + 1,
    hour = 0,
    min = 0,
    sec = 0,
  })
  return start_epoch, end_epoch
end

local function events_for_day(events, offset)
  local start_epoch, end_epoch = day_bounds(offset)
  local filtered = {}
  for _, ev in ipairs(events) do
    local ev_start = tonumber(ev.start_epoch or ev.epoch)
    local ev_end = tonumber(ev.end_epoch) or ev_start
    if ev_start and ev_end and ev_start < end_epoch and ev_end >= start_epoch then
      filtered[#filtered + 1] = ev
    end
  end
  return filtered
end

local function empty_label(offset)
  if offset == 0 then return "today" end
  if offset == 1 then return "tomorrow" end
  return "in " .. offset .. " days"
end

local function item_for_event(ev, index)
  local time_range = ev.start .. "\u{2013}" .. ev["end"]
  local subtitle = ev.calendar
  if ev.location ~= "" then
    subtitle = subtitle .. " \u{00b7} " .. ev.location
  end
  return {
    title = time_range .. "  " .. ev.title,
    subtitle = subtitle,
    score = 1000 - index,
    badge = "CAL",
    payload = { kind = "open_event", epoch = ev.epoch },
  }
end

local function search_cal(raw)
  local day_offset = query_day_offset(raw)
  local result = load_snapshot()

  if result.error == "denied" then
    return {{
      title = "Calendar access denied",
      subtitle = "Press Enter to open Privacy settings",
      score = 100,
      badge = "CAL",
      payload = { kind = "open_privacy" },
    }}
  end

  if day_offset >= SNAPSHOT_DAYS then
    return {{
      title = "Calendar range not cached",
      subtitle = "This plugin currently caches the next " .. SNAPSHOT_DAYS .. " days",
      score = 100,
      badge = "CAL",
      payload = { kind = "noop" },
    }}
  end

  local events = events_for_day(result, day_offset)
  local items = {}
  for i, ev in ipairs(events) do
    table.insert(items, item_for_event(ev, i))
  end
  if #items == 0 then
    table.insert(items, {
      title = "No upcoming events " .. empty_label(day_offset),
      subtitle = "Calendar is clear",
      score = 100,
      badge = "CAL",
      payload = { kind = "noop" },
    })
  end
  return items
end

local function run(payload)
  if payload.kind == "open_privacy" then
    runx.exec_status("open", {
      "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars",
    })
  elseif payload.kind == "open_event" then
    local app = ensure_app()
    runx.exec_status("open", { "-g", "-W", app, "--args", "--open", payload.epoch })
  end
end

return {
  metadata = {
    id = "cal",
    name = "Calendar",
    badge = "CAL",
  },
  commands = {
    cal = "search_cal",
  },
  search_cal = search_cal,
  run = run,
}
