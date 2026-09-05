import os
import secrets
import time

from dotenv import load_dotenv

from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse

from starlette.middleware.sessions import SessionMiddleware

from authlib.integrations.starlette_client import OAuth

from openai import OpenAI

from pydantic import BaseModel

from sqlalchemy.orm import Session

from auth import (
    create_access_token,
    get_current_user_id,
    hash_password,
    verify_password,
)

from conversation.manager import (
    delete_conversation,
    get_conversations,
    save_message,
)

from database.database import (
    Base,
    SessionLocal,
    engine,
)

from database.models import (
    User,
    OAuthAccount,
)

from memory.manager import (
    create_memory,
    delete_memory,
    detect_memory,
    get_memories,
)


# ============================================================
# CONFIGURAÇÃO
# ============================================================

load_dotenv()


# ============================================================
# OPENAI
# ============================================================

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

if not OPENAI_API_KEY:
    raise RuntimeError(
        "OPENAI_API_KEY não foi encontrada."
    )

client = OpenAI(
    api_key=OPENAI_API_KEY
)


# ============================================================
# ADMIN / LOGIN
# ============================================================

ADMIN_USERNAME = os.getenv(
    "ADMIN_USERNAME",
    "admin",
)

ADMIN_PASSWORD = os.getenv(
    "ADMIN_PASSWORD",
)

if not ADMIN_PASSWORD:
    raise RuntimeError(
        "ADMIN_PASSWORD não foi encontrada."
    )


# ============================================================
# GOOGLE OAUTH
# ============================================================

GOOGLE_CLIENT_ID = os.getenv(
    "GOOGLE_CLIENT_ID"
)

GOOGLE_CLIENT_SECRET = os.getenv(
    "GOOGLE_CLIENT_SECRET"
)

GOOGLE_REDIRECT_URI = os.getenv(
    "GOOGLE_REDIRECT_URI"
)

SESSION_SECRET = os.getenv(
    "SESSION_SECRET"
)

FRONTEND_URL = os.getenv(
    "FRONTEND_URL",
    "https://30jarvis.com.br",
)

if not GOOGLE_CLIENT_ID:
    raise RuntimeError(
        "GOOGLE_CLIENT_ID não foi configurado."
    )

if not GOOGLE_CLIENT_SECRET:
    raise RuntimeError(
        "GOOGLE_CLIENT_SECRET não foi configurado."
    )

if not SESSION_SECRET:
    raise RuntimeError(
        "SESSION_SECRET não foi configurado."
    )


oauth = OAuth()

oauth.register(
    name="google",
    client_id=GOOGLE_CLIENT_ID,
    client_secret=GOOGLE_CLIENT_SECRET,
    server_metadata_url=(
        "https://accounts.google.com/"
        ".well-known/openid-configuration"
    ),
    client_kwargs={
        "scope": "openid email profile",
    },
)


# ============================================================
# BANCO DE DADOS
# ============================================================

Base.metadata.create_all(
    bind=engine
)


# ============================================================
# FASTAPI
# ============================================================

app = FastAPI(
    title="JARVIS Backend",
    version="1.0.0",
)


# ============================================================
# SESSÃO
# ============================================================

app.add_middleware(
    SessionMiddleware,
    secret_key=SESSION_SECRET,
    same_site="lax",
    https_only=True,
)


# ============================================================
# CORS
# ============================================================

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
    "https://30jarvis.com.br",
    "https://www.30jarvis.com.br",
    "http://localhost:54396",
],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================
# DATABASE SESSION
# ============================================================

def get_db():
    db = SessionLocal()

    try:
        yield db

    finally:
        db.close()


# ============================================================
# GARANTIR USUÁRIO ADMIN
# ============================================================

def ensure_admin_user():
    db = SessionLocal()

    try:
        user = (
            db.query(User)
            .filter(
                User.username == ADMIN_USERNAME
            )
            .first()
        )

        if user:
            user.password_hash = hash_password(
                ADMIN_PASSWORD
            )

            user.active = True

        else:
            user = User(
                username=ADMIN_USERNAME,
                password_hash=hash_password(
                    ADMIN_PASSWORD
                ),
                active=True,
            )

            db.add(user)

        db.commit()

    finally:
        db.close()


ensure_admin_user()


# ============================================================
# MODELOS
# ============================================================

class ChatRequest(BaseModel):
    message: str


class LoginRequest(BaseModel):
    username: str
    password: str


class MemoryRequest(BaseModel):
    content: str
    category: str = "general"
    importance: int = 3


# ============================================================
# ROOT
# ============================================================

@app.get("/")
def root():
    return {
        "status": "online",
        "service": "JARVIS Backend",
        "version": "1.0.0",
    }


# ============================================================
# HEALTH
# ============================================================

@app.get("/health")
def health():
    return {
        "status": "healthy",
        "api": "online",
        "database": "online",
    }


# ============================================================
# LOGIN TRADICIONAL
# ============================================================

@app.post("/login")
def login(
    request: LoginRequest,
    db: Session = Depends(get_db),
):
    username = request.username.strip()
    password = request.password

    if not username or not password:
        raise HTTPException(
            status_code=401,
            detail="Usuário ou senha inválidos.",
        )

    user = (
        db.query(User)
        .filter(
            User.username == username
        )
        .first()
    )

    if not user:
        raise HTTPException(
            status_code=401,
            detail="Usuário ou senha inválidos.",
        )

    if not user.active:
        raise HTTPException(
            status_code=403,
            detail="Usuário desativado.",
        )

    if not verify_password(
        password,
        user.password_hash,
    ):
        raise HTTPException(
            status_code=401,
            detail="Usuário ou senha inválidos.",
        )

    token = create_access_token(
        user.id
    )

    return {
        "access_token": token,
        "token_type": "bearer",
        "user_id": user.id,
        "username": user.username,
    }


# ============================================================
# GOOGLE LOGIN
# ============================================================

@app.get("/auth/google/login")
async def google_login(
    request: Request,
):
    return await oauth.google.authorize_redirect(
        request,
        GOOGLE_REDIRECT_URI,
    )


# ============================================================
# GOOGLE CALLBACK
# ============================================================

@app.get("/auth/google/callback")
async def google_callback(
    request: Request,
    db: Session = Depends(get_db),
):
    try:
        token = await oauth.google.authorize_access_token(
            request
        )

        userinfo = token.get(
            "userinfo"
        )

        if not userinfo:
            userinfo = await oauth.google.userinfo(
                token=token
            )

        google_id = userinfo.get(
            "sub"
        )

        email = userinfo.get(
            "email"
        )

        name = userinfo.get(
            "name"
        )

        picture = userinfo.get(
            "picture"
        )

        if not google_id:
            raise RuntimeError(
                "Google não retornou o identificador do usuário."
            )

        # ----------------------------------------------------
        # PROCURAR CONTA GOOGLE EXISTENTE
        # ----------------------------------------------------

        oauth_account = (
            db.query(OAuthAccount)
            .filter(
                OAuthAccount.provider == "google",
                OAuthAccount.provider_user_id == google_id,
            )
            .first()
        )

        # ----------------------------------------------------
        # CONTA JÁ VINCULADA
        # ----------------------------------------------------

        if oauth_account:
            user = (
                db.query(User)
                .filter(
                    User.id == oauth_account.user_id
                )
                .first()
            )

            if not user:
                raise RuntimeError(
                    "Conta Google encontrada, mas usuário não existe."
                )

            # Atualiza a foto caso o Google
            # tenha retornado uma nova URL.
            if picture:
                user.picture_url = picture

            db.commit()

        # ----------------------------------------------------
        # NOVA CONTA GOOGLE
        # ----------------------------------------------------

        else:
            base_username = (
                email.split("@")[0]
                if email
                else name or "google_user"
            )

            base_username = "".join(
                char
                for char in base_username
                if char.isalnum()
                or char in "._-"
            )

            if not base_username:
                base_username = "google_user"

            base_username = base_username[:90]

            username = base_username

            counter = 1

            while (
                db.query(User)
                .filter(
                    User.username == username
                )
                .first()
            ):
                username = (
                    f"{base_username[:80]}_{counter}"
                )

                counter += 1

            random_password = secrets.token_urlsafe(
                32
            )

            user = User(
                username=username,
                password_hash=hash_password(
                    random_password
                ),
                active=True,
                picture_url=picture,
            )

            db.add(user)

            db.flush()

            oauth_account = OAuthAccount(
                user_id=user.id,
                provider="google",
                provider_user_id=google_id,
            )

            db.add(oauth_account)

            db.commit()

        # ----------------------------------------------------
        # VERIFICAR USUÁRIO
        # ----------------------------------------------------

        if not user.active:
            raise RuntimeError(
                "Usuário desativado."
            )

        # ----------------------------------------------------
        # GERAR JWT DO JARVIS
        # ----------------------------------------------------

        jwt_token = create_access_token(
            user.id
        )

        # ----------------------------------------------------
        # DEVOLVER PARA O SITE
        # ----------------------------------------------------

        redirect_url = (
            f"{FRONTEND_URL}/pages/login.html"
            f"#token={jwt_token}"
        )

        return RedirectResponse(
            url=redirect_url,
            status_code=302,
        )

    except Exception as error:
        print(
            f"Erro no Google OAuth: {error}"
        )

        error_url = (
            f"{FRONTEND_URL}/pages/login.html"
            "#oauth_error=google_login_failed"
        )

        return RedirectResponse(
            url=error_url,
            status_code=302,
        )


# ============================================================
# USUÁRIO ATUAL
# ============================================================

@app.get("/me")
def get_me(
    user_id: int = Depends(
        get_current_user_id
    ),
    db: Session = Depends(get_db),
):
    user = (
        db.query(User)
        .filter(
            User.id == user_id
        )
        .first()
    )

    if not user:
        raise HTTPException(
            status_code=404,
            detail="Usuário não encontrado.",
        )

    return {
        "id": user.id,
        "username": user.username,
        "active": user.active,
        "picture_url": user.picture_url,
    }


# ============================================================
# CHAT AUTENTICADO
# ============================================================

@app.post("/chat")
def chat(
    request: ChatRequest,
    user_id: int = Depends(
        get_current_user_id
    ),
    db: Session = Depends(get_db),
):
    message = request.message.strip()

    if not message:
        raise HTTPException(
            status_code=422,
            detail="VALIDATION_ERROR",
        )

    if len(message) > 4000:
        raise HTTPException(
            status_code=413,
            detail="Mensagem muito longa.",
        )

    try:
        save_message(
            db=db,
            user_id=user_id,
            role="user",
            content=message,
        )

        for tentativa in range(3):
            try:
                response = client.responses.create(
                    model="gpt-5.6-luna",
                    input=message,
                )

                answer = response.output_text

                if not answer:
                    raise RuntimeError(
                        "A IA não retornou uma resposta."
                    )

                break

            except Exception as error:
                print(
                    f"Erro no /chat "
                    f"(tentativa {tentativa + 1}/3): "
                    f"{error}"
                )

                if tentativa == 2:
                    raise

                time.sleep(2)

        save_message(
            db=db,
            user_id=user_id,
            role="assistant",
            content=answer,
        )

        return {
            "response": answer,
        }

    except HTTPException:
        raise

    except Exception as error:
        print(
            f"Erro final no /chat: {error}"
        )

        raise HTTPException(
            status_code=503,
            detail=(
                "O núcleo de IA está temporariamente "
                "indisponível. Tente novamente em alguns segundos."
            ),
        )


# ============================================================
# CHAT PÚBLICO
# ============================================================

@app.post("/public/chat")
def public_chat(
    request: ChatRequest,
):
    message = request.message.strip()

    if not message:
        raise HTTPException(
            status_code=422,
            detail="VALIDATION_ERROR",
        )

    if len(message) > 4000:
        raise HTTPException(
            status_code=413,
            detail="Mensagem muito longa.",
        )

    for tentativa in range(3):
        try:
            response = client.responses.create(
                model="gpt-5.6-luna",
                input=message,
            )

            answer = response.output_text

            if not answer:
                raise RuntimeError(
                    "A IA não retornou uma resposta."
                )

            return {
                "response": answer,
            }

        except Exception as error:
            print(
                f"Erro no /public/chat "
                f"(tentativa {tentativa + 1}/3): "
                f"{error}"
            )

            if tentativa < 2:
                time.sleep(2)

    raise HTTPException(
        status_code=503,
        detail=(
            "O núcleo de IA está temporariamente "
            "indisponível. Tente novamente em alguns segundos."
        ),
    )


# ============================================================
# CONVERSAS
# ============================================================

@app.get("/conversations")
def conversations(
    user_id: int = Depends(
        get_current_user_id
    ),
    db: Session = Depends(get_db),
):
    return get_conversations(
        db=db,
        user_id=user_id,
    )


# ============================================================
# EXCLUIR CONVERSA
# ============================================================

@app.delete(
    "/conversations/{conversation_id}"
)
def remove_conversation(
    conversation_id: int,
    user_id: int = Depends(
        get_current_user_id
    ),
    db: Session = Depends(get_db),
):
    deleted = delete_conversation(
        db=db,
        user_id=user_id,
        conversation_id=conversation_id,
    )

    if not deleted:
        raise HTTPException(
            status_code=404,
            detail="Conversa não encontrada.",
        )

    return {
        "success": True,
        "message": "Conversa excluída.",
    }


# ============================================================
# MEMÓRIAS
# ============================================================

@app.get("/memories")
def memories(
    user_id: int = Depends(
        get_current_user_id
    ),
    db: Session = Depends(get_db),
):
    return get_memories(
        db=db,
        user_id=user_id,
    )


# ============================================================
# CRIAR MEMÓRIA
# ============================================================

@app.post("/memories")
def add_memory(
    request: MemoryRequest,
    user_id: int = Depends(
        get_current_user_id
    ),
    db: Session = Depends(get_db),
):
    content = request.content.strip()

    if not content:
        raise HTTPException(
            status_code=422,
            detail="VALIDATION_ERROR",
        )

    if request.importance < 1:
        importance = 1

    elif request.importance > 5:
        importance = 5

    else:
        importance = request.importance

    memory = create_memory(
        db=db,
        user_id=user_id,
        content=content,
        category=request.category,
        importance=importance,
    )

    return memory


# ============================================================
# DETECTAR MEMÓRIA
# ============================================================

@app.post("/memories/detect")
def detect_memory_route(
    request: MemoryRequest,
    user_id: int = Depends(
        get_current_user_id
    ),
    db: Session = Depends(get_db),
):
    content = request.content.strip()

    if not content:
        raise HTTPException(
            status_code=422,
            detail="VALIDATION_ERROR",
        )

    result = detect_memory(
        db=db,
        user_id=user_id,
        content=content,
    )

    return result


# ============================================================
# EXCLUIR MEMÓRIA
# ============================================================

@app.delete(
    "/memories/{memory_id}"
)
def remove_memory(
    memory_id: int,
    user_id: int = Depends(
        get_current_user_id
    ),
    db: Session = Depends(get_db),
):
    deleted = delete_memory(
        db=db,
        user_id=user_id,
        memory_id=memory_id,
    )

    if not deleted:
        raise HTTPException(
            status_code=404,
            detail="Memória não encontrada.",
        )

    return {
        "success": True,
        "message": "Memória excluída.",
    }