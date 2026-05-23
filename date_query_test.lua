package.path = "./?.lua;" .. package.path

local date_query = require("date_query")

local function epoch(year, month, day)
  return os.time({
    year = year,
    month = month,
    day = day,
    hour = 0,
    min = 0,
    sec = 0,
  })
end

local now = os.time({
  year = 2026,
  month = 5,
  day = 16,
  hour = 15,
  min = 0,
  sec = 0,
})

local function offset_to(year, month, day)
  return math.floor((epoch(year, month, day) - epoch(2026, 5, 16)) / 86400)
end

local cases = {
  { "", 0, "today", "16.05.2026", "Today" },
  { "today", 0, "today", "16.05.2026", "Today" },
  { "tomorrow", 1, "tomorrow", "17.05.2026", "Tomorrow" },
  { "tmr", 1, "tomorrow", "17.05.2026", "Tomorrow" },
  { "1", 1, "tomorrow", "17.05.2026", "Tomorrow" },
  { "15", 15, "in 15 days", "31.05.2026", nil },
  { "01.01", offset_to(2027, 1, 1), "on 01.01.2027", "01.01.2027", nil },
  { "1.1", offset_to(2027, 1, 1), "on 01.01.2027", "01.01.2027", nil },
  { "01.01.2027", offset_to(2027, 1, 1), "on 01.01.2027", "01.01.2027", nil },
  { "16.05", 0, "on 16.05.2026", "16.05.2026", "Today" },
  { "17.05", 1, "on 17.05.2026", "17.05.2026", "Tomorrow" },
  { "15.05", offset_to(2027, 5, 15), "on 15.05.2027", "15.05.2027", nil },
  { "29.02", offset_to(2028, 2, 29), "on 29.02.2028", "29.02.2028", nil },
  { "sat", 0, "Saturday", "16.05.2026", "Today" },
  { "sat.", 0, "Saturday", "16.05.2026", "Today" },
  { "sun", 1, "Sunday", "17.05.2026", "Tomorrow" },
  { "mon", 2, "Monday", "18.05.2026", "Monday" },
  { "mon.", 2, "Monday", "18.05.2026", "Monday" },
  { "monday", 2, "Monday", "18.05.2026", "Monday" },
  { "tue", 3, "Tuesday", "19.05.2026", "Tuesday" },
  { "tues.", 3, "Tuesday", "19.05.2026", "Tuesday" },
  { "wed.foo", 4, "Wednesday", "20.05.2026", "Wednesday" },
  { "thu", 5, "Thursday", "21.05.2026", "Thursday" },
  { "fri", 6, "Friday", "22.05.2026", "Friday" },
}

for _, case in ipairs(cases) do
  local parsed = date_query.parse(case[1], now)
  assert(parsed.offset == case[2], case[1] .. " offset=" .. parsed.offset)
  assert(parsed.label == case[3], case[1] .. " label=" .. parsed.label)
  assert(parsed.display_date == case[4], case[1] .. " date=" .. parsed.display_date)
  assert(parsed.display_label == case[5], case[1] .. " display=" .. tostring(parsed.display_label))
end

local invalid = date_query.parse("31.02", now)
assert(invalid.offset == 0 and invalid.label == "today")

-- Negative offsets (past dates)
local neg_cases = {
  { "-1", -1, "yesterday", "15.05.2026", nil },
  { "-3", -3, "3 days ago", "13.05.2026", nil },
  { "-0", 0, "today", "16.05.2026", "Today" },
  { "01.01.2026", offset_to(2026, 1, 1), "on 01.01.2026", "01.01.2026", nil },
  { "15.05.2026", -1, "on 15.05.2026", "15.05.2026", nil },
}

for _, case in ipairs(neg_cases) do
  local parsed = date_query.parse(case[1], now)
  assert(parsed.offset == case[2], case[1] .. " offset=" .. parsed.offset)
  assert(parsed.label == case[3], case[1] .. " label=" .. parsed.label)
  assert(parsed.display_date == case[4], case[1] .. " date=" .. parsed.display_date)
  assert(parsed.display_label == case[5], case[1] .. " display=" .. tostring(parsed.display_label))
end

print("date_query ok")
