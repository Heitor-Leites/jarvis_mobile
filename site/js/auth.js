function saveToken(token) {
    localStorage.setItem("jarvis_token", token);

    window.jarvisAnalytics?.identifyFromToken(token);
}

function getToken() {
    return localStorage.getItem("jarvis_token");
}

function removeToken() {
    localStorage.removeItem("jarvis_token");

    window.jarvisAnalytics?.reset();
}

function isLoggedIn() {
    return getToken() !== null;
}
