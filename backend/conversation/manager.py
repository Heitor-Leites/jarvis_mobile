from sqlalchemy import select
from sqlalchemy.orm import Session

from database.models import Conversation


def save_message(
    db: Session,
    user_id: int,
    role: str,
    content: str,
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
        role=role,
        content=content,
    )

    db.add(conversation)
    db.commit()
    db.refresh(conversation)

    return conversation


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