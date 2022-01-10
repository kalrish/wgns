#!/usr/bin/env -S --debug -- bash

set \
	-e \
	#

declare \
	-i \
	-- \
	exit_code=0 \
	#

function show_usage
{
	echo "usage: $0 <up|down> NAMESPACE" >&2
}

if [[ $@ = ?(-)?(-)help ]]
then
	show_usage
elif [[ $# -eq 2 ]]
then
	declare \
		-r \
		-- \
		subcommand="$1" \
		namespace="$2" \
		#

	case "${subcommand}" in
		down)
			# Delete the network namespace
			ip \
				netns del \
				"${namespace}" \
				#
			echo "info: network namespace '${namespace}' deleted" >&2
			# The WireGuard interface within the namespace is deleted automatically,
			# so it isn't necessary to run `ip -netns ${namespace} link delete dev wg0`
			;;
		up)
			# Create the network namespace
			ip \
				netns add \
				"${namespace}" \
				#
			echo "info: network namespace '${namespace}' created" >&2

			# Network devices within the same network namespace must have unique names.
			# Since the WireGuard interface is created in a shared namespace at first,
			# steps must be taken to reduce the risk of a name collision.
			# For `$RANDOM` see the Bash manual:
			# https://www.gnu.org/software/bash/manual/bash#index-RANDOM
			interface="wgnetns-${RANDOM}"
			# The WireGuard interface is renamed to `wg0` later, once it has been moved
			# into its own namespace

			# Create the WireGuard interface in the current network namespace
			ip \
				link add \
				dev "${interface}" \
				type wireguard \
				#
			echo "info: WireGuard interface created under temporary name '${interface}'" >&2

			# Try to move the WireGuard interface into the new network namespace
			if
				ip \
					link set \
					dev "${interface}" \
					netns "${namespace}" \
					#
			then
				echo "debug: WireGuard interface '${interface}' moved into network namespace '${namespace}'" >&2

				# Network devices in different network namespaces can have the same name.
				# Take advantage of this to provide the WireGuard interface with a more
				# reasonable name.
				ip \
					-netns "${namespace}" \
					link set \
					dev "${interface}" \
					name wg0 \
					#
				echo "debug: WireGuard interface renamed to 'wg0' inside network namespace '${namespace}'" >&2
			else
				echo "error: cannot move WireGuard interface '${interface}' into network namespace '${namespace}'" >&2
				exit_code=1

				ip \
					-netns "${namespace}" \
					link delete \
					dev "${interface}" \
					#
				echo "info: WireGuard interface '${interface}' deleted" >&2
			fi
			;;
		*)
			show_usage
			exit_code=1
			;;
	esac
else
	show_usage
	exit_code=1
fi

exit "${exit_code}"
