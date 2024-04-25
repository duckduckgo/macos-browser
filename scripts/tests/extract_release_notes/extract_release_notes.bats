#!/usr/bin/env bats

setup() {
	DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
	# make executables in src/ visible to PATH
	PATH="$DIR/../..:$PATH"
}

main() {
	bash extract_release_notes.sh "$@"
}

# bats test_tags=placeholder, raw
@test "placeholder raw output" {
	run main -r < placeholder.txt
	[ "$status" -eq 0 ]
	[ "$output" == "$(<placeholder-output-raw.txt)" ]
}

# bats test_tags=placeholder, html
@test "placeholder HTML output" {
	run main -h < placeholder.txt
	[ "$status" -eq 0 ]
	[ "$output" == "$(<placeholder-output-html.txt)" ]
}

# bats test_tags=placeholder, asana
@test "placeholder Asana output" {
	run main -a < placeholder.txt
	[ "$status" -eq 0 ]
	[ "$output" == "$(<placeholder-output-asana.txt)" ]
}

# bats test_tags=full, raw
@test "full raw output" {
	run main -r < full.txt
	[ "$status" -eq 0 ]
	[ "$output" == "$(<full-output-raw.txt)" ]
}

# bats test_tags=full, html
@test "full HTML output" {
	run main -h < full.txt
	[ "$status" -eq 0 ]
	[ "$output" == "$(<full-output-html.txt)" ]
}

# bats test_tags=full, asana
@test "full Asana output" {
	run main -a < full.txt
	[ "$status" -eq 0 ]
	[ "$output" == "$(<full-output-asana.txt)" ]
}

# bats test_tags=no-pp, raw
@test "no-pp raw output" {
	run main -r < no-pp.txt
	[ "$status" -eq 0 ]
	[ "$output" == "$(<no-pp-output-raw.txt)" ]
}

# bats test_tags=no-pp, html
@test "no-pp HTML output" {
	run main -h < no-pp.txt
	[ "$status" -eq 0 ]
	[ "$output" == "$(<no-pp-output-html.txt)" ]
}

# bats test_tags=no-pp, asana
@test "no-pp Asana output" {
	run main -a < no-pp.txt
	[ "$status" -eq 0 ]
	[ "$output" == "$(<no-pp-output-asana.txt)" ]
}

# bats test_tags=placeholder-pp, raw
@test "placeholder-pp raw output" {
	run main -r < placeholder-pp.txt
	[ "$status" -eq 0 ]
	[ "$output" == "$(<no-pp-output-raw.txt)" ]
}

# bats test_tags=placeholder-pp, html
@test "placeholder-pp HTML output" {
	run main -h < placeholder-pp.txt
	[ "$status" -eq 0 ]
	[ "$output" == "$(<no-pp-output-html.txt)" ]
}

# bats test_tags=placeholder-pp, asana
@test "placeholder-pp Asana output" {
	run main -a < placeholder-pp.txt
	[ "$status" -eq 0 ]
	[ "$output" == "$(<no-pp-output-asana.txt)" ]
}
