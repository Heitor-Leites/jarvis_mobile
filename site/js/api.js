const API_URL = "https://jarvis-backend-mzhe.onrender.com";

window.sendMessage = sendMessage;

async function apiRequest(endpoint, options = {}) {
    const response = await fetch(
        `${API_URL}${endpoint}`,
        {
            ...options,
            headers: {
                "Content-Type": "application/json",
                ...(options.headers || {})
            }
        }
    );

    const contentType =
        response.headers.get("content-type") || "";

    let data;

    if (contentType.includes("application/json")) {
        data = await response.json();
    } else {
        const text = await response.text();

        data = {
            detail:
                text ||
                "Erro desconhecido do servidor."
        };
    }

    if (!response.ok) {
        const error = new Error(
            data.detail ||
            "Erro na comunicação com o servidor."
        );

        error.status = response.status;

        throw error;
    }

    return data;
}

async function publicChat(message) {
    const response = await apiRequest(
        "/public/chat",
        {
            method: "POST",
            body: JSON.stringify({
                message: message
            })
        }
    );

    return response.response;
}

async function authenticatedChat(message) {
    const token =
        localStorage.getItem("jarvis_token");

    if (!token) {
        throw new Error("NOT_AUTHENTICATED");
    }

    const response = await apiRequest(
        "/chat",
        {
            method: "POST",
            headers: {
                "Authorization":
                    `Bearer ${token}`
            },
            body: JSON.stringify({
                message: message
            })
        }
    );

    return response.response;
}

async function sendMessage(message) {
    const token =
        localStorage.getItem("jarvis_token");

    if (token) {
        try {
            return await authenticatedChat(message);
        } catch (error) {
            if (error.status === 401) {
                localStorage.removeItem(
                    "jarvis_token"
                );
            } else {
                throw error;
            }
        }
    }

    return await publicChat(message);
}

window.sendMessage = sendMessage;