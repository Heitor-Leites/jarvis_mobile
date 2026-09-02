const API_URL = "https://jarvis-backend-mzhe.onrender.com";


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

        throw new Error(
            data.detail || "Erro na comunicação com o servidor."
        );

    }


    return data;
}