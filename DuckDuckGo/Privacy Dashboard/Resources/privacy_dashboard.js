
(function() {

    function onChangeTrackerBlocking(arg) {
        
        document.getElementById("trackerBlocking").value = JSON.stringify(arg);
    }

    function onChangeAllowedPermissions(arg) {
        document.getElementById("permissions").value = JSON.stringify(arg);
    }

    var protectionState = false;
    function toggleProtectionAction() {
        protectionState = !protectionState;
        webkit.messageHandlers.privacyDashboardSetProtection.postMessage(protectionState);
    }

    function firePixelAction() {
        webkit.messageHandlers.privacyDashboardFirePixel.postMessage("m_mac_privacy_dashboard_open");
    }

    function changePermissionAction() {
        webkit.messageHandlers.privacyDashboardSetPermission.postMessage({
            permission: "geolocation", // camera, microphone, cameraAndMicrophone, geolocation, sound
            value: "deny" // ask, grant, deny
        });
    }

    var protectionState = false;
    function pausePermissionAction() {
        webkit.messageHandlers.privacyDashboardSetPermissionPaused.postMessage({
            permission: "geolocation", // camera, microphone, cameraAndMicrophone, geolocation, sound
            paused: true
        });
    }

    function onLoadNativeCallback(e) {
        window.onChangeTrackerBlocking = onChangeTrackerBlocking;
        window.onChangeAllowedPermissions = onChangeAllowedPermissions;

        document.getElementById("toggleProtectionButton").addEventListener("click", toggleProtectionAction);
        document.getElementById("firePixelButton").addEventListener("click", firePixelAction);
        document.getElementById("changePermissionButton").addEventListener("click", changePermissionAction);
        document.getElementById("pausePermissionButton").addEventListener("click", pausePermissionAction);
    }
    window.addEventListener("load", onLoadNativeCallback, false);

})();
