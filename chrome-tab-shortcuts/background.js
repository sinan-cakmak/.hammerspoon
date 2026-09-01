async function travelTabs(delta, extendSelection) {
  const tabs = (await chrome.tabs.query({currentWindow: true}))
    .filter((tab) => Number.isInteger(tab.index))
    .sort((a, b) => a.index - b.index);

  if (tabs.length < 2) return;

  const activeOffset = tabs.findIndex((tab) => tab.active);
  if (activeOffset === -1) return;

  const targetOffset = (activeOffset + delta + tabs.length) % tabs.length;
  const target = tabs[targetOffset];

  if (!extendSelection) {
    // Passing one index also clears any previous multi-tab selection.
    await chrome.tabs.highlight({
      windowId: target.windowId,
      tabs: target.index,
    });
    return;
  }

  // Chrome makes the first index active, so put the newly traversed tab first
  // and retain every tab that was already selected.
  const selectedIndices = [
    target.index,
    ...tabs
      .filter((tab) => tab.highlighted && tab.index !== target.index)
      .map((tab) => tab.index),
  ];

  await chrome.tabs.highlight({
    windowId: target.windowId,
    tabs: selectedIndices,
  });
}

chrome.commands.onCommand.addListener((command) => {
  const actions = {
    "select-previous-tab": [-1, true],
    "select-next-tab": [1, true],
  };

  const action = actions[command];
  if (!action) return;

  travelTabs(...action).catch((error) => {
    console.error(`Tab command ${command} failed`, error);
  });
});
