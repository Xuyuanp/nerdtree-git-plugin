
# Creates a git repo with dir ignore

git init
mkdir -p foo/bar
touch {,foo/,foo/bar/}{a,b,c,d,e}
echo 'foo/bar' >> .gitignore
