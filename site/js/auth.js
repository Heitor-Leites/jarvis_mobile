function saveToken(token) {
    localStorage.setItem("jarvis_token", token);
}

function getToken() {
    return localStorage.getItem("jarvis_token");
}

function removeToken() {
    localStorage.removeItem("jarvis_token");
}

function isLoggedIn() {
    return getToken() !== null;
}