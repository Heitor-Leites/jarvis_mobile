from database.connection import SessionLocal
from memory.manager import save_memory, get_memories


db = SessionLocal()

try:
    memory = save_memory(
        db=db,
        content="O projeto do usuário se chama JARVIS Mobile.",
        category="projects",
        importance=5,
    )

    print()
    print("MEMÓRIA SALVA")
    print(f"ID: {memory.id}")
    print(f"Conteúdo: {memory.content}")
    print(f"Categoria: {memory.category}")
    print(f"Importância: {memory.importance}")

    print()
    print("MEMÓRIAS ENCONTRADAS:")

    memories = get_memories(db)

    for item in memories:
        print(
            f"[{item.id}] "
            f"{item.content} "
            f"| categoria={item.category} "
            f"| importância={item.importance}"
        )

finally:
    db.close()