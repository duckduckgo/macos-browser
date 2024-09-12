// Function to add the dynamic blocking rule
function addDynamicBlockingRule() {
  const rule = {
    id: 1,  // Updated Rule ID to 1
    priority: 1,  // Rule priority
    action: {
      type: 'block'  // Action type is "block" to block the request
    },
    condition: {
      urlFilter: 'https://bad.third-party.site/privacy-protections/request-blocking/block-me/script.js',
      resourceTypes: ['script']  // This applies the rule only to script resource types
    }
  };

  // Use updateDynamicRules to add the new blocking rule
  chrome.declarativeNetRequest.updateDynamicRules({
    addRules: [rule],  // Adding the new rule
    removeRuleIds: []  // Not removing any existing rules
  }, () => {
    if (chrome.runtime.lastError) {
      console.error(`Error adding rule: ${chrome.runtime.lastError}`);
    } else {
      console.log('Blocking rule added successfully.');
    }
  });
}

// Function to remove the dynamic blocking rule
function removeDynamicBlockingRule() {
  chrome.declarativeNetRequest.updateDynamicRules({
    addRules: [],
    removeRuleIds: [1]  // Updated to remove the rule with ID 1
  }, () => {
    if (chrome.runtime.lastError) {
      console.error(`Error removing rule: ${chrome.runtime.lastError}`);
    } else {
      console.log('Blocking rule removed successfully.');
    }
  });
}

// Example: Add the blocking rule when the extension is installed or updated
chrome.runtime.onInstalled.addListener(() => {
  addDynamicBlockingRule();
});

// You can also use the chrome.action.onClicked event to toggle the rule on/off
chrome.action.onClicked.addListener(() => {
  removeDynamicBlockingRule();
});
