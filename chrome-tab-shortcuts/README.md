# Vertical Tab Keyboard Navigation

Chrome extension plus Hammerspoon bridge providing vertical tab-navigation
shortcuts:

| Shortcut | Action |
| --- | --- |
| `Cmd+Option+Up` | Activate the previous tab |
| `Cmd+Option+Down` | Activate the next tab |
| `Cmd+Option+Shift+Up` | Select the previous tab and retain traversed tabs |
| `Cmd+Option+Shift+Down` | Select the next tab and retain traversed tabs |

## Install

1. Open `chrome://extensions` in Chrome.
2. Enable **Developer mode**.
3. Click **Load unpacked**.
4. Select this `chrome-tab-shortcuts` directory. If the hidden `.hammerspoon`
   directory is not visible in the file picker, press `Cmd+Shift+G` and paste
   `/Users/sinan/.hammerspoon/chrome-tab-shortcuts`.

Chrome should apply its two private bridge shortcuts automatically. They can be
checked at `chrome://extensions/shortcuts`. Internally, the extension uses
`Option+Shift+PageUp/PageDown`; Hammerspoon translates the requested
`Cmd+Option+Shift+Up/Down` shortcuts to those commands because Chrome rejects
`Command+Option` combinations in extension manifests.
