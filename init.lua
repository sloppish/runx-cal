---@diagnostic disable: undefined-global

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
  tomorrow = "1",
  tmr = "1",
  today = "0",
}

local function run_cal_binary(app, day_offset)
  local binary = app .. "/Contents/MacOS/cal-events"
  local args = {}
  if day_offset ~= "0" then args = { day_offset } end
  return runx.exec_json(binary, args)
end

local function run_cal_app(app, day_offset)
  local tmp = os.tmpname()
  local open_args = { "-W", "-g", app, "--args", "--output", tmp }
  if day_offset ~= "0" then
    table.insert(open_args, day_offset)
  end
  runx.exec_status("open", open_args)
  local f = io.open(tmp, "r")
  if not f then return { error = "no_output" } end
  local json_str = f:read("*a")
  f:close()
  os.remove(tmp)
  return runx.json_decode(json_str)
end

local function search_cal(raw)
  local arg = raw:match("^%s*(.-)%s*$")
  local day_offset = day_aliases[arg] or arg
  if day_offset == "" then day_offset = "0" end

  local app = ensure_app()

  -- Fast path: run binary directly (works if TCC already granted)
  local ok, result = pcall(run_cal_binary, app, day_offset)
  if ok and type(result) == "table" and result.error == "denied" then
    -- Slow path: launch as app so macOS can show TCC prompt
    result = run_cal_app(app, day_offset)
  elseif not ok then
    result = run_cal_app(app, day_offset)
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

  local events = result
  local label = ""
  if day_offset == "1" then label = "tomorrow" end

  local items = {}
  for _, ev in ipairs(events) do
    local time_range = ev.start .. "\u{2013}" .. ev["end"]
    local subtitle = ev.calendar
    if ev.location ~= "" then
      subtitle = subtitle .. " \u{00b7} " .. ev.location
    end
    table.insert(items, {
      title = time_range .. "  " .. ev.title,
      subtitle = subtitle,
      score = 100,
      badge = "CAL",
      payload = { kind = "open_event", epoch = ev.epoch },
    })
  end
  if #items == 0 then
    local msg = "No upcoming events" .. (label ~= "" and " " .. label or " today")
    table.insert(items, {
      title = msg,
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
