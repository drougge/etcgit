#!/bin/sh

if ! which git > /dev/null 2>&1; then
	echo >&2 This script needs git installed.
	exit 1
fi

if [ "x$*" = "x" ]; then
	log_message="autocommit"
else
	log_message="$*"
fi

cd /etc

if [ ! -d .git ]; then
	echo >&2 Run \"git init\" in /etc and configure whatever you need.
	exit 1
fi

# Avoid security disasters
chmod 700 .git

# I need spaces in words in my "array" vars, so I use _ as the delimiter instead
IFS=_

# Defaults, selectively overridden in case below
STATCMD="stat_-f_%Sp %5l %6u %6g %12z %m %N"
SORTCMD="sort_-z"
DIRS="/etc"

# Choose commands based on kernel name and some other things for Linux
case "`uname`" in
	Linux)
		STATCMD="stat_-c_%A %5h %6u %6g %12s %Y %n"
		# Keep a list of installed packages
		if [ -e /etc/debian_version ]; then
			COLUMNS=160 dpkg -l > 00PACKAGES
		elif [ -e /etc/redhat-release ]; then
			rpm -qa | sort > 00PACKAGES
		elif [ -e /etc/alpine-release ]; then
			apk -vv info | sort > 00PACKAGES
		else
			echo >&2 "Unknown Linux dist"
			exit 1
		fi
		;;
	FreeBSD)
		# Keep a list of installed packages
		pkg info -a > 00PACKAGES
		# Packages don't store their configuration in /etc on FreeBSD
		DIRS="${DIRS}_/usr/local/etc"
		;;
	OpenBSD)
		# Keep a list of installed packages
		pkg_info -a > 00PACKAGES
		;;
	NetBSD)
		SORTCMD="sort_-R\\0"
		# Keep a list of installed packages
		pkgin list > 00PACKAGES
		# Packages don't store their configuration in /etc on NetBSD
		DIRS="${DIRS}_/usr/pkg/etc"
		;;
	*)
		echo >&2 "Unknown OS"
		exit 1
		;;
esac

# Also keep a list of all files present, with full metadata
find $DIRS \( -name .git -o -name 00FILES -o -name 00PACKAGES \) -prune \
 -o -print0 | $SORTCMD | xargs -0 $STATCMD > 00FILES

# Extra DIRS require core.worktree to be / (we can't add files outside the tree)
if [ "$DIRS" != "/etc" -a "`git config --get core.worktree`" != "/" ]; then
	git config core.worktree /
fi

# Make sure all files are in index
git ls-files -c -d -o -z $DIRS | git update-index --add --remove -z --stdin

# Only commit if something changed
if ! git diff-index --quiet HEAD --ignore-submodules; then
	git commit -m "$log_message" -n

	# repack every now and then
	if [ `dd if=/dev/urandom bs=1 count=1 2>/dev/null | od -iAn` -lt 16 ]; then
		git repack -d
	fi
fi

# Try to keep "git status" output useful even when DIRS has more than just /etc
# This has a race if something modifies /etc after our update-index.
if [ "$DIRS" != "/etc" -a ! -e .git/etcgit.exclude ]; then
	git status --porcelain=v1 | sed 's/^\?\? //' > .git/etcgit.exclude
	git config core.excludesFile /etc/.git/etcgit.exclude
fi
