local function get_events()
  local script = [[
    const app = Application("Calendar");
    const now = new Date();
    const endOfDay = new Date(now);
    endOfDay.setHours(23, 59, 59, 999);

    const results = [];
    for (const cal of app.calendars()) {
      const events = cal.events.whose({
        _and: [
          { startDate: { _greaterThan: now } },
          { startDate: { _lessThan: endOfDay } }
        ]
      })();
      for (const ev of events) {
        results.push({
          title: ev.summary(),
          start: ev.startDate().toISOString(),
          endDate: ev.endDate().toISOString(),
          location: ev.location() || "",
          calendar: cal.name(),
        });
      }
    }
    results.sort((a, b) => a.start.localeCompare(b.start));
    JSON.stringify(results);
  ]]

  local ok, output = pcall(runx.exec_capture, "osascript", { "-l", "JavaScript", "-e", script })
  if not ok or output == "" then
    return {}
  end
  local ok2, events = pcall(runx.json_decode, output)
  if not ok2 then
    return {}
  end
  return events
end

local function format_time(iso)
  local hour, min = iso:match("T(%d%d):(%d%d)")
  if not hour then return "" end
  return hour .. ":" .. min
end

local function search_cal(raw, argv)
  local events = get_events()
  local items = {}
  for _, ev in ipairs(events) do
    local time_range = format_time(ev.start) .. "–" .. format_time(ev.endDate)
    local subtitle = ev.calendar
    if ev.location ~= "" then
      subtitle = subtitle .. " · " .. ev.location
    end
    table.insert(items, {
      title = time_range .. "  " .. ev.title,
      subtitle = subtitle,
      score = 100,
      badge = "CAL",
      payload = { kind = "noop" },
    })
  end
  if #items == 0 then
    table.insert(items, {
      title = "No upcoming events today",
      subtitle = "Calendar is clear",
      score = 100,
      badge = "CAL",
      payload = { kind = "noop" },
    })
  end
  return items
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
}
