# Claude Agents

Коллекция AI-агентов и команд для [Claude Code](https://claude.ai/claude-code), автоматизирующих workflow разработки: от анализа задач до реализации.

## Что это?

Набор специализированных агентов, которые превращают Claude Code в полноценного члена команды разработки:

| Агент | Назначение |
|-------|------------|
| `task-quality-reviewer` | Проверяет качество описания задач в Jira для PM и маркетинга |
| `pre-refinement-task-analyzer` | Технический анализ задач перед refinement — план реализации, оценка |
| `execute-task` | Выполняет задачу по готовому плану из pre-refinement |

## Возможности

- **Интеграция с Jira** — чтение задач, комментарии с анализом
- **Анализ Figma** — извлечение спецификаций дизайна
- **Анализ кода через GitHub API** — поиск существующих паттернов без клонирования
- **Автоматический daily-анализ** — cron-скрипт для задач в статусе Refinement

## Структура проекта

```
claude-agents/
├── .claude/
│   ├── agents/                    # Определения агентов
│   │   ├── pre-refinement-task-analyzer.md
│   │   └── task-quality-reviewer.md
│   └── commands/                  # Slash-команды
│       ├── execute-task.md
│       ├── review-task.md
│       └── sync-patterns.md
├── scripts/                       # Автоматизация
│   ├── daily-pre-refinement.sh   # Ежедневный анализ задач
│   ├── review-task.sh
│   └── sync-patterns.sh
├── docs/                          # Документация
│   └── component-patterns.md     # Паттерны компонентов
└── logs/                          # Логи выполнения
```

## Быстрый старт

### Требования

- [Claude Code CLI](https://claude.ai/claude-code)
- GitHub CLI (`gh`) с авторизацией
- MCP серверы: Atlassian, Figma (опционально: Grafana)

### Настройка MCP

Создайте `.mcp.json` в корне проекта:

```json
{
  "mcpServers": {
    "atlassian": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.atlassian.com/v1/sse"]
    },
    "figma": {
      "command": "npx",
      "args": ["-y", "figma-developer-mcp"],
      "env": {
        "FIGMA_API_KEY": "your-figma-api-key"
      }
    }
  }
}
```

### Использование

**Проверка качества задачи:**
```bash
claude "/review-task PROJ-123"
```

**Технический pre-refinement:**
```bash
claude --agent pre-refinement-task-analyzer "Analyze PROJ-123"
```

**Выполнение задачи:**
```bash
claude "/execute-task PROJ-123"
```

**Автоматический ежедневный анализ:**
```bash
./scripts/daily-pre-refinement.sh
```

## Workflow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  PM создает     │     │  Технический    │     │  Разработчик    │
│  задачу в Jira  │────▶│  pre-refinement │────▶│  реализует      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                      │                       │
         ▼                      ▼                       ▼
   /review-task          агент analyzer           /execute-task
   (качество)            (план + оценка)          (реализация)
```

1. **Review** — агент проверяет задачу на полноту, задает вопросы PM
2. **Pre-refinement** — технический анализ: план, файлы, оценка часов
3. **Execute** — реализация по плану с учетом Figma и CLAUDE.md

## Агенты

### task-quality-reviewer

Помогает PM и маркетингу писать понятные задачи:
- Проверяет Figma на наличие всех состояний
- Анализирует код для понимания контекста
- Пишет review БЕЗ технического жаргона
- Задает конкретные вопросы о требованиях

### pre-refinement-task-analyzer

Технический анализ для разработчиков:
- Gap-анализ: что есть vs что нужно
- Поиск существующих компонентов
- План реализации по фазам
- Оценка трудозатрат с/без AI

### execute-task

Выполнение задачи:
- Чтение плана из pre-refinement комментария
- Создание веток в нужных репозиториях
- Следование CLAUDE.md guidelines
- Реализация по Figma спецификациям

## Cron-автоматизация

Для ежедневного анализа задач в Refinement:

```bash
# Добавить в crontab
0 9 * * 1-5 /path/to/claude-agents/scripts/daily-pre-refinement.sh
```

Скрипт:
1. Находит задачи в статусе Refinement
2. Фильтрует те, что еще не проанализированы
3. Запускает агент для каждой задачи
4. Пишет логи в `logs/`

## Конфигурация

### Переменные окружения

```bash
# .env
FIGMA_ACCESS_TOKEN=your-token
```

### Jira Cloud ID

Найдите в настройках Jira или через API. Используется во всех агентах.

## Логи

Все запуски логируются в `logs/`:
- `pre-refinement-YYYY-MM-DD.log` — ежедневный анализ
- `filter-output.txt` — результат фильтрации задач

---

*Создано для автоматизации workflow разработки с помощью Claude Code*