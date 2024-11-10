#!/bin/sh

echo -n "[*] Enter a commit message: "
read input

if [ -z "$input" ]
then
	echo "[*] No commit message was entered!"
else
	bundle update
	bundle exec jekyll build
	git add .
	git commit -m "$input"
	git push origin master
	echo -n "[*] Git push successful"
fi

