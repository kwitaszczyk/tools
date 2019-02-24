#!/bin/sh
#
# Copyright (c) 2018-2019 Konrad Witaszczyk <def@FreeBSD.org>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHORS AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

usage()
{
	echo "usage: pwdb command args ..."
	echo
	echo "	add <name>"
	echo "	del <name>"
	echo "	gen"
	echo "	get <name>"
	echo "	list"
	echo "  show <name>"
	exit 1
}

die()
{
	echo "${*}"
	exit 1
}

pwdb_read()
{
	gpg --decrypt "${PWDB_PATH}" 2>/dev/null
}

pwdb_write()
{
	local recipient recipients

	recipients=""
	for recipient in ${PWDB_IDS}; do
		recipients="${recipients} --recipient ${recipient}"
	done

	gpg --encrypt ${recipients} --output "${PWDB_PATH}.new"
	[ $? -eq 0 ] || die "GnuPG returned invalid value."
	mv "${PWDB_PATH}.new" "${PWDB_PATH}"
}

pwdb_clip()
{
	local password

	read password
	[ -n "${password}" ] || exit 1
	echo "${password}" | xclip -l 1
	echo "Password successfully copied."
}

pwdb_new()
{
	local password

	password=`openssl rand -base64 12 2>/dev/null`
	if [ $? -ne 0 ] || [ -z "${password}" ]; then
		die "OpenSSL returned invalid value." >&2
	fi

	echo "${password}"
}

pwdb_gen()
{
	pwdb_new | pwdb_clip
}

pwdb_get()
{
	local name

	name="$1"
	[ -n "${name}" ] || die "Missing name."

	pwdb_show "${name}" | pwdb_clip
}

pwdb_show()
{
	local name

	name="$1"
	[ -n "${name}" ] || die "Missing name."

	pwdb_read | sed -n "s/^${name}:\(.*\)$/\1/p"
}

pwdb_add()
{
	local name password

	name="$1"
	[ -n "${name}" ] || die "Missing name."

	password=`pwdb_show "${name}"`
	[ -z "${password}" ] || die "You must delete old password."

	password=`pwdb_new`

	(pwdb_read && echo "${name}:${password}") | pwdb_write || exit 1

	echo "${password}" | pwdb_clip
}

pwdb_del()
{
	local name

	name="$1"
	[ -n "${name}" ] || die "Missing name."

	pwdb_read | sed "/^${name}:.*$/d" | pwdb_write || exit 1
}

pwdb_list()
{
	pwdb_read | sed -n 's/^\(.*\):.*$/\1/p' | sort
}

main()
{
	[ -n "${PWDB_IDS}" ] || die "Missing identities."
	[ -f "${PWDB_PATH}" ] || die "Missing database file."

	case "$1" in
	"add")
		pwdb_add "$2"
		;;
	"del")
		pwdb_del "$2"
		;;
	"gen")
		pwdb_gen
		;;
	"get")
		pwdb_get "$2"
		;;
	"list")
		pwdb_list
		;;
	"show")
		pwdb_show "$2"
		;;
	*)
		usage
		;;
	esac
}

main "${@}"
