import os

from dotenv import load_dotenv
from database.connection import SessionLocal
from database.models import User
from auth import hash_password


load_dotenv()

USERNAME = os.getenv("ADMIN_USERNAME", "admin")
PASSWORD = os.getenv("ADMIN_PASSWORD")

if not PASSWORD:
    raise RuntimeError(
        "ADMIN_PASSWORD não foi encontrada nas variáveis de ambiente."
    )


db = SessionLocal()

try:
    existing = (
        db.query(User)
        .filter(User.username == USERNAME)
        .first()
    )

    if existing:
        print("Usuário já existe.")
    else:
        user = User(
            username=USERNAME,
            password_hash=hash_password(PASSWORD),
            active=True,
        )

        db.add(user)
        db.commit()
        db.refresh(user)

        print("Usuário criado com sucesso.")
        print(f"ID: {user.id}")
        print(f"Usuário: {USERNAME}")

finally:
    db.close()
