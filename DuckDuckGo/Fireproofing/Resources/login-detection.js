//
//  login-detection.js
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

"use strict";

(function() {

    if (!window.__ddg__) {
        Object.defineProperty(window, "__ddg__", {
            enumerable: false,
            configurable: false,
            writable: false,
            value: {
            }
        });
    }

    // Set `logger = console` to print messages to the web inspector console
    const logger = duckduckgoDebugMessaging;

    function loginAttemptDetected() {
        try {
            logger.log("Possible login attempt detected");
            webkit.messageHandlers.loginFormDetected.postMessage({});
        } catch (error) {}
    }

    function inputVisible(input) {
        return !(input.offsetWidth === 0 && input.offsetHeight === 0) && !input.hidden && input.value !== "";
    }

    function validatePasswordField(passwords) {
        for (var i = 0; i < passwords.length; i++) {
            var password = passwords[i];
            var found = inputVisible(password);
            if (found) {
                loginAttemptDetected();
                return found;
            }
        }
    }

    function checkIsLoginForm(form) {
        logger.log("Checking for login form " + form);

        var inputs = form.getElementsByTagName("input");
        if (!inputs) {
            return;
        }

        for (var i = 0; i < inputs.length; i++) {
            var input = inputs.item(i);
            if (input.type == "password" && inputVisible(input)) {
                loginAttemptDetected();
                return true;
            }
        }

        logger.log("No password field in form " + form);
        return false;
    }

    function scanPasswordFieldsInIFrame() {
        logger.log("Scanning for iframes");
        var iframes = document.querySelectorAll('iframe');
        for (var i = 0; i < iframes.length; i++) {
            var iframeDoc = iframes[i].contentWindow.document;
            passwords = iframeDoc.querySelectorAll('input[type=password]');
            var found = validatePasswordField(passwords);
            if (found) {
                return found;
            }
        }
        return false;
    }

    function submitHandler(event) {
        checkIsLoginForm(event.target);
    }

    function scanForForms() {
        logger.log("Scanning for forms");

        var forms = document.forms;
        if (!forms || forms.length === 0) {
            logger.log("No forms found");
            return;
        }

        for (var i = 0; i < forms.length; i++) {
            var form = forms[i];
            form.removeEventListener("submit", submitHandler);
            form.addEventListener("submit", submitHandler);
            logger.log("Adding form handler for form #" + i);
        }
    }

    function scanForPasswordField() {
        logger.log("Scanning DOM for password fields");

        var passwords = document.querySelectorAll('input[type=password]');
        if (passwords.length === 0) {
            var found = scanPasswordFieldsInIFrame()
            if (!found) {
                logger.log("No password fields found");
            }
            return found;
        }

        return validatePasswordField(passwords);
    }

    // Allow the `scanForPasswordField` function to be called from the client.
    Object.defineProperty(window.__ddg__, "scanForPasswordField", {
        enumerable: false,
        configurable: false,
        writable: false,
        value: scanForPasswordField
    })

    // Register event listeners:

    logger.log("Installing loginDetection.js - IN");

    window.addEventListener("DOMContentLoaded", function(event) {
        logger.log("Adding login detection to DOM");
        setTimeout(scanForForms, 1000);
    });

    window.addEventListener("click", scanForForms);
    window.addEventListener("beforeunload", scanForForms);
    window.addEventListener("submit", submitHandler);

    try {
        const observer = new PerformanceObserver((list, observer) => {
            const entries = list.getEntries().filter((entry) => {
                var found = (entry.initiatorType == "xmlhttprequest" || entry.initiatorType == "fetch") && entry.name.split("?")[0].match(/login|sign-in|signin|session/);
                if (found) {
                    logger.log("XHR: observed login - " + entry.name.split("?")[0]);
                }
                return found;
            });

            if (entries.length == 0) {
                return;
            }

            logger.log("XHR: checking forms - IN");
            var forms = document.forms;
            if (!forms || forms.length == 0) {
                logger.log("XHR: No forms found");
                return;
            }

            for (var i = 0; i < forms.length; i++) {
                if (checkIsLoginForm(forms[i])) {
                    logger.log("XHR: found login form");
                    break;
                }
            }
            logger.log("XHR: checking forms - OUT");

        });
        observer.observe({entryTypes: ["resource"]});
    } catch(error) {
        // no-op
    }

    logger.log("Installing loginDetection.js - OUT");

})();
