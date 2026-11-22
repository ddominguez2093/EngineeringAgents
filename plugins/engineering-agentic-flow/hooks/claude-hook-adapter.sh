#!/usr/bin/env bash
#
# Permite que un hook PreToolUse escrito para Claude Code (el tuyo, de .claude/settings.json)
# corra tal cual en Antigravity.
#
#   claude-hook-adapter.sh '<comando del hook de Claude>'
#
# Traduce el evento de Antigravity ({"toolCall": {"name", "args"}}) al de Claude Code
# ({"tool_name", "tool_input"}), corre el hook con CLAUDE_PROJECT_DIR definido, y traduce
# su respuesta: exit 2 o permissionDecision=deny -> {"decision": "deny", "reason": ...};
# cualquier otra cosa -> {"decision": "allow"}.
#
# Los nombres de los campos de ruta de cada herramienta de Antigravity no estan
# documentados. Si un hook no ve el archivo (o para comprobar que se ejecuta), crea
# .agentflow/hook-debug (o AGENTFLOW_HOOK_DEBUG=1) y mira
# .agentflow/logs/hook-payloads.log para ver el evento real.
#
set -uo pipefail

CMD="${1:-}"
if [ -z "$CMD" ]; then echo '{"decision": "allow"}'; exit 0; fi

PY=""
for p in python3 python py; do
  if command -v "$p" >/dev/null 2>&1 && "$p" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1; then
    PY="$p"; break
  fi
done
if [ -z "$PY" ]; then
  echo "claude-hook-adapter: falta Python 3; el hook '$CMD' no se ejecuto." >&2
  echo '{"decision": "allow"}'; exit 0
fi

AF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" AF_INPUT="$(cat)" AF_CMD="$CMD" "$PY" -I - <<'EOF'
import json, os, subprocess, sys

def out(decision, reason=""):
    d = {"decision": decision}
    if reason:
        d["reason"] = reason
    print(json.dumps(d))
    sys.exit(0)

try:
    ev = json.loads(os.environ.get("AF_INPUT", ""))
except Exception:
    out("allow")

tc = ev.get("toolCall") or {}
name = tc.get("name", "")
args = tc.get("args") or {}
ws = (ev.get("workspacePaths") or [os.getcwd()])[0]

afd = os.environ.get("AF_DIR") or os.path.join(ws, ".agentflow")
if os.environ.get("AGENTFLOW_HOOK_DEBUG") == "1" or os.path.exists(os.path.join(afd, "hook-debug")):
    try:
        os.makedirs(os.path.join(afd, "logs"), exist_ok=True)
        with open(os.path.join(afd, "logs", "hook-payloads.log"), "a") as f:
            f.write(json.dumps({"hook": os.environ["AF_CMD"], "event": ev}) + "\n")
    except Exception:
        pass

def classify(n):
    # La App y la documentacion de Antigravity usan nombres distintos para las mismas
    # herramientas (read_file/view_file, edit_file/replace_file_content...): se clasifica por nombre.
    n = n.lower()
    if n == "run_command":
        return "Bash"
    if "edit" in n or "replace" in n:
        return "Edit"
    if "write" in n or "create" in n:
        return "Write"
    if "read" in n or "view" in n:
        return "Read"
    return None

kind = classify(name)
if kind is None:
    out("allow")

def first_path(a):
    for k in ("AbsolutePath", "TargetFile", "FilePath", "Path", "file_path", "path", "File"):
        v = a.get(k)
        if isinstance(v, str) and v:
            return v
    for v in a.values():
        if isinstance(v, str) and "/" in v and "\n" not in v and len(v) < 4096:
            return v
    return ""

if kind == "Bash":
    tool_input = {"command": args.get("CommandLine") or args.get("command") or ""}
else:
    p = first_path(args)
    tool_input = {"file_path": p, "path": p}

payload = {"tool_name": kind, "tool_input": tool_input, "cwd": ws, "hook_event_name": "PreToolUse"}
env = dict(os.environ, CLAUDE_PROJECT_DIR=ws)
env.pop("AF_INPUT", None)

try:
    r = subprocess.run(["bash", "-c", os.environ["AF_CMD"]], input=json.dumps(payload),
                       capture_output=True, text=True, cwd=ws, env=env, timeout=25)
except Exception as e:
    sys.stderr.write("claude-hook-adapter: no se pudo ejecutar el hook: %s\n" % e)
    out("allow")

if r.returncode == 2:
    out("deny", (r.stderr or "Bloqueado por un hook del proyecto.").strip())
try:
    j = json.loads(r.stdout) if r.stdout.strip() else {}
    h = j.get("hookSpecificOutput") or {}
    if h.get("permissionDecision") == "deny" or j.get("decision") in ("block", "deny"):
        out("deny", h.get("permissionDecisionReason") or j.get("reason") or "Bloqueado por un hook del proyecto.")
except Exception:
    pass
out("allow")
EOF
