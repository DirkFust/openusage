# Menu bar

The strip shows the limits closest to running out, or with Always Show In Menu Bar everything
Priority lists.

- Left-click the icon to open the panel. Right-click (or control-click) it for **Settings** and
  **Quit OpenUsage**.
- The strip shows the limits [running out](dashboard.md#priority), most urgent first, pinned or not,
  up to **Settings → Display → Menu Bar Icons → Max Items In Menu Bar** (3 by default).
- With **Always Show In Menu Bar** on (off by default), it lists everything Priority does, in its
  order: Pinned, Running Out, Use It or Lose It, then Used Up. A pinned limit shows once, where
  Priority lists it.
- Each limit shows the provider's mark, a short name, and its value. An account can appear more than once.
- Beside the value, a limit with a reset shows the time until it, in one unit: `22m`, `2h`, `3d`. Under
  it, a small bar fills the way the limit's row does, with a tick where an even pace through the window
  would be by now. The bar follows the same rules as the row's [pace mark](dashboard.md), so it hides
  with **Pace Marks** off, once the limit is used up, or early in its window.
- The value turns orange or red when what's left drops to the Warning or Critical level. The bar turns
  orange when the limit would land close to its limit at the reset, and red when it would run out
  before it. Everything else keeps the menu bar's own color.
- Limits past that number show as a count, like `+7`. Used Up limits never count. With Always Show
  In Menu Bar off, only limits running out show or count.
- With nothing to show, or with **App Icon Only**, the strip shows the app icon.
- With [Privacy Mode](privacy.md#privacy-mode) on, it shows the app icon while your screen
  is shared or recorded.
- When an [update](updates.md) is available, the app icon shows at the end of the strip until the
  update banner goes away.
- When a provider has more than one account, its mark carries the account name's initials: "Personal"
  reads P and "Attention Machine 1" reads A1. Rename one of two accounts with the same initials to tell
  them apart. A provider with [Unify Multiple Accounts](dashboard.md#unify-multiple-accounts) on shows
  each limit once, with no initials.
