from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from database.models import ChatSession, Conversation


def save_message(
    db: Session,
    user_id: int,
    role: str,
    content: str,
    session_id: int | None = None,
) -> Conversation:
    content = content.strip()

    if not content:
        raise ValueError(
            "A mensagem não pode estar vazia."
        )

    if role not in ["user", "assistant"]:
        raise ValueError(
            "Role de mensagem inválido."
        )

    conversation = Conversation(
        user_id=user_id,
        session_id=session_id,
        role=role,
        content=content,
    )

    db.add(conversation)
    db.commit()
    db.refresh(conversation)

    return conversation


def create_chat_session(
    db: Session,
    user_id: int,
    title: str,
) -> ChatSession:
    title = title.strip()[:160] or "Nova conversa"
    session = ChatSession(
        user_id=user_id,
        title=title,
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    return session


def get_chat_session(
    db: Session,
    user_id: int,
    session_id: int,
) -> ChatSession | None:
    return db.scalar(
        select(ChatSession).where(
            ChatSession.id == session_id,
            ChatSession.user_id == user_id,
        )
    )


def get_session_messages(
    db: Session,
    user_id: int,
    session_id: int,
    limit: int = 20,
) -> list[dict]:
    statement = (
        select(Conversation)
        .where(
            Conversation.user_id == user_id,
            Conversation.session_id == session_id,
        )
        .order_by(Conversation.created_at.desc())
        .limit(limit)
    )
    messages = list(db.scalars(statement).all())
    messages.reverse()
    return [
        {
            "id": message.id,
            "role": message.role,
            "content": message.content,
            "created_at": (
                message.created_at.isoformat()
                if message.created_at
                else None
            ),
        }
        for message in messages
    ]


def get_legacy_message(
    db: Session,
    user_id: int,
    message_id: int,
) -> Conversation | None:
    return db.scalar(
        select(Conversation).where(
            Conversation.id == message_id,
            Conversation.user_id == user_id,
            Conversation.session_id.is_(None),
        )
    )


def list_chat_sessions(
    db: Session,
    user_id: int,
    limit: int = 100,
) -> list[dict]:
    sessions = list(
        db.scalars(
            select(ChatSession)
            .where(ChatSession.user_id == user_id)
            .order_by(ChatSession.updated_at.desc())
            .limit(limit)
        ).all()
    )

    result = [
        {
            "id": session.id,
            "title": session.title,
            "created_at": session.created_at.isoformat(),
            "updated_at": session.updated_at.isoformat(),
            "legacy": False,
        }
        for session in sessions
    ]

    legacy_messages = list(
        db.scalars(
            select(Conversation)
            .where(
                Conversation.user_id == user_id,
                Conversation.session_id.is_(None),
            )
            .order_by(Conversation.created_at.desc())
            .limit(20)
        ).all()
    )

    result.extend(
        {
            "id": -message.id,
            "title": message.content[:80],
            "created_at": message.created_at.isoformat(),
            "updated_at": message.created_at.isoformat(),
            "legacy": True,
        }
        for message in legacy_messages
    )
    return result


def touch_chat_session(
    db: Session,
    session: ChatSession,
) -> None:
    session.updated_at = datetime.utcnow()
    db.add(session)


def get_conversations(
    db: Session,
    user_id: int,
    limit: int = 100,
) -> list[dict]:
    statement = (
        select(Conversation)
        .where(
            Conversation.user_id == user_id
        )
        .order_by(
            Conversation.created_at.desc()
        )
        .limit(limit)
    )

    conversations = list(
        db.scalars(statement).all()
    )

    conversations.reverse()

    return [
        {
            "id": conversation.id,
            "role": conversation.role,
            "content": conversation.content,
            "created_at": (
                conversation.created_at.isoformat()
                if conversation.created_at
                else None
            ),
        }
        for conversation in conversations
    ]


def delete_conversation(
    db: Session,
    user_id: int,
    conversation_id: int,
) -> bool:
    conversation = db.scalar(
        select(Conversation).where(
            Conversation.id == conversation_id,
            Conversation.user_id == user_id,
        )
    )

    if not conversation:
        return False

    db.delete(conversation)
    db.commit()

    return True


def delete_chat_session(
    db: Session,
    user_id: int,
    session_id: int,
) -> bool:
    session = get_chat_session(
        db=db,
        user_id=user_id,
        session_id=session_id,
    )
    if not session:
        return False

    db.delete(session)
    db.commit()
    return True
