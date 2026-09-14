const API_URL = "https://api.30jarvis.com.br";
let authenticatedConversationId = null;

function getBrowserDeviceId() {
    const key = "jarvis_device_id";
    let deviceId = localStorage.getItem(key);

    if (!deviceId) {
        deviceId = window.crypto?.randomUUID
            ? window.crypto.randomUUID()
            : `web-${Date.now()}-${Math.random().toString(16).slice(2)}`;
        localStorage.setItem(key, deviceId);
    }

    return deviceId;
}

function getBrowserDeviceName() {
    const agent = navigator.userAgent || "";
    const browser = agent.includes("Edg/")
        ? "Microsoft Edge"
        : agent.includes("Chrome/")
            ? "Google Chrome"
            : agent.includes("Firefox/")
                ? "Mozilla Firefox"
                : agent.includes("Safari/")
                    ? "Safari"
                    : "Navegador web";

    return `${browser} · ${navigator.platform || "Sistema atual"}`;
}

async function registerBrowserDevice() {
    const token = localStorage.getItem("jarvis_token");
    if (!token) return;

    try {
        await fetch(`${API_URL}/devices/heartbeat`, {
            method: "POST",
            credentials: "include",
            headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${token}`,
                "X-Jarvis-Device-Id": getBrowserDeviceId()
            },
            body: JSON.stringify({
                device_id: getBrowserDeviceId(),
                device_name: getBrowserDeviceName(),
                platform: "web"
            })
        });
    } catch (_) {
        // O registro do aparelho não deve impedir o uso do JARVIS.
    }
}

window.jarvisRegisterBrowserDevice = registerBrowserDevice;
window.setTimeout(registerBrowserDevice, 0);

window.sendMessage = sendMessage;

async function apiRequest(endpoint, options = {}) {
    const response = await fetch(`${API_URL}${endpoint}`, {
        ...options,
        credentials: options.credentials || "include",
        headers: {
            "Content-Type": "application/json",
            ...(options.headers || {})
        }
    });

    const contentType = response.headers.get("content-type") || "";
    let data;

    if (contentType.includes("application/json")) {
        data = await response.json();
    } else {
        const text = await response.text();
        data = {
            detail: text || "Erro desconhecido do servidor."
        };
    }

    if (!response.ok) {
        const error = new Error(
            data.detail || "Erro na comunicação com o servidor."
        );
        error.status = response.status;
        throw error;
    }

    return data;
}

async function publicChat(message, history = []) {
    const response = await apiRequest("/public/chat", {
        method: "POST",
        body: JSON.stringify({
            message,
            history
        })
    });

    return response.response;
}

async function authenticatedChat(message) {
    const token = localStorage.getItem("jarvis_token");

    if (!token) {
        throw new Error("NOT_AUTHENTICATED");
    }

    const response = await apiRequest("/chat", {
        method: "POST",
        headers: {
            Authorization: `Bearer ${token}`
        },
        body: JSON.stringify({
            message,
            ...(authenticatedConversationId !== null
                ? { conversation_id: authenticatedConversationId }
                : {})
        })
    });

    if (response.conversation_id !== undefined) {
        const parsedConversationId = Number(response.conversation_id);

        if (Number.isInteger(parsedConversationId)) {
            authenticatedConversationId = parsedConversationId;
        }
    }

    return response.response;
}

async function sendMessage(message, history = []) {
    const token = localStorage.getItem("jarvis_token");

    if (token) {
        try {
            return await authenticatedChat(message);
        } catch (error) {
            if (error.status === 401) {
                localStorage.removeItem("jarvis_token");
                authenticatedConversationId = null;
            } else {
                throw error;
            }
        }
    }

    return publicChat(message, history);
}
