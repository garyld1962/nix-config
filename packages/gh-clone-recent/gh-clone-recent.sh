# shellcheck shell=bash
# Clone every repo in a GitHub account that was pushed to in the last N days.
# "Pushed to" covers new commits and new branches on any branch (GitHub's pushedAt).

usage() {
    cat >&2 <<EOF
Usage: $(basename "$0") [-n|--dry-run] <account> <days> [dest-dir]

  account    GitHub user or organization, e.g. garyld1962
  days       Include repos pushed to within this many days
  dest-dir   Where to clone (default: current directory)
  -n         Dry run: list the repos that would be cloned, clone nothing
EOF
    exit 2
}

dry_run=0
case "${1:-}" in
    -n|--dry-run) dry_run=1; shift ;;
    -h|--help) usage ;;
esac

[ $# -ge 2 ] && [ $# -le 3 ] || usage
account=$1
days=$2
dest=${3:-.}

case "$days" in
    ''|*[!0-9]*) echo "days must be a whole number, got: $days" >&2; exit 2 ;;
esac

repos=$(gh repo list "$account" --limit 1000 --json nameWithOwner,name,pushedAt |
    jq -r --argjson days "$days" '
        (now - $days * 86400) as $cutoff
        | map(select(.pushedAt != null and (.pushedAt | fromdateiso8601) >= $cutoff))
        | sort_by(.pushedAt) | reverse
        | .[] | [.nameWithOwner, .name, .pushedAt] | @tsv')

if [ -z "$repos" ]; then
    echo "No repos in $account were pushed to in the last $days day(s)."
    exit 0
fi

if [ "$dry_run" -eq 1 ]; then
    echo "Would clone into $dest (last push shown):"
    printf '%s\n' "$repos" | while IFS="$(printf '\t')" read -r full name pushed; do
        if [ -e "$dest/$name" ]; then
            printf '  %-50s %s  (exists, would skip)\n' "$full" "$pushed"
        else
            printf '  %-50s %s\n' "$full" "$pushed"
        fi
    done
    exit 0
fi

mkdir -p "$dest"
failed=0
# Read from fd 3 so git/ssh prompts can still use stdin.
while IFS="$(printf '\t')" read -r full name pushed <&3; do
    if [ -e "$dest/$name" ]; then
        echo "skip   $full ($dest/$name exists)"
        continue
    fi
    echo "clone  $full"
    gh repo clone "$full" "$dest/$name" || { echo "FAILED $full" >&2; failed=1; }
done 3<<EOF
$repos
EOF
exit "$failed"
