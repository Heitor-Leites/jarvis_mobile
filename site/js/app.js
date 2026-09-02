// ============================================================
// JARVIS DASHBOARD
// ============================================================


// ============================================================
// VERIFICAÇÃO DE LOGIN
// ============================================================

if (!isLoggedIn()) {

    const loginPath =
        window.location.pathname.includes("/pages/")
            ? "login.html"
            : "pages/login.html";

    window.location.replace(loginPath);
}


// ============================================================
// ELEMENTOS
// ============================================================

const systemStatus =
    document.getElementById("systemStatus");

const sidebarStatus =
    document.getElementById("sidebarStatus");

const apiStatus =
    document.getElementById("apiStatus");

const databaseStatus =
    document.getElementById("databaseStatus");

const memoryCount =
    document.getElementById("memoryCount");

const welcomeMessage =
    document.getElementById("welcomeMessage");

const lastActivity =
    document.getElementById("lastActivity");

const activityContainer =
    document.getElementById("activityContainer");


// ============================================================
// ESTADO
// ============================================================

let currentUser = null;


// ============================================================
// CARREGAR USUÁRIO
// ============================================================

async function loadUser() {

    try {

        const user =
            await apiRequest(
                "/me",
                {
                    headers: {
                        "Authorization":
                            `Bearer ${getToken()}`
                    }
                }
            );

        currentUser = user;


        if (welcomeMessage) {

            welcomeMessage.textContent =
                `Bem-vindo, ${user.username}.`;

        }

    } catch (error) {

        console.error(
            "Erro ao carregar usuário:",
            error
        );

        logout();
    }
}


// ============================================================
// VERIFICAR API
// ============================================================

async function checkAPI() {

    try {

        const response =
            await apiRequest("/health");


        if (
            response &&
            response.status === "healthy"
        ) {

            if (apiStatus) {

                apiStatus.textContent =
                    "ONLINE";

                apiStatus.style.color =
                    "#4ade80";
            }


            if (systemStatus) {

                systemStatus.textContent =
                    "Sistema operacional";
            }


            if (sidebarStatus) {

                sidebarStatus.textContent =
                    "Sistema online";
            }

        } else {

            if (apiStatus) {

                apiStatus.textContent =
                    "ONLINE";

                apiStatus.style.color =
                    "#4ade80";
            }

        }

    } catch (error) {

        console.error(
            "Erro ao verificar API:",
            error
        );


        if (apiStatus) {

            apiStatus.textContent =
                "OFFLINE";

            apiStatus.style.color =
                "#f87171";
        }


        if (systemStatus) {

            systemStatus.textContent =
                "Sistema indisponível";
        }


        if (sidebarStatus) {

            sidebarStatus.textContent =
                "Sistema offline";
        }
    }
}


// ============================================================
// CARREGAR MEMÓRIAS
// ============================================================

async function loadMemories() {

    try {

        const response =
            await apiRequest(
                "/memories",
                {
                    headers: {
                        "Authorization":
                            `Bearer ${getToken()}`
                    }
                }
            );


        const memories =
            response.memories || [];


        // ----------------------------------------------------
        // CONTADOR
        // ----------------------------------------------------

        if (memoryCount) {

            memoryCount.textContent =
                memories.length;
        }


        // ----------------------------------------------------
        // DATABASE
        // ----------------------------------------------------

        if (databaseStatus) {

            databaseStatus.textContent =
                "ONLINE";

            databaseStatus.style.color =
                "#4ade80";
        }


        // ----------------------------------------------------
        // ATIVIDADE
        // ----------------------------------------------------

        if (!activityContainer) {
            return;
        }


        if (memories.length === 0) {

            activityContainer.textContent =
                "Nenhuma memória registrada.";

            return;
        }


        // ----------------------------------------------------
        // PEGAR A MEMÓRIA MAIS RECENTE
        // ----------------------------------------------------

        const latestMemory =
            [...memories].sort(
                (a, b) =>
                    new Date(b.created_at) -
                    new Date(a.created_at)
            )[0];


        // ----------------------------------------------------
        // FORMATAR CATEGORIA
        // ----------------------------------------------------

        const categoryNames = {

            general: "Geral",

            projects: "Projetos",

            preferences: "Preferências"

        };


        const category =
            categoryNames[
                latestMemory.category
            ] ||
            latestMemory.category ||
            "Geral";


        // ----------------------------------------------------
        // IMPORTÂNCIA
        // ----------------------------------------------------

        const importance =
            Number(
                latestMemory.importance || 1
            );


        const stars =
            "★".repeat(
                Math.max(
                    1,
                    Math.min(
                        importance,
                        5
                    )
                )
            );


        // ----------------------------------------------------
        // DATA
        // ----------------------------------------------------

        let formattedDate =
            "Data desconhecida";


        if (latestMemory.created_at) {

            const date =
                new Date(
                    latestMemory.created_at
                );


            formattedDate =
                date.toLocaleString(
                    "pt-BR",
                    {
                        dateStyle: "short",
                        timeStyle: "short"
                    }
                );
        }


        // ----------------------------------------------------
        // SEGURANÇA
        // ----------------------------------------------------

        const safeContent =
            escapeHtml(
                latestMemory.content
            );


        // ----------------------------------------------------
        // RENDER
        // ----------------------------------------------------

        activityContainer.innerHTML = `

            <div class="activity-item">

                <div>

                    <strong>
                        Nova memória registrada
                    </strong>

                    <p>
                        ${safeContent}
                    </p>

                </div>

                <div class="activity-meta">

                    <span>
                        ${category}
                    </span>

                    <span>
                        ${stars}
                    </span>

                    <span>
                        ${formattedDate}
                    </span>

                </div>

            </div>

        `;

    } catch (error) {

        console.error(
            "Erro ao carregar memórias:",
            error
        );


        if (memoryCount) {

            memoryCount.textContent =
                "—";
        }


        if (databaseStatus) {

            databaseStatus.textContent =
                "ERRO";

            databaseStatus.style.color =
                "#f87171";
        }


        if (activityContainer) {

            activityContainer.textContent =
                "Não foi possível carregar as memórias.";
        }
    }
}


// ============================================================
// ESCAPAR HTML
// ============================================================

function escapeHtml(value) {

    return String(value)
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");
}


// ============================================================
// ATIVIDADE
// ============================================================

function updateActivity() {

    const now =
        new Date();


    const time =
        now.toLocaleTimeString(
            "pt-BR",
            {
                hour: "2-digit",
                minute: "2-digit"
            }
        );


    if (lastActivity) {

        lastActivity.textContent =
            `Atualizado às ${time}`;
    }
}


// ============================================================
// LOGOUT
// ============================================================

function logout() {

    removeToken();


    const loginPath =
        window.location.pathname.includes("/pages/")
            ? "login.html"
            : "pages/login.html";


    window.location.replace(
        loginPath
    );
}


// ============================================================
// INICIALIZAÇÃO
// ============================================================

async function initializeDashboard() {

    updateActivity();

    await loadUser();

    await checkAPI();

    await loadMemories();
}


// ============================================================
// START
// ============================================================

initializeDashboard();