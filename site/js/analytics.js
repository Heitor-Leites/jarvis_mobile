/*
 * Analytics privacy-first do J.A.R.V.I.S.
 *
 * O Project Token do PostHog é público por definição para bibliotecas de
 * cliente. Este módulo usa somente eventos manuais: não há autocaptura,
 * heatmap, gravação de sessão ou envio do conteúdo do usuário.
 */
(function () {
    "use strict";

    const POSTHOG_TOKEN =
        "phc_trQLfcNSVxP973bpx5Lovr2RwizZkJuWjBipVdSXTSxM";
    const POSTHOG_HOST = "https://us.i.posthog.com";
    const ANONYMOUS_ID_KEY = "jarvis_posthog_distinct_id";
    const DISABLED_KEY = "jarvis_analytics_disabled";
    const SAFE_PROPERTY_KEYS = new Set([
        "path",
        "method",
        "mode",
        "platform",
        "source",
        "status",
        "success",
        "variant",
        "$anon_distinct_id",
    ]);

    function isDisabled() {
        return (
            localStorage.getItem(DISABLED_KEY) === "true" ||
            navigator.doNotTrack === "1"
        );
    }

    function getAnonymousId() {
        let distinctId = localStorage.getItem(ANONYMOUS_ID_KEY);

        if (!distinctId) {
            distinctId = window.crypto?.randomUUID
                ? window.crypto.randomUUID()
                : `web-${Date.now()}-${Math.random().toString(16).slice(2)}`;
            localStorage.setItem(ANONYMOUS_ID_KEY, distinctId);
        }

        return distinctId;
    }

    function safeProperties(properties) {
        const result = {
            app: "jarvis",
            platform: "web",
        };

        Object.entries(properties || {}).forEach(([key, value]) => {
            if (!SAFE_PROPERTY_KEYS.has(key)) {
                return;
            }

            if (
                typeof value === "string" ||
                typeof value === "number" ||
                typeof value === "boolean"
            ) {
                result[key] = String(value).slice(0, 120);
            }
        });

        return result;
    }

    function sendEvent(event, distinctId, properties) {
        if (!POSTHOG_TOKEN || isDisabled()) {
            return;
        }

        fetch(`${POSTHOG_HOST}/capture/`, {
            method: "POST",
            keepalive: true,
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                api_key: POSTHOG_TOKEN,
                event,
                properties: {
                    ...safeProperties(properties),
                    distinct_id: distinctId,
                },
            }),
        }).catch(() => {
            // Analytics jamais deve interromper o uso do J.A.R.V.I.S.
        });
    }

    function capture(event, properties = {}) {
        sendEvent(event, getAnonymousId(), properties);
    }

    function identify(userId) {
        const normalizedUserId = String(userId || "").trim().slice(0, 80);
        if (!normalizedUserId || isDisabled()) {
            return;
        }

        const anonymousId = getAnonymousId();
        sendEvent("$identify", normalizedUserId, {
            distinct_id: normalizedUserId,
            $anon_distinct_id: anonymousId,
        });
    }

    function identifyFromToken(token) {
        try {
            const encodedPayload = String(token || "").split(".")[1];
            if (!encodedPayload) {
                return;
            }

            const normalizedPayload = encodedPayload
                .replace(/-/g, "+")
                .replace(/_/g, "/");
            const paddedPayload = normalizedPayload.padEnd(
                Math.ceil(normalizedPayload.length / 4) * 4,
                "=",
            );
            const payload = JSON.parse(
                decodeURIComponent(
                    atob(paddedPayload)
                        .split("")
                        .map((character) =>
                            `%${("00" + character.charCodeAt(0).toString(16)).slice(-2)}`,
                        )
                        .join(""),
                ),
            );

            identify(payload.sub);
        } catch (_) {
            // Um token inválido não deve afetar o login.
        }
    }

    function reset() {
        localStorage.removeItem(ANONYMOUS_ID_KEY);
    }

    window.jarvisAnalytics = {
        capture,
        identify,
        identifyFromToken,
        reset,
        disable() {
            localStorage.setItem(DISABLED_KEY, "true");
        },
        enable() {
            localStorage.removeItem(DISABLED_KEY);
        },
    };

    window.addEventListener("DOMContentLoaded", () => {
        capture("page_view", {
            path: window.location.pathname,
        });
    });
})();
