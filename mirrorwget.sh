#!/bin/bash
# Support downloading from 'mirror://' links from within wget.
# (C) 2010 Michał Górny <gentoo@mgorny.alt.pl>
# Released under the terms of the 3-clause BSD license.

getmirrors() {
	local mirrorname portdir overlays repo fn awkscript gmirrors umirrors i
	mirrorname=${1}
	portdir=$(portageq portdir)
	overlays=$(portageq portdir_overlay)

	set --

	for repo in "${portdir}" ${overlays}; do
		fn="${repo}"/profiles/thirdpartymirrors
		[ -r "${fn}" ] && set -- "${@}" "${fn}"
	done

	# We need to call awk twice in order to get the 'gentoo' mirrors first.
	awkscript='
$1 == "_MIRROR_" {
	for (i = 2; i < NF; i++)
		print $i
	exit(64)
}'

	gmirrors=$(awk "${awkscript/_MIRROR_/gentoo}" "${1}")
	umirrors=$(awk "${awkscript/_MIRROR_/${mirrorname}}" "${@}")

	if [ ${PIPESTATUS} -ne 64 ]; then
		echo "Warning: mirror '${mirrorname}' not found in thirdpartymirrors!" >&2
		echo ${gmirrors} # XXX: shuffle
	else
		set -- ${gmirrors}

		# Shift to a random argument.
		i=$(( RANDOM % ${#} ))
		while [ ${i} -gt 0 ]; do
			shift
			: $(( i -= 1 ))
		done

		echo ${1}
		echo ${umirrors} # XXX: shuffle
	fi
}

main() {
	local argcount gotnc gotm arg mirroruri mirrorname mirrorpath mirror
	argcount=${#}
	gotnc=0
	gotm=0

	while [ ${argcount} -gt 0 ]; do
		arg=${1}
		mirroruri=${arg#mirror://}
		shift
		: $(( argcount -= 1 ))

		if [ ${mirroruri} != ${arg} ]; then
			# Get the mirrors here, and happily append them.
			mirrorname=${mirroruri%%/*}
			mirrorpath=${mirroruri#*/}

			for mirror in $(getmirrors "${mirrorname}"); do
				set -- "${@}" "${mirror}/${mirrorpath}"
			done

			gotm=1
		else
			# Not a mirror, maybe an important option?
			[ "${arg}" = -nc -o "${arg}" = --no-clobber ] && gotnc=1
			[ "${arg}" = -c -o "${arg}" = --continue ] && gotnc=1

			# Anyway, reappend it.
			set -- "${@}" "${arg}"
		fi
	done

	if [ ${gotnc} -ne 1 -a ${gotm} -eq 1 ]; then
		echo 'Prepending the wget arguments with --no-clobber.' >&2
		set -- --no-clobber "${@}"
	fi

	exec wget "${@}"
}

main "${@}"
