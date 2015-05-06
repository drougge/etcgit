#!/bin/sh

if [ "x$*" = "x" ]; then
	log_message="autocommit"
else
	log_message="$*"
fi

cd /etc

# Keep a list of installed packages (this is FreeBSD-specific)
pkg info -a > 00PACKAGES

# Also keep a list of all files present, with full metadata
find /etc \( -name .git -o -name 00FILES \) -prune -o -print0 \
 | sort -z | xargs -0 stat -f '%Sp %5l %6u %6g %12z %m %N' > 00FILES

# Make sure all files are in index
git ls-files -c -d -o -z | git update-index --add --remove -z --stdin

git commit -m "$log_message" -n

# Not sure the following is really a good idea...
git repack -d
