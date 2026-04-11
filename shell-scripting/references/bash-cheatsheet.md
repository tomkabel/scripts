<!-- Part of the shell-scripting AbsolutelySkilled skill. Load this file when
     writing bash scripts and needing quick reference for built-ins, parameter
     expansion syntax, test operators, or special variables. -->

# Bash Cheatsheet

Quick reference for writing production bash scripts. Covers the constructs used
most often in real automation work. For Zsh equivalents and differences, see
`zsh-cheatsheet.md`.

---

## Script Boilerplate & Safety

```bash
#!/usr/bin/env bash
set -Eeuo pipefail          # Unofficial Strict Mode (Bash 4.0+)
shopt -s inherit_errexit   # Inherit errexit in subshells (Bash 4.4+)
shopt -s nullglob          # Unmatched globs expand to nothing
shopt -s globstar          # Enable ** recursive globbing (Bash 4.0+)

# Note [Zsh]: Zsh uses `emulate -L zsh` and `setopt` instead of `set -Eeuo pipefail`
# and `shopt`. Zsh equivalents: err_return, pipe_fail, no_unset.
```

---

## Special Variables

| Variable | Meaning |
|---|---|
| `$0` | Script name (path as invoked) |
| `$1` .. `$9` | Positional arguments |
| `$@` | All positional args as separate words (always quote: `"$@"`) |
| `$*` | All positional args as a single string (rarely useful) |
| `$#` | Number of positional arguments |
| `$?` | Exit code of the last command |
| `$$` | PID of the current shell |
| `$!` | PID of the last background job |
| `$_` | Last argument of the previous command |
| `$BASH_SOURCE[0]` | Path of the currently executing script file |
| `$LINENO` | Current line number in the script |
| `$FUNCNAME[0]` | Name of the current function |
| `$IFS` | Internal Field Separator (default: space/tab/newline) |
| `$EPOCHSECONDS` | Current epoch time in seconds (Bash 5.0+) |
| `$EPOCHREALTIME` | Current epoch time with nanoseconds (Bash 5.0+) |

**Note:** `BASH_SOURCE[0]` works reliably when sourced, but may fail inside symlinks.
For maximum robustness, prefer: `SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"`

---

## Parameter Expansion

### Basic

| Syntax | Result |
|---|---|
| `${var}` | Value of `var` (braces prevent ambiguity) |
| `${var:-default}` | Value of `var`, or `default` if unset or empty |
| `${var:=default}` | Value of `var`; also assigns `default` if unset or empty |
| `${var:?message}` | Value of `var`; exits with `message` if unset or empty |
| `${var:+other}` | `other` if `var` is set and non-empty; else empty string |

### Substring

| Syntax | Result |
|---|---|
| `${var:offset}` | Substring from `offset` to end |
| `${var:offset:length}` | Substring of `length` starting at `offset` |
| `${#var}` | Length of `var` |

### Pattern Removal

| Syntax | Result |
|---|---|
| `${var#pattern}` | Remove shortest prefix matching `pattern` |
| `${var##pattern}` | Remove longest prefix matching `pattern` |
| `${var%pattern}` | Remove shortest suffix matching `pattern` |
| `${var%%pattern}` | Remove longest suffix matching `pattern` |

Common uses:

```bash
"${path##*/}"     # basename equivalent
"${path%/*}"      # dirname equivalent
"${file%.txt}"    # strip .txt extension
```

### Substitution and Case

| Syntax | Result |
|---|---|
| `${var/pattern/replace}` | Replace first match of `pattern` with `replace` |
| `${var//pattern/replace}` | Replace all matches |
| `${var/#pattern/replace}` | Replace if `pattern` matches at start |
| `${var/%pattern/replace}` | Replace if `pattern` matches at end |
| `${var,,}` | Convert all characters to lowercase (Bash 4+) |
| `${var^^}` | Convert all characters to uppercase (Bash 4+) |
| `${var^}` | Capitalise first character (Bash 4+) |
| `${var@Q}` | Safely quote for eval/SSH (Bash 4.4+). Outputs shell-safe format |

**Note [Zsh]:** Zsh uses `:l` and `:u` modifiers instead of `,,` and `^^`. Zsh also
has `${var@Q}` equivalent via the `(q)` expansion flag: `${(q)var}`.

---

## Test Operators

### File Tests (`[[ -X file ]]`)

| Operator | True if |
|---|---|
| `-e file` | File exists (any type) |
| `-f file` | Regular file exists (preferred over `-e` in scripts) |
| `-d file` | Directory exists |
| `-L file` | Symbolic link exists |
| `-r file` | File is readable |
| `-w file` | File is writable |
| `-x file` | File is executable |
| `-s file` | File exists and is non-empty |
| `-z file` | File is zero bytes |
| `f1 -nt f2` | `f1` is newer than `f2` |
| `f1 -ot f2` | `f1` is older than `f2` |

**Note:** Modern linters (ShellCheck) recommend `-f` over `-e` to avoid unexpected
behavior with sockets or device nodes.

### String Tests

| Operator | True if |
|---|---|
| `-z "$s"` | String is empty |
| `-n "$s"` | String is non-empty |
| `"$a" == "$b"` | Strings are equal |
| `"$a" != "$b"` | Strings are not equal |
| `"$s" == pattern` | String matches glob pattern (no quotes on pattern) |
| `"$s" =~ regex` | String matches extended regex (Bash only) |

**Warning:** The right-hand side of `=~` must NOT be quoted if it contains regex
metacharacters. Quoting forces literal string matching. Example: `[[ "$s" =~ ^foo[0-9]+$ ]]`

**Note [Zsh]:** Zsh also supports `=~` but has richer glob matching built-in.
Zsh's `==` supports more advanced glob patterns than Bash.

### Integer Tests

| Operator | True if |
|---|---|
| `$a -eq $b` | Equal |
| `$a -ne $b` | Not equal |
| `$a -lt $b` | Less than |
| `$a -le $b` | Less than or equal |
| `$a -gt $b` | Greater than |
| `$a -ge $b` | Greater than or equal |

In `(( ))` arithmetic context, use `==`, `!=`, `<`, `<=`, `>`, `>=` directly.

---

## Bash Built-ins

| Built-in | Purpose |
|---|---|
| `echo` | Print text (avoid `-e`; not portable) |
| `printf` | Formatted output; portable and reliable |
| `read` | Read a line from stdin into a variable |
| `local` | Declare a function-scoped variable |
| `declare` | Declare variables with attributes (`-r`, `-i`, `-a`, `-A`) |
| `readonly` | Mark a variable as immutable |
| `export` | Make a variable available to child processes |
| `source` / `.` | Execute a script in the current shell context |
| `eval` | Execute a string as a shell command (use with extreme caution) |
| `mapfile` / `readarray` | Read lines from stdin into an array (Bash 4+) |
| `typeset` | Alias for `declare` (also used in Zsh) |
| `trap` | Register a command to run on a signal or exit |
| `wait` | Wait for background jobs to finish |
| `jobs` | List background jobs |
| `disown` | Remove a job from the shell's job table |
| `getopts` | Parse short option flags |
| `shift` | Shift positional parameters left by N |
| `set` | Set shell options or positional parameters |
| `shopt` | Set/unset additional shell options (Bash-specific) |
| `unset` | Remove a variable or function |
| `pushd` / `popd` | Directory stack navigation |
| `command` | Bypass shell functions; run the external command directly |
| `type` | Show how a name is interpreted (function, built-in, file) |
| `compgen` | Generate completions (useful in scripts for listing commands) |

### Useful `shopt` Options

```bash
shopt -s globstar          # Enable ** for recursive globbing
shopt -s nullglob         # Globs with no matches expand to nothing
shopt -s failglob         # Globs with no matches cause error
shopt -s inherit_errexit  # Subshells inherit errexit option
shopt -s dotglob          # Include dotfiles in glob expansion
```

**Note [Zsh]:** Zsh uses `setopt` and `unsetopt` instead of `shopt`. Key Zsh equivalents:
`nullglob` → `setopt null_glob`, `extended_glob` → `setopt extended_glob`.

---

## Redirection

| Syntax | Meaning |
|---|---|
| `cmd > file` | Redirect stdout to file (overwrite) |
| `cmd >> file` | Redirect stdout to file (append) |
| `cmd < file` | Read stdin from file |
| `cmd 2> file` | Redirect stderr to file |
| `cmd 2>&1` | Redirect stderr to stdout |
| `cmd &> file` | Redirect both stdout and stderr to file (Bash) |
| `cmd &>> file` | Append both stdout and stderr to file (Bash 4.0+) |
| `cmd 2>/dev/null` | Discard stderr |
| `cmd > /dev/null 2>&1` | Discard all output (portable) |
| `cmd | cmd2` | Pipe stdout of cmd1 to stdin of cmd2 |
| `cmd |& cmd2` | Pipe both stdout and stderr to cmd2 (Bash 4.0+ shorthand for `2>&1 |`) |
| `cmd <<EOF ... EOF` | Here document - feed multi-line string as stdin |
| `cmd <<-EOF ... EOF` | Here document stripping leading tabs |
| `cmd <(other)` | Process substitution - treat output of `other` as a file |
| `cmd >(other)` | Process substitution - write to stdin of `other` via a file |

### Dynamic File Descriptors (Bash 4.1+)

```bash
exec {fd}>file              # Auto-assign unused fd (e.g., creates fd 3)
echo "data" >&$fd           # Write to fd 3
exec {fd}>&-               # Close fd 3
```

**Note [Zsh]:** Zsh has MULTIOS - you can redirect to multiple files with `cmd > f1 > f2`.
Zsh also has `cmd =(other)` which uses a true temporary file (solves seek issues).

---

## File Navigation

```bash
pwd                        # Print working directory
cd /path/to/dir            # Change directory
cd -                       # Return to previous directory
cd ~                       # Go to home directory
ls -la                     # List all files with details
realpath file              # Resolve to absolute path (coreutils)
readlink -f file           # Resolve symlinks (coreutils)

# Find script directory robustly
SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"

# Glob patterns (requires shopt -s globstar for **)
ls **/*.txt                # All .txt files recursively
cp file1 file2             # Copy files
mv source dest             # Move/rename files
rm -rf directory           # Remove recursively
mkdir -p path/to/dir       # Create directory tree
```

---

## Text Processing

```bash
# Reading files
mapfile -t lines < "input.txt"   # Read file into array (strip newlines with -t)
while IFS= read -r line; do      # Read line by line
  echo "$line"
done < "input.txt"

# String manipulation
${var#pattern}              # Remove shortest prefix
${var##pattern}            # Remove longest prefix
${var%pattern}             # Remove shortest suffix
${var%%pattern}            # Remove longest suffix
${var/substr/repl}         # Replace first match
${var//substr/repl}        # Replace all matches

# Text search and processing
grep "pattern" file         # Search for pattern
sed 's/foo/bar/g' file     # Replace all occurrences
awk '{print $1}' file      # Print first column
sort file | uniq -c        # Count duplicates
head -n 10 file            # First 10 lines
tail -n 10 file            # Last 10 lines

# Floating point math (container-safe, no bc needed)
result=$(awk "BEGIN { printf \"%.2f\", 10 / 3 }")
```

**Note [Zsh]:** Zsh has native floating point support via `typeset -F`. No external
tools needed: `result=$(( 22.0 / 7.0 ))`. Zsh also has `(f)` flag for splitting
files: `lines=( ${(f)"$(<file.txt)"} )`.

---

## Job Control

```bash
# Basic job control
cmd &                      # Run command in background
jobs                       # List background jobs
fg %1                      # Bring job 1 to foreground
bg %1                      # Resume job 1 in background
kill %1                    # Kill job 1
wait                       # Wait for all background jobs

# Pipeline status checking
cmd1 | cmd2 | cmd3
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then   # Check if cmd1 failed
  echo "Pipeline failed at first command"
fi

# Disowning jobs
disown %1                  # Remove job from shell's job table
disown -h %1               # Job ignores SIGHUP

# Trap patterns
trap 'cleanup_function' EXIT           # Run on script exit
trap 'cleanup_function' INT TERM       # Run on signals
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT          # Guaranteed cleanup on exit
```

**Note [Zsh]:** Zsh job control is similar but uses slightly different syntax.
Zsh has `wait` and `jobs` equivalents. The PIPESTATUS array exists in Bash 3.0+;
Zsh uses `${pipestatus[@]}` for the same purpose.

---

## Arrays

```bash
# Declare and populate
arr=("alpha" "beta" "gamma")
declare -a arr

# Access
echo "${arr[0]}"           # first element
echo "${arr[-1]}"          # last element (Bash 4.3+)
echo "${arr[@]}"           # all elements (always quote)
echo "${#arr[@]}"          # number of elements
echo "${!arr[@]}"          # all indices

# Append
arr+=("delta")

# Slice: ${arr[@]:offset:length}
echo "${arr[@]:1:2}"       # elements 1 and 2

# Delete element (WARNING: creates sparse array)
unset 'arr[1]'

# Iterate safely
for item in "${arr[@]}"; do
  echo "$item"
done

# Associative array (Bash 4+)
declare -A map
map["key"]="value"
echo "${map["key"]}"
echo "${!map[@]}"          # all keys

# Append multiple keys (Bash 5.0+)
map+=(["key2"]="value2" ["key3"]="value3")
```

**Note [Zsh]:** Zsh arrays are 1-based by default, not 0-based. Access first element
as `${arr[1]}`. Zsh uses `typeset -A` for associative arrays. Zsh has richer array
operations including `${arr[(Ie)element]}` to find element indices, and tied arrays
via `typeset -T`.

---

## Arithmetic

```bash
# (( )) for integer arithmetic - returns exit code 0/1 for true/false
(( count++ ))
(( total = a + b * c ))
if (( count > 10 )); then echo "too many"; fi

# $(( )) for arithmetic substitution
result=$(( 2 ** 10 ))      # 1024
echo $(( RANDOM % 100 ))   # random 0-99

# Floating point math (container-safe with awk)
float_val=$(awk "BEGIN { printf \"%.2f\", 22.0 / 7.0 }")
```

**Note [Zsh]:** Zsh has native floating point support via `typeset -F`. No external
tools needed: `typeset -F result; result=$(( 22.0 / 7.0 ))`.

---

## Scripting Constructs

### Conditionals

```bash
# Simple conditional
if [[ $# -eq 1 ]]; then
  echo "One argument provided"
elif [[ $# -gt 1 ]]; then
  echo "Multiple arguments"
else
  echo "No arguments"
fi

# Test and execute
[[ -f file ]] && echo "File exists"
[[ -d dir ]] || mkdir dir

# Case statement
case "$var" in
  foo) echo "Found foo" ;;
  bar) echo "Found bar" ;;
  *)   echo "Default" ;;
esac
```

### Loops

```bash
# For loop over items
for item in "${arr[@]}"; do
  echo "$item"
done

# C-style for loop
for (( i=0; i<10; i++ )); do
  echo "$i"
done

# While loop
while (( count < 10 )); do
  (( count++ ))
done

# Until loop
until [[ -f lockfile ]]; do
  sleep 1
done

# Reading lines
while IFS= read -r line; do
  echo "$line"
done < "input.txt"

# Process each file in directory
for file in *.txt; do
  [[ -f "$file" ]] || continue
  echo "Processing $file"
done
```

### Functions

```bash
# Basic function
my_function() {
  local arg1="$1"
  local result
  result=$(some_command "$arg1")
  echo "$result"
}

# Return value via echo
get_date() {
  date +%Y-%m-%d
}

# Function with error handling
safe_operation() {
  local status=0
  "$@" || status=$?
  return $status
}
```

### Argument Parsing

```bash
# Simple shift-based parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -v|--verbose)
      verbose=true
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      args+=("$1")
      ;;
  esac
  shift
done

# Using getopts for short options
while getopts "hvno:" opt; do
  case $opt in
    h) usage; exit 0 ;;
    v) verbose=true ;;
    n) dry_run=true ;;
    o) output="$OPTARG" ;;
    *) exit 1 ;;
  esac
done
shift $(( OPTIND - 1 ))
```

---

## Common Patterns

```bash
# Default value for missing first argument
input="${1:-default.txt}"

# Require exactly one argument
[[ $# -eq 1 ]] || { echo "Usage: $0 <file>" >&2; exit 1; }

# Check if running as root
[[ $EUID -eq 0 ]] || { echo "Must run as root" >&2; exit 1; }

# Check if a command exists
command -v docker &>/dev/null || { echo "docker not found" >&2; exit 1; }

# Silent background job
some_long_command &>/dev/null &

# Retry a command up to N times
retry() {
  local n="$1"; shift
  local delay="${1:-2}"; shift
  local i
  for (( i=1; i<=n; i++ )); do
    "$@" && return 0
    echo "Attempt $i/$n failed. Retrying in ${delay}s..." >&2
    sleep "$delay"
  done
  return 1
}
retry 3 2 curl -sf https://example.com

# Safe cleanup via EXIT trap
scratch_dir=$(mktemp -d)
trap 'rm -rf "$scratch_dir"' EXIT

# Check pipeline status across all stages
cmd1 | cmd2 | cmd3
if [[ ${PIPESTATUS[0]} -ne 0 ]] || [[ ${PIPESTATUS[1]} -ne 0 ]]; then
  echo "Pipeline failed"
fi
```

---

## 2026 Modern Bash Best Practices

These represent the current (2026) state-of-the-art for production Bash scripting,
particularly in containerized environments.

### Time Measurement Without Subshells

```bash
start_time=$EPOCHREALTIME
# ... do work ...
duration=$(awk "BEGIN {print $EPOCHREALTIME - $start_time}")
```

### Safe Variable Quoting for Eval/SSH

```bash
# Bash 4.4+ @Q operator - safe for eval and SSH
command="ls -l ${filepath@Q}"
eval "$command"           # Now safe from injection
ssh user@host "${cmd@Q}"  # Safe remote execution
```

### Modern Script Directory Detection

```bash
# With coreutils realpath (standard in virtually all containers)
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

# Fallback for minimal environments
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

### Floating Point Math (Container-Safe)

```bash
# awk is available in essentially all containers; bc is often missing
result=$(awk "BEGIN {print 22/7}")
printf "%.2f\n" "$(awk "BEGIN {print 22/7}")"
```

### Pipeline Status Verification

```bash
# Always check PIPESTATUS for pipeline debugging
some_cmd | grep "error" | tee error.log
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
  echo "some_cmd failed!"
fi
```
