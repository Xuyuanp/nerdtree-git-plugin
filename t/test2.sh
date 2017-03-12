
# Creates a git repo with exclude patterns

git init
mkdir -p foo/bar
touch {,foo/,foo/bar/}{a,b,c,d,e}
echo a > .git/info/exclude
