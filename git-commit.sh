#!/bin/sh

# See if git is installed or exit
which git > /dev/null 2>&1 || exit $?

if [ "x$*" = "x" ]; then
	log_message="autocommit"
else
	log_message="$*"
fi

ETCDIR="/etc"

# I need spaces in words in my "array" vars, so I use _ as the delimiter instead
IFS=_

# Defaults, selectively overridden in case below
STATCMD="stat_-f_%Sp %5l %6u %6g %12z %m %N"
SORTCMD="sort_-z"

# Keep a list of all files present, with full metadata
findFunction() {
	find "$ETCDIR" \( -name .git -o -name 00FILES -o -name 00PACKAGES \) \
	 -prune -o -print0 | $SORTCMD | xargs -0 $STATCMD > "$ETCDIR"/00FILES
}

gitFunction() {
	cd "$ETCDIR"
	if [ ! -d .git ]; then
		git init
		chmod 700 .git
		git config user.name "The Devil himself"
		git config user.email "root@`hostname`"
	fi

	# Make sure all files are in index
	git ls-files -c -d -o -z | git update-index --add --remove -z --stdin

	git commit -m "$log_message" -n |\
		grep -v -e "On branch master" \
			-e "nothing to commit"

	# repack every now and then
	if [ `dd if=/dev/urandom bs=1 count=1 2>/dev/null | \
	od -iAn` -lt 16 ]; then
		git repack -d -q
	fi
}

# Choose commands based on kernel name and some other things for Linux
case "`uname`" in
	Linux)
		STATCMD="stat_-c_%A %5h %6u %6g %12s %Y %n"
		# Keep a list of installed packages
		if [ -e /etc/debian_version ]; then
			COLUMNS=160 dpkg -l > "$ETCDIR/00PACKAGES"
		elif [ -e /etc/redhat-release ]; then
			rpm -qa | sort > "$ETCDIR/00PACKAGES"
		elif [ -e /etc/alpine-release ]; then
			apk -vv info | sort > "$ETCDIR/00PACKAGES"
		else
			echo >&2 "Unknown Linux dist"
			exit 1
		fi
		(findFunction)
		(gitFunction)
		;;
	FreeBSD)
		# Mainly for cron
		PATH="$PATH":/usr/local/bin
		# Keep a list of installed packages
		pkg info -a > "$ETCDIR/00PACKAGES"
		(findFunction)
		(gitFunction)
		ETCDIR="/usr/local/etc"
		(findFunction)
		(gitFunction)
		;;
	OpenBSD)
		# Keep a list of installed packages
		pkg_info -a > "$ETCDIR/00PACKAGES"
		(findFunction)
		(gitFunction)
		;;
	NetBSD)
		SORTCMD="sort_-R\\0"
		# Keep a list of installed packages
		pkgin list > "$ETCDIR/00PACKAGES"
		(findFunction)
		(gitFunction)
		;;
	*)
		echo >&2 "Unknown OS"
		exit 1
		;;
esac
