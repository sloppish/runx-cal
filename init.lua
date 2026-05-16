---@diagnostic disable: undefined-global

local date_query = require("date_query")

local SNAPSHOT_DAYS = 31
local SNAPSHOT_KEY = "events:snapshot"

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

local function run_cal_binary(app, args)
  local binary = app .. "/Contents/MacOS/cal-events"
  return runx.exec_json(binary, args)
end

local function run_cal_app(app, args)
  local tmp = os.tmpname()
  local open_args = { "-W", "-g", app, "--args", "--output", tmp }
  for _, arg in ipairs(args) do
    table.insert(open_args, arg)
  end
  runx.exec_status("open", open_args)
  local f = io.open(tmp, "r")
  if not f then return { error = "no_output" } end
  local json_str = f:read("*a")
  f:close()
  os.remove(tmp)
  return runx.json_decode(json_str)
end

local function fetch_events(args)
  local app = ensure_app()

  -- Fast path: run binary directly (works if TCC already granted)
  local ok, result = pcall(run_cal_binary, app, args)
  if ok and type(result) == "table" and result.error == "denied" then
    -- Slow path: launch as app so macOS can show TCC prompt
    result = run_cal_app(app, args)
  elseif not ok then
    result = run_cal_app(app, args)
  end

  return result
end

local function load_snapshot()
  local cached = runx.session_get(SNAPSHOT_KEY)
  if type(cached) == "table" then
    return cached
  end

  local result = fetch_events({ "--days", tostring(SNAPSHOT_DAYS) })

  if type(result) == "table" and result.error == nil then
    runx.session_set(SNAPSHOT_KEY, result)
  end

  return result
end

local function load_day(day_offset)
  return fetch_events({ tostring(day_offset) })
end

local function events_for_day(events, query)
  local filtered = {}
  for _, ev in ipairs(events) do
    local ev_start = tonumber(ev.start_epoch or ev.epoch)
    local ev_end = tonumber(ev.end_epoch) or ev_start
    if ev_start and ev_end and ev_start < query.end_epoch and ev_end > query.start_epoch then
      filtered[#filtered + 1] = ev
    end
  end
  return filtered
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
  local query = date_query.parse(raw)
  local result = nil

  if query.offset >= SNAPSHOT_DAYS then
    result = load_day(query.offset)
  else
    result = load_snapshot()
  end

  if result.error == "denied" then
    return {{
      title = "Calendar access denied",
      subtitle = "Press Enter to open Privacy settings",
      score = 100,
      badge = "CAL",
      payload = { kind = "open_privacy" },
    }}
  end

  local events = query.offset >= SNAPSHOT_DAYS and result or events_for_day(result, query)
  local items = {}
  for i, ev in ipairs(events) do
    table.insert(items, item_for_event(ev, i))
  end
  if #items == 0 then
    table.insert(items, {
      title = "No upcoming events " .. query.label,
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
