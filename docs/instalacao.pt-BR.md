# Guia de Instalação e Sincronização

Este guia detalha como instalar, sincronizar, verificar atualizações e efetuar rollback de skills, ferramentas e agentes deste repositório nos ambientes de IA suportados.

*Consulte a versão principal em [Inglês](./installation.md).*

---

## 1. Ambientes Suportados e Escopos de Descoberta

Os artefatos seguem a especificação aberta [Agent Skills Specification](https://agentskills.io/specification). Cada cliente descobre skills e personas em locais padronizados conforme o sistema operacional:

| Cliente / Ambiente | Escopo | Caminho no Linux e macOS | Caminho no Windows (`$env:USERPROFILE`) | Tipo de Link | Exige Reinício de Sessão? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Claude Code** | Skills Globais | `~/.claude/skills/<nome-da-skill>/` | `.claude\skills\<nome-da-skill>\` | Symlink / Junção | **Sim** — Reiniciar o terminal do Claude Code |
| **Claude Code** | Agentes Globais | `~/.claude/agents/<nome-do-agente>.md` | `.claude\agents\<nome-do-agente>.md` | Cópia compilada | **Sim** — Registro de agentes é congelado no boot |
| **OpenAI Codex** | Skills Globais | `~/.codex/skills/<nome-da-skill>/` | `.codex\skills\<nome-da-skill>\` | Symlink / Junção | Não — Descoberto no próximo turno |
| **Google Antigravity** | Skills Globais | `~/.gemini/config/skills/<nome-da-skill>/` (App/CLI)<br>`~/.gemini/antigravity/skills/<nome-da-skill>/` (IDE) | `.gemini\config\skills\<nome-da-skill>\`<br>`.gemini\antigravity\skills\<nome-da-skill>\` | Symlink / Junção | Não — Hot-reload dinâmico |
| **Cursor** | Skills Globais | `~/.cursor/skills/<nome-da-skill>/` | `.cursor\skills\<nome-da-skill>\` | Symlink / Junção | Não — Leitura instantânea via symlink |
| **Cursor** | Agentes Globais | `~/.cursor/agents/<nome-do-agente>.md` | `.cursor\agents\<nome-do-agente>.md` | Symlink / Cópia | Não — Leitura instantânea via symlink |

### Matriz de Compatibilidade por Sistema Operacional

- **Linux**: Totalmente nativo com links simbólicos POSIX (`ln -sfn`). Suportado via `./tools/sync-skills.sh` e `./tools/build-agents.sh`.
- **macOS (Darwin)**: Totalmente nativo com links simbólicos POSIX (`ln -sfn`). Compatível out-of-the-box no Terminal / Zsh / Bash via `./tools/sync-skills.sh` e `./tools/build-agents.sh`. Os caminhos resolvem sob `/Users/<usuario>/`.
- **Windows (PowerShell Nativo)**: Totalmente suportado via `.\tools\sync-skills.ps1` e `.\tools\build-agents.ps1`. Caso o Modo Desenvolvedor do Windows esteja desativado ou o PowerShell esteja sem privilégios de Administrador, o script recorre automaticamente a **Junções NTFS de Diretório** (`Junctions`), que dispensam privilégios elevados.
- **Windows (Git Bash / WSL)**: Suportado via `./tools/sync-skills.sh` e `./tools/build-agents.sh` (o Git Bash requer Modo Desenvolvedor ativado ou permissão de Administrador para criar symlinks NTFS).

---

## 2. Pré-requisitos

- **Git** (versão 2.20+)
- **Para Linux e macOS (ou Windows via Git Bash / WSL)**:
  - **Bash** e **Perl** (ferramentas padrão POSIX para execução de `sync-skills.sh` e compilação de `build-agents.sh`)
- **Para Windows Nativo**:
  - **PowerShell 5.1+** ou **PowerShell Core (pwsh)** (sem necessidade de instalar ferramentas adicionais)
- **Ferramentas Opcionais**:
  - **GitHub CLI (`gh`)** (recomendado para publicação automatizada de PRs pelo `release-manager`)
  - **Node.js 18+** (necessário apenas para rodar scripts de validação de catálogo e CI)

---

## 3. Métodos de Instalação

### Método A: Checkout Local Canônico e Ferramentas de Sincronização (Documentado e Testado)

Recomendado para usuários que operam múltiplos ambientes na mesma máquina.

1. **Clonar o repositório**:
   ```bash
   git clone https://github.com/aleemerich/resources-generative-ai.git ~/.local/share/resources-generative-ai
   cd ~/.local/share/resources-generative-ai
   ```

2. **Executar as ferramentas de sincronização conforme o seu sistema**:

   **No Linux / macOS (ou Windows via Git Bash / WSL):**
   ```bash
   # Sincroniza todas as skills estáveis (stable) nos ambientes globais detectados
   ./tools/sync-skills.sh

   # Compila e sincroniza os subagentes para Cursor e Claude Code
   ./tools/build-agents.sh
   ```

   **No Windows (PowerShell Nativo):**
   ```powershell
   # Sincroniza skills usando symlinks ou junções NTFS sem exigir privilégios elevados
   .\tools\sync-skills.ps1

   # Sincroniza agentes para Cursor e Claude Code
   .\tools\build-agents.ps1
   ```

3. **Instalação seletiva por cliente**:
   ```bash
   # Linux / macOS / Git Bash
   ./tools/sync-skills.sh --client claude

   # Windows PowerShell
   .\tools\sync-skills.ps1 -Client claude
   ```

### Método B: Instalação Assistida por LLM (Documentado e Testado)

Você pode instruir seu próprio assistente de IA a configurar as skills. Copie e envie o prompt abaixo:

```markdown
Você está me auxiliando a instalar skills do repositório público:
https://github.com/aleemerich/resources-generative-ai

Por favor, execute as seguintes etapas:
1. Detecte meu ambiente atual de assistente de IA (Claude Code, Cursor, Codex ou Antigravity) e sistema operacional.
2. Clone este repositório em `~/.local/share/resources-generative-ai` (ou execute `git pull` se já existir).
   - Caso esteja em um ambiente sem acesso direto ao terminal, consulte o manifesto em:
     https://raw.githubusercontent.com/aleemerich/resources-generative-ai/main/catalog.json
     e baixe os arquivos necessários a partir de `https://raw.githubusercontent.com/aleemerich/resources-generative-ai/main/`.
3. Crie os links simbólicos das skills estáveis para o diretório de descoberta do meu ambiente:
   - No Windows (PowerShell): execute `.\tools\sync-skills.ps1` (e `.\tools\build-agents.ps1` para subagentes).
   - No Linux / macOS / Git Bash: execute `./tools/sync-skills.sh` (e `./tools/build-agents.sh` para subagentes).
   - Caso esteja em ambiente sem terminal, salve os arquivos baixados diretamente na pasta de skills do meu ambiente.
4. Informe exatamente quais skills e agentes foram instalados, suas respectivas versões do catalog.json e se é necessário reiniciar a sessão do assistente.
```

### Método C: Integração via Vercel Skills CLI (*Planejado / Implementação Futura*)

> [!NOTE]
> *Status: Planejado / Implementação Futura*. Este método requer indexação prévia no catálogo central do CLI `skills`.

```bash
# Comando planejado (ainda não ativo no registro central upstream)
npx skills add aleemerich/resources-generative-ai --skill to-the-point
```

---

## 4. Verificação da Instalação

Após instalar, confirme que o cliente reconhece as novas capacidades:

1. **No Claude Code**:
   Reinicie o terminal e digite `/` no prompt. Você verá `/factual-writer`, `/to-the-point` e `/taskforce` listados.
2. **No Cursor**:
   Abra a barra de chat e digite `@skills` ou acione o comando correspondente (ex: `/to-the-point` ou `/taskforce`).
3. **No OpenAI Codex**:
   Verifique as skills vinculadas em `~/.codex/skills/` ou solicite ao modelo que liste as capacidades ativas.
4. **No Google Antigravity**:
   Verifique as skills disponíveis na lista de ferramentas da sessão ou invoque diretamente.

---

## 5. Atualizações, Fixação de Versão e Rollback

### Verificando Novas Versões
```bash
cd ~/.local/share/resources-generative-ai
git fetch origin
git log HEAD..origin/main --oneline
```

### Atualizando para a Última Versão Estável
```bash
cd ~/.local/share/resources-generative-ai
git pull origin main
./tools/sync-skills.sh
./tools/build-agents.sh
```

### Fixando uma Release Específica (Pinning)
Para evitar que alterações futuras quebrem automações locais:
```bash
cd ~/.local/share/resources-generative-ai
git checkout v1.0.0
./tools/sync-skills.sh --force
./tools/build-agents.sh
```

### Procedimento de Rollback
Caso uma nova versão apresente incompatibilidade:
```bash
cd ~/.local/share/resources-generative-ai
git checkout HEAD~1
./tools/sync-skills.sh --force
./tools/build-agents.sh
```
*Lembre-se de reiniciar o Claude Code caso esteja utilizando esse cliente.*

---

## 6. Desinstalação

### Opção 1: Desinstalação Segura Automatizada (Recomendada)
Remove apenas os links e junções que apontam comprovadamente para este repositório, preservando arquivos pessoais ou de outros projetos:

```bash
# Linux / macOS / Git Bash:
./tools/sync-skills.sh --clean

# Windows PowerShell:
.\tools\sync-skills.ps1 -Clean
```

### Opção 2: Remoção Manual
Para desvincular uma skill manualmente sem risco de apagar arquivos de terceiros, confirme se o arquivo é de fato um link simbólico antes de remover:

```bash
# Linux / macOS / Git Bash (remove apenas se for link simbólico):
[ -L ~/.claude/skills/factual-writer ] && rm ~/.claude/skills/factual-writer
[ -L ~/.cursor/skills/factual-writer ] && rm ~/.cursor/skills/factual-writer
[ -L ~/.codex/skills/factual-writer ] && rm ~/.codex/skills/factual-writer
[ -L ~/.gemini/config/skills/factual-writer ] && rm ~/.gemini/config/skills/factual-writer
```

```powershell
# Windows PowerShell (remove apenas se for ReparsePoint / Link simbólico):
Get-Item "$HOME\.claude\skills\factual-writer" -ErrorAction SilentlyContinue | Where-Object { $_.LinkType } | ForEach-Object { $_.Delete() }
```

---

## 7. Solução de Problemas

| Sintoma | Causa Provável | Solução |
| :--- | :--- | :--- |
| A skill não aparece no Claude Code | O Claude congela o registro de skills na inicialização | Reinicie completamente o Claude Code (`exit` e reabra) |
| Agentes não aparecem no Claude Code | O script `build-agents.sh` não foi executado ou sessão não foi reiniciada | Execute `./tools/build-agents.sh` e reinicie a sessão do Claude Code |
| Link simbólico quebrado | O clone local do repositório foi movido de pasta | Reexecute `./tools/sync-skills.sh` para reconstruir os links |
| Erro de permissão em symlinks no Windows | Modo Desenvolvedor desativado no Windows | Utilize o script PowerShell nativo (`.\tools\sync-skills.ps1`), que recorre automaticamente a junções NTFS sem exigir privilégios de Administrador, ou ative o Modo Desenvolvedor nas configurações do Windows |
| O modelo ignora as regras da skill | Prompt ambíguo ou múltiplos modos conflitantes ativos | Acione a skill explicitamente pelo comando slash (ex: `/factual-writer`) |

