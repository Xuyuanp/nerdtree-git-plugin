
# Creates a git repo with negative patterns

git init
mkdir -p foo/bar
touch {,foo/,foo/bar/}{a,b,c,d,e}
echo a > .gitignore
echo '!foo/bar/a' >> .gitignore
