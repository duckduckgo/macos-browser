#!/usr/bin/env bats

setup() {
	DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
	# make executables in ./../../ visible to PATH
	PATH="$DIR/../..:$PATH"
}

main() {
	bash extract_release_notes.sh "$@"
}

#
# Functions below define inputs and expected outputs for the tests
#

# Placeholder release notes with placeholder Privacy Pro section
placeholder() {
	local mode="${1:-input}"
	case "$mode" in
		input)
			cat <<-EOF
			Note: This task's description is managed automatically.
			Only the Release notes section below should be modified manually.
			Please do not adjust formatting.

			Release notes

				<-- Add release notes here -->

			For Privacy Pro subscribers

				<-- Add release notes here -->

			This release includes:
			EOF
			;;
		raw)
			cat <<-EOF
			<-- Add release notes here -->
			EOF
			;;
		html)
			cat <<-EOF
			<h3 style="font-size:14px">What's new</h3>
			<ul>
			<li>&lt;-- Add release notes here --&gt;</li>
			</ul>
			EOF
			;;
		asana)
			cat <<-EOF
			<ul><li>&lt;-- Add release notes here --&gt;</li></ul>
			EOF
			;;
	esac
}

# Non-empty release notes with non-empty Privacy Pro section
full() {
	local mode="${1:-input}"
	case "$mode" in
		input)
			cat <<-EOF
			Note: This task's description is managed automatically.
			Only the Release notes section below should be modified manually.
			Please do not adjust formatting.

			Release notes

				You can now find browser windows listed in the "Window" app menu and in the Dock menu.
				We also added "Duplicate Tab" to the app menu so you can use it as an action in Apple Shortcuts.
				When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.
				The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.

			For Privacy Pro subscribers

				VPN updates! More detailed connection info in the VPN dashboard, plus animations and usability improvements.
				Visit https://duckduckgo.com/pro for more information. Privacy Pro is currently available to U.S. residents only.

			This release includes:

				https://app.asana.com/0/0/0/f/
				https://app.asana.com/0/0/0/f/
				https://app.asana.com/0/0/0/f/
			EOF
			;;
		raw)
			cat <<-EOF
			You can now find browser windows listed in the "Window" app menu and in the Dock menu.
			We also added "Duplicate Tab" to the app menu so you can use it as an action in Apple Shortcuts.
			When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.
			The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.
			For Privacy Pro subscribers
			VPN updates! More detailed connection info in the VPN dashboard, plus animations and usability improvements.
			Visit https://duckduckgo.com/pro for more information. Privacy Pro is currently available to U.S. residents only.
			EOF
			;;
		html)
			cat <<-EOF
			<h3 style="font-size:14px">What's new</h3>
			<ul>
			<li>You can now find browser windows listed in the "Window" app menu and in the Dock menu.</li>
			<li>We also added "Duplicate Tab" to the app menu so you can use it as an action in Apple Shortcuts.</li>
			<li>When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.</li>
			<li>The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.</li>
			</ul>
			<h3 style="font-size:14px">For Privacy Pro subscribers</h3>
			<ul>
			<li>VPN updates! More detailed connection info in the VPN dashboard, plus animations and usability improvements.</li>
			<li>Visit <a href="https://duckduckgo.com/pro">https://duckduckgo.com/pro</a> for more information. Privacy Pro is currently available to U.S. residents only.</li>
			</ul>
			EOF
			;;
		asana)
			cat <<-EOF
			<ul><li>You can now find browser windows listed in the "Window" app menu and in the Dock menu.</li><li>We also added "Duplicate Tab" to the app menu so you can use it as an action in Apple Shortcuts.</li><li>When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.</li><li>The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.</li></ul><h2>For Privacy Pro subscribers</h2><ul><li>VPN updates! More detailed connection info in the VPN dashboard, plus animations and usability improvements.</li><li>Visit <a href="https://duckduckgo.com/pro">https://duckduckgo.com/pro</a> for more information. Privacy Pro is currently available to U.S. residents only.</li></ul>
			EOF
			;;
	esac
}

# Non-empty release notes and missing Privacy Pro section
without_privacy_pro_section() {
	local mode="${1:-input}"
	case "$mode" in
		input)
			cat <<-EOF
			Note: This task's description is managed automatically.
			Only the Release notes section below should be modified manually.
			Please do not adjust formatting.

			Release notes

				You can now find browser windows listed in the "Window" app menu and in the Dock menu.
				We also added "Duplicate Tab" to the app menu so you can use it as an action in Apple Shortcuts.
				When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.
				The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.

			This release includes:

				https://app.asana.com/0/0/0/f/
				https://app.asana.com/0/0/0/f/
				https://app.asana.com/0/0/0/f/
			EOF
			;;
		raw)
			cat <<-EOF
			You can now find browser windows listed in the "Window" app menu and in the Dock menu.
			We also added "Duplicate Tab" to the app menu so you can use it as an action in Apple Shortcuts.
			When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.
			The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.
			EOF
			;;
		html)
			cat <<-EOF
			<h3 style="font-size:14px">What's new</h3>
			<ul>
			<li>You can now find browser windows listed in the "Window" app menu and in the Dock menu.</li>
			<li>We also added "Duplicate Tab" to the app menu so you can use it as an action in Apple Shortcuts.</li>
			<li>When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.</li>
			<li>The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.</li>
			</ul>
			EOF
			;;
		asana)
			cat <<-EOF
			<ul><li>You can now find browser windows listed in the "Window" app menu and in the Dock menu.</li><li>We also added "Duplicate Tab" to the app menu so you can use it as an action in Apple Shortcuts.</li><li>When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.</li><li>The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.</li></ul>
			EOF
			;;
	esac
}

# Non-empty release notes and a placeholder Privacy Pro section
placeholder_privacy_pro_section() {
	local mode="${1:-input}"
	case "$mode" in
		input)
			cat <<-EOF
			Note: This task's description is managed automatically.
			Only the Release notes section below should be modified manually.
			Please do not adjust formatting.

			Release notes

				You can now find browser windows listed in the "Window" app menu and in the Dock menu.
				We also added "Duplicate Tab" to the app menu so you can use it as an action in Apple Shortcuts.
				When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.
				The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.

			For Privacy Pro subscribers

				<-- Add release notes here -->

			This release includes:

				https://app.asana.com/0/0/0/f/
				https://app.asana.com/0/0/0/f/
				https://app.asana.com/0/0/0/f/
			EOF
			;;
		*)
			without_privacy_pro_section "$mode"
			;;
	esac
}

# Non-empty release notes and Privacy Pro release header as a bullet point inside regular release notes
# Privacy Pro section header should be recognized and interpreted as a separate section (like in the full example)
privacy_pro_in_regular_release_notes() {
	local mode="${1:-input}"
	case "$mode" in
		input)
			cat <<-EOF
			Note: This task's description is managed automatically.
			Only the Release notes section below should be modified manually.
			Please do not adjust formatting.

			Release notes

				You can now find browser windows listed in the "Window" app menu and in the Dock menu.
				We also added "Duplicate Tab" to the app menu so you can use it as an action in Apple Shortcuts.
				When watching videos in Duck Player, clicking endscreen recommendations will now open those videos in the same tab.
				The bug that duplicated sites in your browsing history has been fixed, and the visual glitching that sometimes occurred during session restore and app launch has been addressed.
				For Privacy Pro subscribers
				VPN updates! More detailed connection info in the VPN dashboard, plus animations and usability improvements.
				Visit https://duckduckgo.com/pro for more information. Privacy Pro is currently available to U.S. residents only.

			This release includes:

				https://app.asana.com/0/0/0/f/
				https://app.asana.com/0/0/0/f/
				https://app.asana.com/0/0/0/f/
			EOF
			;;
		*)
			full "$mode"
			;;
	esac
}

#
# Test cases start here
#

# bats test_tags=placeholder, raw
@test "input: placeholder | output: raw" {
	run main -r <<< "$(placeholder)"
	[ "$status" -eq 0 ]
	[ "$output" == "$(placeholder raw)" ]
}

# bats test_tags=placeholder, html
@test "input: placeholder | output: html" {
	run main -h <<< "$(placeholder)"
	[ "$status" -eq 0 ]
	[ "$output" == "$(placeholder html)" ]
}

# bats test_tags=placeholder, asana
@test "input: placeholder | output: asana" {
	run main -a <<< "$(placeholder)"
	[ "$status" -eq 0 ]
	[ "$output" == "$(placeholder asana)" ]
}

# bats test_tags=full, raw
@test "input: full | output: raw" {
	run main -r <<< "$(full)"
	[ "$status" -eq 0 ]
	[ "$output" == "$(full raw)" ]
}

# bats test_tags=full, html
@test "input: full | output: html" {
	run main -h <<< "$(full)"
	[ "$status" -eq 0 ]
	[ "$output" == "$(full html)" ]
}

# bats test_tags=full, asana
@test "input: full | output: asana" {
	run main -a <<< "$(full)"
	[ "$status" -eq 0 ]
	[ "$output" == "$(full asana)" ]
}

# bats test_tags=no-pp, raw
@test "input: without_privacy_pro_section | output: raw" {
	run main -r <<< "$(without_privacy_pro_section)"
	[ "$status" -eq 0 ]
	[ "$output" == "$(without_privacy_pro_section raw)" ]
}

# bats test_tags=no-pp, html
@test "input: without_privacy_pro_section | output: html" {
	run main -h <<< "$(without_privacy_pro_section)"
	[ "$status" -eq 0 ]
	[ "$output" == "$(without_privacy_pro_section html)" ]
}

# bats test_tags=no-pp, asana
@test "input: without_privacy_pro_section | output: asana" {
	run main -a <<< "$(without_privacy_pro_section)"
	[ "$status" -eq 0 ]
	[ "$output" == "$(without_privacy_pro_section asana)" ]
}

# bats test_tags=placeholder-pp, raw
@test "input: placeholder_privacy_pro_section | output: raw" {
	run main -r <<< "$(placeholder_privacy_pro_section)"
	[ "$status" -eq 0 ]
	[ "$output" == "$(placeholder_privacy_pro_section raw)" ]
}

# bats test_tags=placeholder-pp, html
@test "input: placeholder_privacy_pro_section | output: html" {
	run main -h <<< "$(placeholder_privacy_pro_section)"
	[ "$status" -eq 0 ]
	[ "$output" == "$(placeholder_privacy_pro_section html)" ]
}

# bats test_tags=placeholder-pp, asana
@test "input: placeholder_privacy_pro_section | output: asana" {
	run main -a <<< "$(placeholder_privacy_pro_section)"
	[ "$status" -eq 0 ]
	[ "$output" == "$(placeholder_privacy_pro_section asana)" ]
}

# bats test_tags=inline-pp, raw
@test "input: privacy_pro_in_regular_release_notes | output: raw" {
	run main -r <<< "$(privacy_pro_in_regular_release_notes)"
	[ "$status" -eq 0 ]
	[ "$output" == "$(privacy_pro_in_regular_release_notes raw)" ]
}

# bats test_tags=inline-pp, html
@test "input: privacy_pro_in_regular_release_notes | output: html" {
	run main -h <<< "$(privacy_pro_in_regular_release_notes)"
	[ "$status" -eq 0 ]
	[ "$output" == "$(privacy_pro_in_regular_release_notes html)" ]
}

# bats test_tags=inline-pp, asana
@test "input: privacy_pro_in_regular_release_notes | output: asana" {
	run main -a <<< "$(privacy_pro_in_regular_release_notes)"
	[ "$status" -eq 0 ]
	[ "$output" == "$(privacy_pro_in_regular_release_notes asana)" ]
}
