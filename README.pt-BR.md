# Recursos de IA Generativa

Um repositório público, padronizado e agnóstico de fornecedor contendo recursos prontos para produção com agentes de IA: Agent Skills, fluxos multi-agente, lentes de revisão e diretrizes operacionais em total conformidade com a [Especificação Agent Skills](https://agentskills.io/specification).

*Consulte a versão principal em [Inglês](./README.md).*

---

## Visão Geral

Este repositório fornece capacidades modulares desenvolvidas para potencializar assistentes de código e agentes modernos (incluindo Claude Code, OpenAI Codex, Cursor e Google Antigravity). Em vez de sobrecarregar as janelas de contexto com system prompts estáticos gigantescos, esses recursos operam por **divulgação progressiva** (*progressive disclosure*): metadados leves são registrados na inicialização e o corpo detalhado de instruções só é carregado sob demanda quando a tarefa exigir.

---

## Estrutura de Diretórios e Estados de Ciclo de Vida

Os artefatos estão organizados por ciclo de vida em todas as categorias de recursos para IA (`skills`, `agents`, `hooks`, `rules`):

```text
├── stable/              # Artefatos consolidados e validados em produção (Distribuição padrão)
│   ├── skills/          # Agent Skills universais (SKILL.md)
│   ├── agents/          # Definições canônicas de subagentes autônomos (taskforce)
│   ├── hooks/           # Gatilhos de ciclo de vida e automação
│   └── rules/           # Regras de contexto de sistema para IAs
├── experimental/        # Incubação e validação de novas capacidades
│   ├── skills/
│   ├── agents/
│   ├── hooks/
│   └── rules/
├── deprecated/          # Artefatos em ciclo de descontinuação (janela de migração)
│   ├── skills/
│   ├── agents/
│   ├── hooks/
│   └── rules/
├── tools/               # Utilitários de sincronização, compilação de personas e validação de CI
└── docs/                # Manuais bilíngues de instalação, sincronização e manutenção
```

- **`stable/`**: Distribuído por padrão. Zero dependências corporativas externas, comportamento verificado e cobertura rigorosa contra regressões.
- **`experimental/`**: Espaço de incubação para prototipagem e testes de novas skills, agentes, hooks e regras antes da promoção.
- **`deprecated/`**: Artefatos obsoletos preservados temporariamente para evitar quebras em fluxos existentes.
- **`tools/`**: Scripts de automação para sincronizar skills (`sync-skills.sh`), compilar agentes (`build-agents.sh`) e validar integridade (`validate-catalog.js`).

---

## Catálogo de Skills Estáveis

| Skill | Categoria | Descrição | Gatilhos Principais |
| :--- | :--- | :--- | :--- |
| **[`factual-writer`](./stable/skills/factual-writer/)** | Escrita / Qualidade | Impõe prosa factual, direta e concisa. Zero adjetivos superlativos, zero travessões, sem enrolação, precisão de dados e narrativa estruturada ("descascar a cebola"). Modo duplo: escrita e revisão automatizada. | `/factual-writer`, relatórios de investigação, post-mortems, RFCs |
| **[`to-the-point`](./stable/skills/to-the-point/)** | Produtividade / Saída | Saída orientada à ação prioritária (*action-first*) desenhada para leitores com TDAH. Começa com código/comando executável na primeira linha, numera passos (máximo 5) e suprime saudações e enrolações. | `/to-the-point`, `/direto-ao-ponto`, modo TDAH |
| **[`communication-style`](./stable/skills/communication-style/)** | Escrita / Voz (PT-BR) | Estilo de comunicação natural em Português do Brasil: voz ativa, respostas diretas, clareza e eliminação de clichês e jargões vazios de IA. | Respostas de chat, documentações técnicas |
| **[`technical-explanation-style`](./stable/skills/technical-explanation-style/)** | Código / Arquitetura (PT-BR) | Sete regras fundamentais e duas passadas de revisão (ideia e varredura mecânica) para explicar código a quem não está com o repositório aberto. | Explicação de código, PR descriptions, diffs |
| **[`post-change-cleanup-review`](./stable/skills/post-change-cleanup-review/)** | Higiene de Código | Checklist pós-modificação para detectar código morto, duplicações, comentários obsoletos e vazamento de código de teste em produção. | Revisão pós-refatoração, conferência pré-commit |
| **[`post-change-tests-review`](./stable/skills/post-change-tests-review/)** | Testes / QA | Avaliação sistemática de suítes de teste após mudanças de código (tabela de relevância, duplicações, compatibilidade de schemas e lacunas de cobertura). | Manutenção de testes, ciclos TDD |
| **[`project-context-file`](./stable/skills/project-context-file/)** | Ferramentas / Onboarding | Criação e manutenção do padrão de mercado `AGENTS.md` (<150 linhas) baseado nos princípios *Toolchain First* e *Limites de Julgamento* (NEVER / ASK / ALWAYS). | Geração de `AGENTS.md`, onboarding de agentes |
| **[`taskforce`](./stable/skills/taskforce/)** | Orquestração Multi-Agente | Orquestra um time de engenharia autônomo (analista, arquiteto, implementador, revisor, release-manager) com TDD e revisões independentes. | `/taskforce`, features, refatorações, investigações |

---

## Início Rápido e Instalação

### Opção 1: Sincronização Automática Multi-Ambiente (Recomendada)

1. Clone o repositório em sua máquina:
   ```bash
   git clone https://github.com/aleemerich/resources-generative-ai.git ~/.local/share/resources-generative-ai
   cd ~/.local/share/resources-generative-ai
   ```

2. Execute o assistente de sincronização para o seu sistema operacional:

   **Linux / macOS / Windows (Git Bash ou WSL):**
   ```bash
   ./tools/sync-skills.sh
   ./tools/build-agents.sh
   ```

   **Windows (PowerShell Nativo):**
   ```powershell
   .\tools\sync-skills.ps1
   .\tools\build-agents.ps1
   ```

   *Os scripts detectam automaticamente os clientes suportados instalados (Claude Code, Cursor, Codex, Antigravity) e criam links simbólicos seguros sem sobrescrever personalizações locais. No Windows, o script `sync-skills.ps1` recorre automaticamente a junções NTFS caso o Modo Desenvolvedor esteja desativado, dispensando privilégios de Administrador.*

### Opção 2: Instalação Assistida por LLM

Envie o prompt abaixo para o seu assistente de programação (Claude Code, Cursor, Codex ou Antigravity):

> "Você está me ajudando a instalar skills e subagentes a partir do repositório público: `https://github.com/aleemerich/resources-generative-ai`.
> 1. Detecte meu ambiente atual de assistente de IA (Claude Code, Cursor, Codex ou Antigravity) e sistema operacional.
> 2. Clone este repositório em `~/.local/share/resources-generative-ai` (ou execute `git pull` se já existir).
> 3. Execute as ferramentas de sincronização adequadas para o meu sistema operacional:
>    - No Windows (PowerShell): execute `.\tools\sync-skills.ps1` (e `.\tools\build-agents.ps1` para subagentes).
>    - No Linux / macOS / Git Bash: execute `./tools/sync-skills.sh` (e `./tools/build-agents.sh` para subagentes).
>    - Caso esteja em um ambiente sem terminal, leia `catalog.json` e baixe os arquivos de cada skill diretamente de `https://raw.githubusercontent.com/aleemerich/resources-generative-ai/main/<entryFile>` para a pasta de skills do meu ambiente.
> 4. Me informe quais skills e agentes foram instalados, suas versões em `catalog.json` e se é necessário reiniciar a sessão."

Para instruções detalhadas de configuração manual, veja o **[Guia de Instalação](./docs/instalacao.pt-BR.md)**.

---

## Versionamento e Atualizações

O repositório mantém versionamento semântico (`MAJOR.MINOR.PATCH`) independente por artefato, declarado no arquivo central `catalog.json`.

- **Verificar atualizações disponíveis**:
  ```bash
  cd ~/.local/share/resources-generative-ai
  git pull origin main
  ./tools/sync-skills.sh --check
  ```
- **Fixar uma versão estável**:
  ```bash
  git checkout v1.0.0
  ./tools/sync-skills.sh --force
  ```
- **Desfazer atualização (Rollback)**:
  ```bash
  git checkout HEAD~1
  ./tools/sync-skills.sh --force
  ```

---

## Contribuição e Governança

Contribuições são muito bem-vindas! Consulte o nosso **[Guia de Manutenção e Governança](./docs/manutencao.pt-BR.md)** para entender:
- Como adicionar novas skills em conformidade com a especificação Agent Skills.
- Validação automatizada via `node tools/validate-catalog.js`.
- Critérios de promoção entre os canais `experimental/`, `stable/` e `deprecated/`.

---

## Licença

Exceto quando especificado em contrário em subdiretórios de artefatos específicos, todo o conteúdo original é disponibilizado sob a **[Licença MIT](./LICENSE)**. Componentes de terceiros preservam sua licença e autoria de origem (exemplo: `to-the-point`, licenciado sob MIT por Ayoub Ghriss).

