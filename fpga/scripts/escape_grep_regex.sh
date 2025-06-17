# Escape the grep regex for the pnr.log file

# Workflow: Copy the loglines that should be ignored to <file>
# bash scripts/escape_grep_regex.sh <file> >> .pnr_ignore_regexes

# Note that the last pattern tries to remove the current directory from any messages

sed \
  -e 's/\\/\\\\/g' \
  -e 's/\./\\./g' \
  -e 's/\*/\\*/g' \
  -e 's/\+/\\+/g' \
  -e 's/\?/\\?/g' \
  -e 's/\^/\\^/g' \
  -e 's/\$/\\$/g' \
  -e 's/\[/\\[/g' \
  -e 's/\]/\\]/g' \
  -e 's/{/\\{/g' \
  -e 's/}/\\}/g' \
  -e 's/(/\\(/g' \
  -e 's/)/\\)/g' \
  -e 's/|/\\|/g' \
  -e "s|`pwd`|\.*|g"
