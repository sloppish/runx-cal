# runx-cal

A [Runx](https://github.com/sloppish/runx) plugin that puts your macOS Calendar events right in the launcher.

Type `cal` and see what's coming up.

## Usage

Open runx and type:

```
cal             → today's events
cal tomorrow    → tomorrow (also: tmr)
cal mon         → next Monday (mon/tue/wed/thu/fri/sat/sun)
cal 3           → 3 days from now
cal -2          → 2 days ago
cal 25.12       → December 25
cal 01.03.2026  → specific date (dd.mm.yyyy)
```

Select an event to open it in Calendar app.

## Aliases

You can define aliases for commands in your Runx plugin config, for example:

```toml
[plugin.cal.aliases]
cal = "c"
```

This lets you type `c tomorrow` instead of `cal tomorrow`.

## Permissions

macOS will prompt you to grant calendar access to "Runx Calendar Plugin Helper" on the first invocation or after updating.
Pick "Full Calendar Access" for it to work.
