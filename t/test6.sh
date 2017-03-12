
# Creates a git repo with negative patterns and ignore all pattern

git init
mkdir -p foo/bar
touch {,foo/,foo/bar/}{a,b,c,d,e}
echo '*' > .gitignore
echo '!b' >> .gitignore
echo '!foo' >> .gitignore
echo '!foo/b' >> .gitignore
echo '!foo/bar' >> .gitignore
echo '!foo/bar/b' >> .gitignore
