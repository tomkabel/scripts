<!-- Part of the shell-scripting AbsolutelySkilled skill. Load this file when
     writing zsh scripts and needing quick reference for built-ins, parameter
     expansion modifiers, globbing qualifiers, or special variables. -->

# Zsh Cheatsheet

Quick reference for writing production Zsh scripts. Covers the constructs used
most often in automation, with a strong focus on Zsh's massive improvements
over Bash (modifiers, expansion flags, native arrays, and multios). For Bash
equivalents and differences, see `bash-cheatsheet.md`.

---

## Script Boilerplate & Isolation

```zsh
#!/usr/bin/env zsh
emulate -L zsh            # Enforce pristine Zsh defaults locally (ISOLATE from user's ~/.zshrc!)
setopt err_return         # Zsh equivalent of `set -e`
setopt pipe_fail          # Fail if any command in a pipe fails
setopt no_unset           # Fail on uninitialized variables (`set -u`)

# Note [Bash]: Bash uses `set -Eeuo pipefail` and `shopt` for similar effects.
# Zsh's `emulate -L zsh` is critical for production scripts to ignore user customizations.
```

**Why this matters:** Unlike Bash, Zsh is highly configurable. A user's `~/.zshrc` might
set options like `extendedglob`, `nullglob`, or `shwordsplit` that silently break your
script. `emulate -L zsh` locks the environment to standard Zsh defaults.

---

## Special Variables

| Variable | Meaning |
|---|---|
| `$0` | Script or function name (depends on `FUNCTION_ARGZERO` option) |
| `$1` .. `$9` | Positional arguments |
| `$@` | All positional args as separate words |
| `$*` | All positional args as a single string |
| `$#` | Number of positional arguments |
| `$?` | Exit code of the last command |
| `$$` | PID of the current shell |
| `$!` | PID of the last background job |
| `$_` | Last argument of the previous command |
| `$ZSH_VERSION`| Current version of Zsh |
| `$LINENO`| Current line number in the script |
| `$funcstack` | Array containing the function call stack |
| `$fpath` | Array of directories to search for `autoload` functions |
| `$path` | Lowercase array inherently tied to `$PATH` (modifying one updates the other) |

**Note [Bash]:** Bash has `$BASH_SOURCE[0]` instead of a direct script path variable.
Bash doesn't have `$funcstack` or tied PATH arrays like Zsh does.

---

## Variable Quoting (Critical Difference from Bash!)

```zsh
# Zsh does NOT split on spaces by default!
my_string="hello world"
print $my_string          # No quotes needed - WON'T split!
print "${my_string}"      # Also safe

# Force splitting (Bash-like behavior)
print ${=my_string}       # The = flag forces word splitting

# Note [Bash]: Bash ALWAYS splits unquoted variables: $var becomes hello world.
# In Bash you MUST quote: "$var" to preserve it as a single string.
```

**This is the #1 difference between Zsh and Bash.** You do not need to quote variables
excessively in Zsh like you do in Bash.

---

## Parameter Expansion

### Basic

| Syntax | Result |
|---|---|
| `${var}` | Value of `var` |
| `${var:-default}` | Value of `var`, or `default` if unset or empty |
| `${var:=default}` | Value of `var`; also assigns `default` if unset/empty |
| `${var:?message}` | Value of `var`; exits with `message` if unset/empty |
| `${var:+other}` | `other` if `var` is set and non-empty; else empty |

### Substring (Zsh uses 1-BASED INDEXING)

| Syntax | Result |
|---|---|
| `$var[offset]` | Character at `offset` (1-based!) |
| `$var[start,end]`| Substring from `start` to `end` index (inclusive) |
| `$var[-1]` | Last character in the string |
| `${#var}` | Length of `var` |

### Modifiers (Zsh exclusive magic)

Modifiers can be chained (e.g., `:a:h` for absolute dirname).

| Syntax | Result | Equivalent to |
|---|---|---|
| `${var:t}` | Tail | `basename "$var"` |
| `${var:h}` | Head | `dirname "$var"` |
| `${var:e}` | Extension | Extracts `txt` from `file.txt` |
| `${var:r}` | Root | Strips extension (keeps `file` from `file.txt`) |
| `${var:l}` | Lowercase | Converts to lowercase |
| `${var:u}` | Uppercase | Converts to uppercase |
| `${var:a}` | Absolute | Converts to absolute path |
| `${var:A}` | Absolute | Converts to absolute path, resolving symlinks |

**Nested expansions:** Zsh allows nested expansions that Bash cannot do:
```zsh
path="/home/user/docs/report.pdf"
print ${${path:t}%.*}      # Remove path AND extension → "report"
```

**Note [Bash]:** Bash uses `,,` and `^^` for case conversion, not `:l` and `:u`.
Bash has no equivalent to Zsh's file path modifiers (`:t`, `:h`, `:r`, `:e`).

### Expansion Flags

Used extensively in Zsh inside the parenthesis: `${(flag)var}`

| Syntax | Result |
|---|---|
| `${(j:,:)array}` | **Join** array elements using `,` as a delimiter |
| `${(s:,:)string}`| **Split** string into an array using `,` as a delimiter |
| `${(q)var}` | Safely **quote** the variable for `eval` or shell output |
| `${(U)var}` | Uppercase the value |
| `${(L)var}` | Lowercase the value |
| `${(k)map}` | Return only the **keys** of an associative array |
| `${(v)map}` | Return only the **values** of an associative array |
| `${(kv)map}` | Return both keys and values |
| `${(f)var}` | Split by newlines into array |
| `${(=)var}` | Split on whitespace (like Bash default) |

### Pattern removal & Substitution

| Syntax | Result |
|---|---|
| `${var#pattern}` | Remove shortest prefix matching `pattern` |
| `${var##pattern}` | Remove longest prefix matching `pattern` |
| `${var%pattern}` | Remove shortest suffix matching `pattern` |
| `${var%%pattern}` | Remove longest suffix matching `pattern` |
| `${var/pattern/repl}`| Replace first match of `pattern` with `repl` |
| `${var//pattern/repl}`| Replace all matches |

---

## Globbing & Qualifiers (Zsh Superpowers)

Zsh evaluates globs powerfully. Use `*(qualifier)` to filter files directly.

| Glob | Matches |
|---|---|
| `**/*.txt` | All `.txt` files recursively |
| `*(.)` | **Files** only (ignores directories, symlinks) |
| `*(/)` | **Directories** only |
| `*(@)` | **Symlinks** only |
| `*(x)` | **Executable** files |
| `*(m-1)` | Modified in the last **1 day** |
| `*(mtime +30)` | Modified more than 30 days ago |
| `*(Lm+1)` | Files larger than **1 Megabyte** |
| `*(om)` | Order by modification date (**newest first**) |
| `*(Om)` | Order by modification date (**oldest first**) |
| `*(.N)` | Nullglob: evaluates to nothing instead of throwing an error if 0 matches |
| `*(.Y2)` | Return exactly **2** files (limit results) |
| `^*.txt` | Match everything **except** `.txt` files (requires `extended_glob`) |

*Example:* `rm -f *.log(.Nmw-1)` removes log regular files modified in the last 1 week,
and does not error out if none are found.

**Note [Bash]:** Bash globs are much simpler. Bash has no glob qualifiers like `*(.)`.
Bash 4+ has `globstar` (`**`) for recursion but no file-type filtering or sorting built-in.

---

## Test Operators

### File Tests (`[[ -X file ]]`)

| Operator | True if |
|---|---|
| `-f file` | Regular file exists |
| `-d file` | Directory exists |
| `-s file` | File exists and is non-empty |
| `-L file` | Symbolic link exists |
| `f1 -nt f2` | `f1` is newer than `f2` |
| `f1 -ot f2` | `f1` is older than `f2` |

### String & Integer tests

| Operator | True if |
|---|---|
| `-z "$s"` | String is empty |
| `-n "$s"` | String is non-empty |
| `"$a" == "$b"` | Strings are equal |
| `"$s" == pattern` | String matches glob pattern (no quotes on pattern) |
| `"$s" =~ regex` | String matches regex |

*Note:* Unlike Bash, you rarely need `-eq`, `-lt` in `[[ ]]`. Use `(( a < b ))` natively.

**Note [Bash]:** Zsh's `==` supports more advanced glob patterns than Bash's `==`.
Bash requires `-eq`, `-lt` etc. for integer comparisons in `[[ ]]`.

---

## Zsh Built-ins

| Built-in | Purpose |
|---|---|
| `print` | Preferred over `echo`. Use `print -l` to print one arg per line |
| `read` | Read input. Use `read -r` to avoid backslash escaping |
| `vared` | Interactively edit the value of an environment variable |
| `autoload`| Mark a function to be loaded from `$fpath` only when first called |
| `typeset` | Declare variables (`-A` for map, `-a` for array, `-i` int, `-F` float, `-T` tied) |
| `zparseopts`| Highly advanced built-in native flag/option parser |
| `zmodload`| Load binary C modules (e.g., `zmodload zsh/datetime` or `zsh/pcre`) |
| `setopt` | Turn on Zsh features (e.g., `setopt extended_glob null_glob`) |
| `unsetopt`| Turn off Zsh features (e.g., `unsetopt nomatch`) |
| `emulate` | Set emulation mode (e.g., `emulate -L zsh`) |

### Useful `setopt` Options

```zsh
setopt extended_glob      # Enable #, ~, ^ glob operators
setopt null_glob          # Globs with no matches expand to nothing
setopt glob_substitute     # Perform parameter expansion on glob results
setopt err_return          # Exit on error (Zsh equivalent of set -e)
setopt no_unset            # Exit on unset variable (Zsh equivalent of set -u)
```

**Note [Bash]:** Bash uses `shopt` instead of `setopt`. Zsh's option system is more
orthogonal and consistent than Bash's `shopt`.

---

## Redirection

| Syntax | Meaning |
|---|---|
| `cmd > f1 > f2` | **MULTIOS**: Redirect stdout to multiple files (behaves like `tee` natively!) |
| `cmd >| file` | Force overwrite file even if `noclobber` is set |
| `cmd < file` | Read stdin from file |
| `cmd > /dev/null 2>&1` | Discard all output |
| `cmd <(other)` | Process substitution - treat output of `other` as a file |
| `cmd =(other)` | **Zsh exclusive**: Same as above, but uses a true temporary file (solves `seek` issues with `<()` pipelines) |

**Note [Bash]:** Bash does NOT have MULTIOS. Bash cannot do `cmd > f1 > f2` to write to
multiple files simultaneously. Bash also lacks the `=(other)` process substitution.

---

## File Navigation

```zsh
pwd                        # Print working directory
cd /path/to/dir            # Change directory
cd -                       # Return to previous directory
cd ~                       # Go to home directory
ls -la                     # List all files with details
realpath file              # Resolve to absolute path (coreutils)
print $PWD                 # Zsh: current directory
print ${(%):-%x}           # Zsh: current script path (prompt expansion)

# Find script directory (Highly robust Zsh specific method)
SCRIPT_DIR="${${(%):-%x}:A:h}"

# Glob patterns with qualifiers
ls **/*.txt                # All .txt files recursively
ls *(.)                    # List only files (no directories)
ls -d */                   # List only directories
cp file1 file2             # Copy files
mv source dest             # Move/rename files
rm -rf directory           # Remove recursively
mkdir -p path/to/dir       # Create directory tree
```

**Note [Bash]:** Bash requires `shopt -s globstar` for `**` recursion. Bash has no
equivalent to `${(%):-%x}` for robust script path detection; use `BASH_SOURCE[0]`.

---

## Text Processing

```zsh
# Modern Zsh file reading (No loops required!)
# (<file) is a highly optimized built-in; (f) splits by newlines
lines=( ${(f)"$(<file.txt)"} )

# Traditional line-by-line reading
while IFS= read -r line; do
  print -r -- "$line"
done < input.txt

# String manipulation with modifiers
path="/home/user/docs/file.txt"
print ${path:t}            # "file.txt" (tail/base name)
print ${path:h}            # "/home/user/docs" (head/dir name)
print ${path:e}            # "txt" (extension)
print ${path:r}            # "/home/user/docs/file" (root)
print ${path:l}            # lowercase

# Splitting and joining
words=( ${(s:,:)string} )  # Split by comma
joined=${(j:,:)array}      # Join with comma

# Text search and processing
grep "pattern" file         # Search for pattern
sed 's/foo/bar/g' file    # Replace all occurrences
awk '{print $1}' file      # Print first column
sort file | uniq -c        # Count duplicates

# Zsh supports native floating point!
typeset -F result
result=$(( 22.0 / 7.0 ))
print $result              # 3.1428571429
```

**Note [Bash]:** Bash requires `mapfile` or a `while read` loop to read files.
Bash has no native floating point; use `awk` for floating point math in containers.

---

## Job Control

```zsh
# Basic job control
cmd &                      # Run command in background
jobs                       # List background jobs
fg %1                      # Bring job 1 to foreground
bg %1                      # Resume job 1 in background
kill %1                    # Kill job 1
wait                       # Wait for all background jobs

# Pipeline status checking
cmd1 | cmd2 | cmd3
if [[ ${pipestatus[1]} -ne 0 ]]; then   # Zsh uses ${pipestatus[@]}
  print "Pipeline failed at first command"
fi

# Disowning jobs
disown %1                  # Remove job from shell's job table
disown -h %1               # Job ignores SIGHUP

# Trap patterns
trap 'cleanup_function' EXIT           # Run on script exit
trap 'cleanup_function' INT TERM       # Run on signals
```

**Note [Bash]:** Zsh uses `${pipestatus[@]}` while Bash uses `${PIPESTATUS[@]}` for
pipeline status. Both shells support `wait`, `jobs`, `fg`, `bg`, `disown`.

---

## Arrays (1-Based Indexing)

```zsh
# Declare and populate
arr=("alpha" "beta" "gamma")
typeset -a arr

# Access (Zsh uses 1-based indexes!)
echo $arr[1]               # "alpha"
echo $arr[-1]              # "gamma" (last element)
echo $arr[@]               # all elements
echo $#arr                 # number of elements (3)
echo $arr[2,-1]            # "beta gamma" (2nd to last inclusive)

# Slice
echo $arr[1,2]             # "alpha beta" (inclusive)

# Append
arr+=("delta")

# Find element in array (returns highest index, or 0 if not found)
if (( ${arr[(Ie)beta]} )); then
  print "beta is in the array"
fi

# Associative array
typeset -A map
map=(
  "key1" "value1"
  "key2" "value2"
)
echo $map[key1]
echo ${(k)map}             # print all keys
echo ${(v)map}             # print all values

# Tied arrays (sync a string with an array)
typeset -T MY_PATH my_path ':'
my_path=(/usr/local/bin /opt/homebrew/bin)
print $MY_PATH             # Outputs: /usr/local/bin:/opt/homebrew/bin
```

**Note [Bash]:** Bash arrays are 0-based. Bash has no tied arrays. Bash 5.0+ supports
`map+=(["key"]="value")` for associative array append. Zsh's `${arr[(Ie)element]}`
syntax for finding elements has no Bash equivalent.

---

## Arithmetic

```zsh
# (( )) for integer arithmetic
(( count++ ))
(( total = a + b * c ))
if (( count > 10 )); then print "too many"; fi

# Zsh supports native floating point! No need for bc or awk
typeset -F result
result=$(( 22.0 / 7.0 ))
print $result              # 3.1428571429

# Floating point variables
typeset -F2 pi             # 2 decimal places
pi=$(( 22.0 / 7.0 ))
print $pi                  # 3.14
```

**Note [Bash]:** Bash has NO native floating point. All floating point math requires
external tools like `awk`. In containerized environments, prefer `awk` over `bc` since
`awk` is universally available.

---

## Scripting Constructs

### Conditionals

```zsh
# Simple conditional
if (( $# == 1 )); then
  print "One argument provided"
elif (( $# > 1 )); then
  print "Multiple arguments"
else
  print "No arguments"
fi

# Test and execute
[[ -f file ]] && print "File exists"
[[ -d dir ]] || mkdir dir

# Case statement
case "$var" in
  foo) print "Found foo" ;;
  bar) print "Found bar" ;;
  *)   print "Default" ;;
esac
```

### Loops

```zsh
# For loop over items
for item in "$arr[@]"; do
  print "$item"
done

# C-style for loop
for (( i=1; i<=10; i++ )); do
  print "$i"
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
  print -r -- "$line"
done < input.txt

# Process files matching glob
for file in *.txt(.N); do   # (.N) = nullglob
  print "Processing $file"
done

# Process files recursively
for file in **/*.txt; do
  [[ -f "$file" ]] || continue
  print "Processing $file"
done
```

### Functions

```zsh
# Basic function
my_function() {
  local arg1="$1"
  local result
  result=$(some_command "$arg1")
  print "$result"
}

# Anonymous function (isolated scope, no subshell fork!)
() {
  local temp_var="secret"
  print "Doing something with $temp_var"
}
# temp_var is no longer accessible here

# Using anonymous functions instead of subshells for scoping
() {
  local tmpfile=$(mktemp)
  # Work with tmpfile...
} # tmpfile automatically cleaned up, no subshell forked!

# Function with error handling
safe_operation() {
  "$@" || return $?
  return 0
}
```

### Argument Parsing

```zsh
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
      print -u2 "Unknown option: $1"
      exit 1
      ;;
    *)
      args+=("$1")
      ;;
  esac
  shift
done

# Using zparseopts for advanced parsing
zparseopts -D -E -- \
  h=help \
  v=verbose \
  n=dry_run \
  o:=output

if [[ -n "$help" ]]; then
  usage
  exit 0
fi
```

---

## Common Patterns

```zsh
# Default value for missing first argument
input=${1:-default.txt}

# Require exactly one argument
(( $# == 1 )) || { print -u2 "Usage: $0 <file>"; exit 1; }

# Absolute path of the script's directory (Highly robust Zsh specific method)
SCRIPT_DIR="${${(%):-%x}:A:h}"

# Loop over lines in a file safely
while IFS= read -r line; do
  print -r -- "$line"
done < input.txt

# Loop over files skipping directories (Using glob qualifiers)
for file in *.txt(.N); do
  print "Processing $file"
done

# Retry a command up to N times
retry() {
  local n=${1} delay=${2:-2} i
  shift $(( $# > 1 ? 2 : 1 ))
  for (( i=1; i<=n; i++ )); do
    "$@" && return 0
    print -u2 "Attempt $i/$n failed. Retrying in ${delay}s..."
    sleep "$delay"
  done
  return 1
}
retry 3 2 curl -sf https://example.com

# Anonymous function for isolated scoping (no subshell!)
() {
  local tmp_dir=$(mktemp -d)
  # Work that doesn't affect parent environment...
}
```

---

## 2026 Modern Zsh Best Practices

These represent the current (2026) state-of-the-art for production Zsh scripting.

### Script Isolation from User Environment

```zsh
#!/usr/bin/env zsh
emulate -L zsh            # CRITICAL: Lock down environment
setopt err_return pipe_fail no_unset
# Your script is now immune to user's ~/.zshrc customizations
```

### Modern File Reading (No Loops Required)

```zsh
# (<file) is a built-in substitution; (f) splits by newlines
lines=( ${(f)"$(<input.txt)"} )
# Highly optimized, no subshell performance hit
```

### Anonymous Functions for Clean Scoping

```zsh
# Use instead of wrapping in (...) subshells which fork and are slow
() {
  local temp_file=$(mktemp)
  # Do work...
  # temp_file automatically destroyed when function exits
  # No subshell forked! Faster than ( ... )
}
```

### Tied Arrays for Path Management

```zsh
# Define custom colon-separated paths tied to arrays
typeset -T KUBECONFIG kubeconfig ':'
kubeconfig=(~/.kube/config ~/.kube/cluster2)
print $KUBECONFIG  # Outputs: /home/user/.kube/config:/home/user/.kube/cluster2
```

### Nested Expansions (Zsh-Exclusive)

```zsh
path="/home/user/docs/report.pdf"
print ${${path:t}%.*}      # "report" - removes path AND extension in one step
print ${${(%):-%x}:A:h}   # Script dir with symlink resolution
```

### Glob Qualifier Limits

```zsh
# Limit glob results to avoid listing 100,000 files
file=$(*(.Y1))             # Get exactly one regular file
if [[ -n $file ]]; then
  print "Found: $file"
fi

# Negated globs (requires extended_glob)
all_files=( ^*.txt(N) )   # All files EXCEPT .txt files
```
