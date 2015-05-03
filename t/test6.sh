
# Creates a git repo with negative patterns and ignore all pattern

git init
mkdir -p foo/bar
touch {,foo/,foo/bar/}{a,b,c,d,e}
echo * > .gitignore
echo '!foo/bar/a' >> .gitignore
