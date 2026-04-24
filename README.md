# AuditDump

A PowerShell-based context preparation tool for LLM-assisted code auditing on .NET / Clean Architecture projects.

Contributions welcome.

---

## AuditDump.ps1

A PowerShell script that pre-organizes a .NET project's source code into structured
Markdown files by architectural layer, ready to be consumed by any LLM agent for
code auditing, gap analysis, or architecture review.

### The problem it solves

Dumping an entire codebase into an LLM context window is not a strategy — it's noise.
Large projects with migrations, generated files, and build artifacts can easily exceed
200k-500k tokens, degrading the model's attention and producing lower quality output.

This script solves that by generating a clean, structured context dump that:

- Excludes build artifacts (obj, bin, Migrations, node_modules)
- Organizes files by architectural layer (Domain, Application, Infrastructure, API, Tests, Crosscutting)
- Embeds an Audit Prompt directly in the tree file, ready to paste into any agent
- Produces reusable artifacts that remain valid across multiple sessions

Estimated token reduction: **40-60%** compared to raw full-project dumps.

### Agent agnostic

The script is completely decoupled from any specific LLM or IDE.
Claude, Gemini CLI, GitHub Copilot, Cursor, GPT-4 via API — any model benefits
from receiving structured context instead of raw unorganized code.

Since context preparation is a **deterministic process** — always producing the same
structured output for the same codebase — the agent receives exactly what it needs,
without relying on autonomous file exploration decisions that frequently produce
partial or biased project views.

> The quality improvement does not come from the agent.  
> It comes from giving the agent context without noise.  
> Any model improves with better input.

### Output files

| File | Contents |
|------|----------|
| `00_tree.md` | Full file tree + Context table + Audit Prompt |
| `01_domain.md` | Entities, Value Objects, Domain Events, Domain interfaces |
| `02_application.md` | Commands, Queries, Handlers, DTOs, Validators, Mappers |
| `03_infrastructure.md` | DbContext, Repositories, EF Configurations, appsettings |
| `04_api.md` | Controllers, Endpoints, Middleware, Program.cs, Blazor components |
| `05_tests.md` | Tests, Fixtures, Mocks, Builders |
| `06_crosscutting.md` | Extensions, Helpers, Result, Guard, Settings |

Output directory: `<ParentOfProjectRoot>\_AuditDump\<ProjectName>\`

### Requirements

- Windows PowerShell 5.1+ or PowerShell 7+
- .NET project under Clean Architecture (standard naming conventions)

### Usage

```powershell
# Basic usage
.\AuditDump.ps1 -ProjectRoot "C:\Development\Antigravity\Hualco.Comex"

# Custom output directory
.\AuditDump.ps1 -ProjectRoot "C:\Development\Antigravity\Hualco.Cargo" -OutputDir "D:\Audits\Cargo"

# If execution policy blocks the script
PowerShell -ExecutionPolicy Bypass -File ".\AuditDump.ps1" -ProjectRoot "C:\Development\MyProject"

# Enable script execution permanently for current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Audit workflow

Once the dump is generated:

1. Upload `00_tree.md` to your LLM agent of choice
2. The embedded Audit Prompt instructs the agent to analyze the structure and request layers in order of architectural risk
3. Upload layer files as requested by the agent
4. Receive a structured gap report in GAP-XXX format

### Gap report format

The embedded prompt instructs the agent to produce output in this format:

```
GAP-001 - [Title]
- Type: Functional | Technical | Architectural | Security | Performance
- Severity: Critical | High | Medium | Low
- Layer: Domain | Application | Infrastructure | API | Crosscutting
- Description: What is missing or incorrectly implemented
- Impact: Concrete consequence if not resolved
- Recommendation: Specific corrective action
```

### Supported file types

`.cs` `.csproj` `.json` `.yaml` `.yml` `.sql` `.js` `.ts` `.razor` `.html` `.css` `.scss` `.xml` `.props` `.targets`

### Known limitations

- Layer detection is heuristic, based on standard Clean Architecture naming conventions.
  Files with non-conventional names may not be captured by layer patterns and will
  only appear in `00_tree.md`.
- Designed for .NET / C# projects. Other stacks require adjusting the `-Include` extensions
  and layer detection patterns.
- Monorepo structures with multiple solutions may mix projects in the same dump.

### Contributing

Found a naming pattern that should be captured? A layer that needs a new file type?
PRs and issues are welcome.

---

## License

MIT

