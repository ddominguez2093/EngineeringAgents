#!/usr/bin/env bash
#
# Verificacion determinista: lint, tipos, pruebas y build de los proyectos tocados.
# Imprime una linea por paso; solo en los fallos agrega la cola del log.
#
#   verify.sh [--quick] [--list] [--all] [base]
#
#   --quick  omite el build (para iterar mientras se implementa)
#   --list   muestra que se correria, sin ejecutar
#   --all    verifica todos los proyectos, no solo los tocados
#   base     rama contra la que se calculan los archivos tocados (por defecto main/master/develop)
#
# Si existe .agentflow/verify.conf, sus pasos sustituyen a la autodeteccion.
# Formato, una linea por paso:   directorio :: comando
#
set -uo pipefail

QUICK=0; LIST=0; ALL=0; BASE=""
for a in "$@"; do
  case "$a" in
    --quick) QUICK=1 ;;
    --list)  LIST=1 ;;
    --all)   ALL=1 ;;
    -*)      echo "opcion desconocida: $a" >&2; exit 2 ;;
    *)       BASE="$a" ;;
  esac
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 2
LOGS="$ROOT/.agentflow/logs"; mkdir -p "$LOGS"
TAIL_LINES="${VERIFY_TAIL:-60}"
STEPS=()   # "dir :: comando"

if [ -z "$BASE" ]; then
  for b in main master develop; do
    git rev-parse --verify -q "$b" >/dev/null 2>&1 && { BASE="$b"; break; }
  done
fi

changed_files() {
  { [ -n "$BASE" ] && git diff --name-only "$BASE"...HEAD 2>/dev/null
    git diff --name-only HEAD 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null; } | sort -u
}

# Sube desde un archivo hasta la raiz del proyecto que lo contiene.
project_root() {
  local d; d="$(dirname "$1")"
  local fallback=""
  while :; do
    if [ -e "$d/gradlew" ] || [ -e "$d/mvnw" ] || [ -e "$d/settings.gradle" ] || [ -e "$d/settings.gradle.kts" ]; then
      echo "$d"; return
    fi
    if [ -z "$fallback" ]; then
      if [ -e "$d/package.json" ] || [ -e "$d/pubspec.yaml" ] || [ -e "$d/Package.swift" ] \
         || [ -e "$d/pom.xml" ] || compgen -G "$d/*.xcodeproj" >/dev/null || compgen -G "$d/*.xcworkspace" >/dev/null; then
        fallback="$d"
      fi
    fi
    # JS, Flutter y SwiftPM se resuelven en el marcador mas cercano.
    if [ -n "$fallback" ] && { [ -e "$fallback/package.json" ] || [ -e "$fallback/pubspec.yaml" ] || [ -e "$fallback/Package.swift" ]; }; then
      echo "$fallback"; return
    fi
    [ "$d" = "." ] && break
    d="$(dirname "$d")"
  done
  [ -n "$fallback" ] && echo "$fallback"
}

all_roots() {
  git ls-files 2>/dev/null | grep -E '(^|/)(package\.json|pubspec\.yaml|Package\.swift|pom\.xml|gradlew|settings\.gradle(\.kts)?|[^/]+\.xcodeproj/project\.pbxproj)$' \
    | grep -vE '(^|/)(node_modules|build|\.dart_tool|Pods)/' \
    | while read -r f; do project_root "$f"; done | sort -u
}

has_script() { grep -qE "\"$2\"[[:space:]]*:" "$1/package.json" 2>/dev/null; }

add() { STEPS+=("$1 :: $2"); }

detect() {
  local d="$1"
  if [ -e "$d/package.json" ]; then
    local pm="npm"
    [ -e "$d/pnpm-lock.yaml" ] && pm="pnpm"
    [ -e "$d/yarn.lock" ] && pm="yarn"
    has_script "$d" typecheck && add "$d" "$pm run typecheck"
    has_script "$d" lint && add "$d" "$pm run lint"
    has_script "$d" test && add "$d" "CI=true $pm run test"
    [ "$QUICK" = 0 ] && has_script "$d" build && add "$d" "$pm run build"
  elif [ -e "$d/pubspec.yaml" ]; then
    add "$d" "flutter analyze"
    add "$d" "flutter test"
  elif [ -e "$d/gradlew" ] || [ -e "$d/settings.gradle" ] || [ -e "$d/settings.gradle.kts" ]; then
    local g="./gradlew"; [ -e "$d/gradlew" ] || g="gradle"
    if grep -rqsE 'com\.android\.(application|library)' "$d"/build.gradle* "$d"/*/build.gradle* "$d"/gradle/libs.versions.toml; then
      add "$d" "$g -q lintDebug testDebugUnitTest"
      [ "$QUICK" = 0 ] && add "$d" "$g -q assembleDebug"
    else
      add "$d" "$g -q check"
    fi
  elif [ -e "$d/pom.xml" ]; then
    local m="./mvnw"; [ -e "$d/mvnw" ] || m="mvn"
    add "$d" "$m -q -B verify"
  elif [ -e "$d/Package.swift" ]; then
    add "$d" "swift build"
    add "$d" "swift test"
  elif compgen -G "$d/*.xcodeproj" >/dev/null || compgen -G "$d/*.xcworkspace" >/dev/null; then
    add "$d" "#SIN-COMANDO proyecto Xcode: define el esquema y destino en .agentflow/verify.conf"
  fi
}

if [ -f .agentflow/verify.conf ]; then
  while IFS= read -r line; do
    case "$line" in ''|\#*) continue ;; esac
    case "$line" in *' :: '*) STEPS+=("$line") ;; *) echo "verify.conf: linea ignorada (falta ' :: '): $line" >&2 ;; esac
  done < .agentflow/verify.conf
else
  if [ "$ALL" = 1 ]; then
    ROOTS="$(all_roots)"
  else
    ROOTS="$(changed_files | while read -r f; do [ -n "$f" ] && project_root "$f"; done | sort -u)"
    [ -z "$ROOTS" ] && ROOTS="$(all_roots)"
  fi
  while read -r r; do [ -n "$r" ] && detect "$r"; done <<< "$ROOTS"
fi

if [ "${#STEPS[@]}" = 0 ]; then
  echo "SIN-PASOS: no se detecto ningun proyecto verificable. Define los comandos en .agentflow/verify.conf"
  exit 3
fi

FAILED=0; SKIPPED=0; n=0
for step in "${STEPS[@]}"; do
  dir="${step%% :: *}"; cmd="${step#* :: }"
  if [ "${cmd#\#SIN-COMANDO}" != "$cmd" ]; then
    echo "OMITIDO  [$dir] ${cmd#\#SIN-COMANDO }"; SKIPPED=$((SKIPPED+1)); continue
  fi
  if [ "$LIST" = 1 ]; then echo "PASO     [$dir] $cmd"; continue; fi
  n=$((n+1)); log="$LOGS/verify-$n.log"; start=$SECONDS
  if ( cd "$dir" && bash -c "$cmd" ) >"$log" 2>&1; then
    echo "OK       [$dir] $cmd ($((SECONDS-start))s)"
  else
    FAILED=$((FAILED+1))
    echo "FALLA    [$dir] $cmd ($((SECONDS-start))s) — log completo: ${log#"$ROOT"/}"
    tail -n "$TAIL_LINES" "$log" | sed 's/^/    | /'
  fi
done

[ "$LIST" = 1 ] && exit 0
if [ "$FAILED" -gt 0 ]; then echo "RESULTADO: falla ($FAILED paso(s))"; exit 1; fi
if [ "$SKIPPED" -gt 0 ]; then echo "RESULTADO: incompleto ($SKIPPED paso(s) omitidos)"; exit 3; fi
echo "RESULTADO: pasa"
