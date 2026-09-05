from sqlalchemy import select
from sqlalchemy.orm import Session

from database.models import Memory


def create_memory(
    db: Session,
    user_id: int,
    content: str,
    category: str = "general",
    importance: int = 1,
) -> Memory:
    content = content.strip()

    if not content:
        raise ValueError(
            "A memória não pode estar vazia."
        )

    if importance < 1:
        importance = 1

    if importance > 5:
        importance = 5

    existing = db.scalar(
        select(Memory).where(
            Memory.user_id == user_id,
            Memory.content == content,
        )
    )

    if existing:
        return existing

    memory = Memory(
        user_id=user_id,
        content=content,
        category=category,
        importance=importance,
    )

    db.add(memory)
    db.commit()
    db.refresh(memory)

    return memory


def save_memory(
    db: Session,
    user_id: int,
    content: str,
    category: str = "general",
    importance: int = 1,
) -> Memory:
    return create_memory(
        db=db,
        user_id=user_id,
        content=content,
        category=category,
        importance=importance,
    )


def get_memories(
    db: Session,
    user_id: int,
    limit: int = 20,
) -> list[dict]:
    statement = (
        select(Memory)
        .where(
            Memory.user_id == user_id
        )
        .order_by(
            Memory.importance.desc(),
            Memory.created_at.desc(),
        )
        .limit(limit)
    )

    memories = list(
        db.scalars(statement).all()
    )

    return [
        {
            "id": memory.id,
            "content": memory.content,
            "category": memory.category,
            "importance": memory.importance,
            "created_at": (
                memory.created_at.isoformat()
                if memory.created_at
                else None
            ),
        }
        for memory in memories
    ]


def delete_memory(
    db: Session,
    user_id: int,
    memory_id: int,
) -> bool:
    memory = db.scalar(
        select(Memory).where(
            Memory.id == memory_id,
            Memory.user_id == user_id,
        )
    )

    if not memory:
        return False

    db.delete(memory)
    db.commit()

    return True


def detect_memory(
    message: str,
) -> tuple[str, str, int] | None:
    text = message.strip()

    if not text:
        return None

    lowered = text.lower()

    triggers = [
        "lembre que ",
        "lembre-se que ",
        "guarde que ",
        "salve que ",
        "memorize que ",
        "quero que você lembre que ",
    ]

    matched_trigger = None

    for trigger in triggers:
        if lowered.startswith(trigger):
            matched_trigger = trigger
            break

    if not matched_trigger:
        return None

    content = text[len(matched_trigger):].strip()

    if not content:
        return None

    category = "general"
    importance = 3

    if any(
        word in lowered
        for word in [
            "projeto",
            "jarvis",
            "aplicativo",
            "site",
        ]
    ):
        category = "projects"
        importance = 5

    elif any(
        word in lowered
        for word in [
            "meu nome",
            "me chamo",
            "meu gosto",
            "eu gosto",
            "prefiro",
        ]
    ):
        category = "preferences"
        importance = 5

    return content, category, importance