
# Creates a git repo with simple ignore filter

git init
mkdir -p foo/bar
touch {,foo/,foo/bar/}{a,b,c,d,e}
echo a > .gitignore
