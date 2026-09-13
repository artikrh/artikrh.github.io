#!/bin/sh
set -e

echo -n "[*] Enter a commit message: "
read input

if [ -z "$input" ]
then
	echo "[*] No commit message was entered!"
else
	bundle install --quiet
	bundle exec jekyll build
	git add .
	git commit -m "$input"
	git push origin master
	echo "[*] Git push successful"
fi
