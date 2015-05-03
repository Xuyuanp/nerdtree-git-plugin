
# Creates a git repo with spaces on path

mkdir "a repo"
cd "a repo"
git init
mkdir -p foo/bar
touch {,foo/,foo/bar/}{a,b,c,d,e}
echo a > .gitignore
echo 'foo/b' >> .gitignore
