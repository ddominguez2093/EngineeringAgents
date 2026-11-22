#!/usr/bin/env bash
#
# Instala engineering-agentic-flow en un repo para usarlo con Antigravity (ademas de
# Claude Code). Genera, a partir del plugin, lo que Antigravity lee:
#
#   .agents/agents/*.md        subagentes (scout, planner, coder, ...)
#   .agents/skills/*/SKILL.md  skills por stack + /eng-flow, /eng-resume, /eng-context, ...
#   .agents/rules/*.md         tus reglas de .claude/rules, con el `trigger` que Antigravity exige
#   .agents/hooks.json         guardrail de seguridad + tus hooks PreToolUse de .claude/settings.json
#   .agentflow/                scripts (verify, scan, graph, state, version) y hooks
#   AGENTS.md                  bloque con el flujo; incluye CLAUDE.md si existe
#
# Es idempotente: vuelve a correrlo despues de actualizar el plugin.
#
#   sync-antigravity.sh [--dry-run] [<ruta del repo>]     (por defecto, el directorio actual)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../plugins/engineering-agentic-flow" && pwd)"

PY=""
for p in python3 python py; do
  if command -v "$p" >/dev/null 2>&1 && "$p" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1; then
    PY="$p"; break
  fi
done
[ -n "$PY" ] || { echo "sync-antigravity: falta Python 3" >&2; exit 4; }

exec "$PY" -I - "$PLUGIN_DIR" "$@" <<'PYEOF'
import json, os, re, shlex, shutil, stat, subprocess, sys
from datetime import datetime, timezone

plugin = os.path.abspath(sys.argv[1])
# Ruta del plugin tal como la ve la maquina donde se usaran los skills (si el sync corre
# en otro entorno, por ejemplo una VM): AGENTFLOW_PLUGIN_PATH.
plugin_shown = os.environ.get("AGENTFLOW_PLUGIN_PATH") or plugin
args = sys.argv[2:]
dry = "--dry-run" in args
paths = [a for a in args if not a.startswith("--")]
target = os.path.abspath(paths[0] if paths else os.getcwd())
if not os.path.isdir(target):
    sys.exit("sync-antigravity: no existe la carpeta " + target)

actions = []
def say(kind, path):
    actions.append((kind, os.path.relpath(path, target)))

def write(path, content, mode=None):
    say("escribe", path)
    if dry:
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)
    if mode:
        os.chmod(path, mode)

def copy_file(src, dst, exe=False):
    say("copia", dst)
    if dry:
        return
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copyfile(src, dst)
    if exe:
        os.chmod(dst, os.stat(dst).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

def copy_tree(src, dst):
    say("copia", dst + "/")
    if dry:
        return
    # Se sobrescribe en sitio (sin borrar antes): funciona aunque la carpeta no permita borrar.
    shutil.copytree(src, dst, dirs_exist_ok=True, ignore=shutil.ignore_patterns("__pycache__", "*.pyc", ".DS_Store"))

def split_fm(text):
    if text.startswith("---\n"):
        end = text.find("\n---", 4)
        if end != -1:
            return text[4:end], text[end + 4:].lstrip("\n")
    return "", text

def parse_fm(fm):
    d, key = {}, None
    for line in fm.splitlines():
        m = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if m:
            key = m.group(1); d[key] = m.group(2).strip()
        elif key and re.match(r"^\s+-\s+", line):
            d[key] = (d[key] + "\n" if d[key] else "") + re.sub(r"^\s+-\s+", "", line).strip()
    return d

def unquote(v):
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        return v[1:-1]
    return v

def as_list(v):
    v = v.strip()
    if v.startswith("["):
        try:
            return [str(x) for x in json.loads(v)]
        except Exception:
            return [unquote(x) for x in v.strip("[]").split(",") if x.strip()]
    return [unquote(x) for x in re.split(r"[\n,]", v) if x.strip()]

# ---------------------------------------------------------------- plugin meta
try:
    plugin_version = json.load(open(os.path.join(plugin, ".claude-plugin", "plugin.json")))["version"]
except Exception:
    plugin_version = "?"
try:
    source_commit = subprocess.run(["git", "-C", plugin, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
except Exception:
    source_commit = ""

# ------------------------------------------------------------ .agentflow/
af = os.path.join(target, ".agentflow")
scripts_dir = os.path.join(plugin, "scripts")
for f in sorted(os.listdir(scripts_dir)):
    if f.endswith(".sh"):
        copy_file(os.path.join(scripts_dir, f), os.path.join(af, f), exe=True)
copy_file(os.path.join(plugin, "security", "semgrep-flutter.yml"), os.path.join(af, "semgrep-flutter.yml"))
for f in ("security-check.sh", "claude-hook-adapter.sh"):
    copy_file(os.path.join(plugin, "hooks", f), os.path.join(af, "hooks", f), exe=True)
if not dry:
    os.makedirs(os.path.join(af, "plans"), exist_ok=True)

# ------------------------------------------------------------- agentes
TOOL_MAP = {
    "Read": ["view_file"], "Grep": ["grep_search"], "Glob": ["find_by_name", "list_dir"],
    "Edit": ["replace_file_content"], "Write": ["write_to_file"], "Bash": ["run_command"], "Skill": [],
}
# Agentes sin `tools:` (planner) heredan todo en Claude Code; aqui solo lo que necesitan:
# leer, buscar, escribir el plan y correr comandos. Sin Edit: no tocan codigo existente.
DEFAULT_TOOLS = "Read, Grep, Glob, Write, Bash"
MODEL_MAP = {"haiku": "flash", "sonnet": "pro", "opus": "pro"}

AGENT_NOTE = (
    "\n\n> **Antigravity.** Los skills viven en `.agents/skills/<nombre>/SKILL.md`: ábrelos con "
    "`view_file` cuando estas instrucciones pidan «cargar» un skill. `.agentflow/` está en la raíz del repo.\n"
)

for f in sorted(os.listdir(os.path.join(plugin, "agents"))):
    if not f.endswith(".md"):
        continue
    text = open(os.path.join(plugin, "agents", f), encoding="utf-8").read()
    fm, body = split_fm(text)
    meta = parse_fm(fm)
    tools = []
    for t in [x.strip() for x in meta.get("tools", DEFAULT_TOOLS).split(",") if x.strip()]:
        for m in TOOL_MAP.get(t, []):
            if m not in tools:
                tools.append(m)
    model = MODEL_MAP.get(meta.get("model", "").strip(), "inherit")
    name = meta.get("name") or f[:-3]
    out = "---\nname: %s\ndescription: %s\ntools:\n%s\nsubagent: true\nmainAgent: false\nmodel: %s\n---\n\n%s%s" % (
        name, json.dumps(unquote(meta.get("description", name)), ensure_ascii=False),
        "\n".join("  - " + t for t in tools), model, body.rstrip("\n"), AGENT_NOTE)
    write(os.path.join(target, ".agents", "agents", f), out)

# --------------------------------------------------------------- skills
skills_out = os.path.join(target, ".agents", "skills")
for d in sorted(os.listdir(os.path.join(plugin, "skills"))):
    src = os.path.join(plugin, "skills", d)
    if os.path.isfile(os.path.join(src, "SKILL.md")):
        copy_tree(src, os.path.join(skills_out, d))
# Skills propios del proyecto (.claude/skills) se copian tal cual.
proj_skills = os.path.join(target, ".claude", "skills")
if os.path.isdir(proj_skills):
    for d in sorted(os.listdir(proj_skills)):
        if os.path.isfile(os.path.join(proj_skills, d, "SKILL.md")):
            copy_tree(os.path.join(proj_skills, d), os.path.join(skills_out, d))

# Comandos -> skills (Antigravity reemplaza los workflows por skills; /nombre los invoca).
CMD_NOTE = """> **Entorno: Antigravity.** Estas instrucciones se escribieron para Claude Code; adáptalas así:
> - Los argumentos son el texto que la persona escribió después de `/{name}`.
> - Subagentes: invócalos por nombre con `invoke_subagent` (están en `.agents/agents/`). Cada
>   agente fija su modelo (`flash` o `pro`); ignora cualquier `model: opus` de abajo.
> - Si no puedes invocar subagentes, haz tú el trabajo del rol siguiendo su archivo y regístralo:
>   `.agentflow/state.sh log <id> <etapa> "sin subagente" antigravity/<modelo>`.
> - Herramientas: Read = `view_file`, Grep = `grep_search`, Bash = `run_command`,
>   Skill = abre `.agents/skills/<nombre>/SKILL.md`.
> - En el estado y el log anota siempre el modelo real: `antigravity/<modelo>`.

"""
for f in sorted(os.listdir(os.path.join(plugin, "commands"))):
    if not f.endswith(".md"):
        continue
    name = f[:-3]
    fm, body = split_fm(open(os.path.join(plugin, "commands", f), encoding="utf-8").read())
    desc = unquote(parse_fm(fm).get("description", name))
    body = body.replace("${CLAUDE_PLUGIN_ROOT}", plugin_shown).replace("$ARGUMENTS", "(lo que escribió la persona tras el comando)")
    out = "---\nname: %s\ndescription: %s\n---\n\n%s%s" % (
        name, json.dumps(desc, ensure_ascii=False), CMD_NOTE.replace("{name}", name), body)
    write(os.path.join(skills_out, name, "SKILL.md"), out)

# ---------------------------------------------------------------- reglas
# Antigravity DESCARTA sin avisar una regla sin `trigger` en el frontmatter.
rules_src = os.path.join(target, ".claude", "rules")
if os.path.isdir(rules_src):
    for f in sorted(os.listdir(rules_src)):
        if not f.endswith(".md"):
            continue
        fm, body = split_fm(open(os.path.join(rules_src, f), encoding="utf-8").read())
        meta = parse_fm(fm)
        heading = next((l.lstrip("# ").strip() for l in body.splitlines() if l.startswith("#")), f[:-3])
        if "paths" in meta:
            globs = ", ".join(as_list(meta["paths"]))
            head = 'trigger: glob\nglobs: %s\ndescription: %s\n' % (json.dumps(globs), json.dumps(heading, ensure_ascii=False))
        else:
            head = "trigger: always_on\n"
        write(os.path.join(target, ".agents", "rules", f), "---\n" + head + "---\n\n" + body)

# ----------------------------------------------------------------- hooks
# La App usa read_file/write_file/edit_file; la documentacion, view_file/write_to_file/replace_file_content. Se cubren ambas.
AG_TOOL = {"Bash": ["run_command"], "Read": ["view_file", "read_file"],
           "Edit": ["replace_file_content", "multi_replace_file_content", "edit_file"],
           "Write": ["write_to_file", "write_file", "create_file"]}
ALL_TOOLS = [t for v in AG_TOOL.values() for t in v]

def hook_entries(matcher, command, timeout=10):
    names = []
    for part in re.split(r"\|", matcher or ""):
        part = part.strip()
        names += AG_TOOL.get(part, [])
    if not matcher or matcher.strip() in ("*", ".*"):
        names = ALL_TOOLS
    # El matcher es una expresion regular: una sola entrada con todas las herramientas.
    return [{"matcher": "|".join(dict.fromkeys(names)), "hooks": [{"type": "command", "command": command, "timeout": timeout}]}]

hooks_path = os.path.join(target, ".agents", "hooks.json")
try:
    hooks = json.load(open(hooks_path)) if os.path.isfile(hooks_path) else {}
except Exception:
    hooks = {}
for k in [k for k in hooks if k.startswith("agentflow-") or k.startswith("claude-")]:
    del hooks[k]
# Rutas absolutas: Antigravity no documenta desde que carpeta corre el comando de un hook.
# AGENTFLOW_TARGET_PATH = ruta del repo tal como la ve tu maquina (si el sync corre en otro entorno).
hook_dir = (os.environ.get("AGENTFLOW_TARGET_PATH") or target).rstrip("/") + "/.agentflow/hooks"
hooks["agentflow-security"] = {"PreToolUse": hook_entries("*", "bash " + shlex.quote(hook_dir + "/security-check.sh"))}
skipped = []
settings_path = os.path.join(target, ".claude", "settings.json")
if os.path.isfile(settings_path):
    try:
        st = json.load(open(settings_path))
    except Exception:
        st = {}
    n = 0
    for event, groups in (st.get("hooks") or {}).items():
        if event != "PreToolUse":
            skipped.append(event); continue
        for g in groups:
            for h in g.get("hooks", []):
                if h.get("type", "command") != "command":
                    continue
                n += 1
                cmd = "bash " + shlex.quote(hook_dir + "/claude-hook-adapter.sh") + " " + shlex.quote(h["command"])
                hooks["claude-%d" % n] = {"PreToolUse": hook_entries(g.get("matcher", ""), cmd, h.get("timeout", 10))}
write(hooks_path, json.dumps(hooks, indent=2, ensure_ascii=False) + "\n")

# -------------------------------------------------------------- AGENTS.md
START, END = "<!-- agentflow:start -->", "<!-- agentflow:end -->"
claude_md = os.path.join(target, "CLAUDE.md")
lines = [START, "## Flujo de agentes (engineering-agentic-flow)"]
if os.path.isfile(claude_md) and not open(claude_md, encoding="utf-8").read().lstrip().startswith("@AGENTS.md"):
    lines.append("")
    lines.append("@[Contexto del proyecto (CLAUDE.md)](CLAUDE.md)")
lines += [
    "",
    "- Skills del flujo: `/eng-flow`, `/eng-resume`, `/eng-context`, `/eng-graph`, `/eng-version`.",
    "- Contexto corto del repo: `.agentflow/context.md` (léelo antes de planear).",
    "- Estado de cada corrida: `.agentflow/state/<id>.state`. Si existe para la tarea, continúa con `/eng-resume`; no empieces de cero.",
    "- El plan y el código son la fuente de verdad: `.agentflow/plans/<id>.md` y git.",
    END, "",
]
block = "\n".join(lines)
agents_md = os.path.join(target, "AGENTS.md")
if os.path.isfile(agents_md):
    cur = open(agents_md, encoding="utf-8").read()
    if START in cur and END in cur:
        new = re.sub(re.escape(START) + r".*?" + re.escape(END) + r"\n?", lambda m: block, cur, flags=re.S)
    else:
        new = cur.rstrip("\n") + "\n\n" + block
else:
    new = "# AGENTS.md\n\n" + block
write(agents_md, new)

# ------------------------------------------------------------- meta + git
write(os.path.join(af, ".sync-meta"),
      "plugin_version=%s\nsource_commit=%s\nsynced_at=%s\nplugin_path=%s\n" % (
          plugin_version, source_commit, datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), plugin_shown))

if not dry:
    try:
        excl = subprocess.run(["git", "-C", target, "rev-parse", "--git-path", "info/exclude"],
                              capture_output=True, text=True, check=True).stdout.strip()
        excl = excl if os.path.isabs(excl) else os.path.join(target, excl)
        os.makedirs(os.path.dirname(excl), exist_ok=True)
        cur = open(excl).read() if os.path.isfile(excl) else ""
        add = [l for l in (".agents/", ".agentflow/state/", ".agentflow/.sync-meta", ".agentflow/hooks/", "graphify-out/") if l not in cur.splitlines()]
        if add:
            open(excl, "a").write(("" if cur.endswith("\n") or not cur else "\n") + "\n".join(add) + "\n")
    except Exception:
        pass

# ---------------------------------------------------------------- resumen
print(("[dry-run] " if dry else "") + "engineering-agentic-flow %s -> %s" % (plugin_version, target))
counts = {}
for kind, p in actions:
    top = ".agents/" + p.split("/")[1] if p.startswith(".agents/") and p.count("/") > 1 else p.split("/")[0]
    counts[top] = counts.get(top, 0) + 1
for k in sorted(counts):
    print("  %-26s %d archivo(s)" % (k, counts[k]))
if skipped:
    print("  Hooks de Claude NO convertidos (solo PreToolUse se traduce): " + ", ".join(sorted(set(skipped))))
print("""
Falta, a mano (no se puede automatizar):
  1. Jira: agrega el MCP de Atlassian en Antigravity (su gestor de MCP). Sin él, usa /eng-flow con texto libre.
  2. Permisos de shell: los agentes corren comandos con tu politica de Antigravity (commandExecutionPolicy);
     el hook bloquea lo destructivo y los archivos de secretos, pero no reemplaza tus 'permissions' de Claude.
  3. Prueba el hook una vez: AGENTFLOW_HOOK_DEBUG=1 y revisa .agentflow/logs/hook-payloads.log si algo no bloquea.
  4. Verifica la version cuando quieras: bash .agentflow/version.sh
""")
PYEOF
