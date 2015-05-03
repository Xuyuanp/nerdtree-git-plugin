
# Creates a git repo with nested .gitignore

git init
mkdir -p foo/bar
touch {,foo/,foo/bar/}{a,b,c,d,e}
echo a > .gitignore
echo b > foo/.gitignore
echo c > foo/bar/.gitignore

