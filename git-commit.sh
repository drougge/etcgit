#!/bin/sh

if [ "x$*" = "x" ]; then
	log_message="autocommit"
else
	log_message="$*"
fi

cd /etc

# I need spaces in words in my "array" vars, so I use _ as the delimiter instead
IFS=_

# Defaults, selectively overridden in case below
STATCMD="stat_-f_%Sp %5l %6u %6g %12z %m %N"
SORTCMD="sort_-z"

# Choose commands based on kernel name and some other things for Linux
case "`uname`" in
	Linux)
		STATCMD="stat_-c_%A %5h %6u %6g %12s %Y %n"
		# Keep a list of installed packages
		if [ -e /etc/debian_version ]; then
			COLUMNS=160 dpkg -l > 00PACKAGES
		elif [ -e /etc/redhat-release ]; then
			rpm -qa | sort > 00PACKAGES
		else
			echo >&2 "Unknown Linux dist"
			exit 1
		fi
		;;
	FreeBSD)
		# Keep a list of installed packages
		pkg info -a > 00PACKAGES
		;;
	NetBSD)
		SORTCMD="sort_-R\\0"
		# Keep a list of installed packages
		pkgin list > 00PACKAGES
		;;
	*)
		echo >&2 "Unknown OS"
		exit 1
		;;
esac

# Also keep a list of all files present, with full metadata
find /etc \( -name .git -o -name 00FILES \) -prune -o -print0 \
 | $SORTCMD | xargs -0 $STATCMD > 00FILES

# Make sure all files are in index
git ls-files -c -d -o -z | git update-index --add --remove -z --stdin

git commit -m "$log_message" -n

# repack every now and then
if [ `dd if=/dev/urandom bs=1 count=1 2>/dev/null | od -iAn` -lt 16 ]; then
	git repack -d
fi
