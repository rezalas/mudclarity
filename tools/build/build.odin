/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package build

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

/*
 The build script, written in Odin so it runs the same on Windows, macOS
 and Linux. build.sh and build.bat only compile and run this with
 `odin run tools/build -- <command>`; every flag lives here.
*/

USAGE :: `usage: build.sh | build.bat [command]
  (none)              Debug build to build/mudclarity
  run [args...]       Build, then run the app with args
  test                Vet our packages and run every package's tests
  test <name>         Run one test, e.g. formats.test_room_basic_fields
  debug-tests         Build each package's tests for a debugger, to build/<package>_test_debug
  debug-tests <name>  Build one test for a debugger, to build/single_test_debug
  help                This text

Set RIFTSHADOW_AREA_DIR to a Riftshadow area/ directory to also parse every
area in its area.lst during test and debug-tests.`

SKALD_COLLECTION :: "-collection:gui=vendor/skald"

// Packages with tests, in the order they run.
TEST_PACKAGES :: [?]string{"formats", "validation", "clarity", "workspace", "cli", "layout", "components", "app"}

// Our packages, for -vet-packages: vendor/skald does not pass -vet.
OUR_PACKAGES :: "main,formats,models,validation,clarity,workspace,cli,layout,components,app,testkit"

// Packages that import Skald. -strict-style applies to every package
// compiled, Skald included, so their tests get -vet-style on our packages
// instead.
SKALD_PACKAGES :: [?]string{"components", "app"}

// Targets every `test` type-checks the program for, whatever the host, so
// an OS-specific mistake shows up on any developer's machine. Windows is
// left out because `odin check` can only target it from Windows (it needs
// the Windows SDK), where the normal check covers it.
CROSS_TARGETS :: [?]string{"darwin_arm64", "darwin_amd64", "linux_amd64", "linux_arm64"}

EXE :: ".exe" when ODIN_OS == .Windows else ""

APP_PATH :: "build/mudclarity" + EXE

main :: proc() {
	args := os.args[1:]
	command := args[0] if len(args) > 0 else ""
	rest := args[1:] if len(args) > 0 else nil
	if err := os.make_directory("build"); err != nil && err != .Exist {
		fail("could not create build/: %v", err)
	}
	copy_runtime_libraries()

	switch command {
	case "":
		build_app()
	case "run":
		build_app()
		command := make([dynamic]string, context.temp_allocator)
		append(&command, APP_PATH)
		append(&command, ..rest)
		run(command[:])
	case "test":
		test(rest[0] if len(rest) > 0 else "")
	case "debug-tests":
		debug_tests(rest[0] if len(rest) > 0 else "")
	case "help", "-h", "--help":
		fmt.println(USAGE)
	case:
		fmt.eprintfln("unknown command %q\n\n%s", command, USAGE)
		os.exit(2)
	}
}

build_app :: proc() {
	odin("build", ".", SKALD_COLLECTION, "-debug", "-out:" + APP_PATH)
}

// Vet everything, then run each package's tests; or run the one test `name`.
test :: proc(name: string) {
	packages := TEST_PACKAGES
	selected := packages[:]
	extra: []string
	if name != "" {
		selected = {package_of(name)}
		extra = {fmt.tprintf("-define:ODIN_TEST_NAMES=%s", name)}
	} else {
		odin("check", ".", SKALD_COLLECTION, "-vet", "-vet-style", "-vet-packages:" + OUR_PACKAGES)
		for target in CROSS_TARGETS {
			odin("check", ".", SKALD_COLLECTION, fmt.tprintf("-target:%s", target))
		}
		odin("check", "tools/build", "-vet", "-strict-style")
	}
	for p in selected {
		flags := make([dynamic]string, context.temp_allocator)
		append(&flags, "test", p, SKALD_COLLECTION, "-vet")
		append(&flags, ..style_flags(p))
		append(&flags, ..corpus_flags())
		append(&flags, ..extra)
		append(&flags, fmt.tprintf("-out:build/%s_test%s", p, EXE))
		odin(..flags[:])
	}
}

// Test binaries to run under a debugger. One test thread keeps breakpoints
// in order; ODIN_TEST_NAMES and ODIN_TEST_THREADS are compile-time
// settings, hence a separate build.
debug_tests :: proc(name: string) {
	if name != "" {
		debug_build(package_of(name), "build/single_test_debug" + EXE, fmt.tprintf("-define:ODIN_TEST_NAMES=%s", name))
		return
	}
	for p in TEST_PACKAGES {
		debug_build(p, fmt.tprintf("build/%s_test_debug%s", p, EXE))
	}
}

debug_build :: proc(package_name, out: string, extra: ..string) {
	flags := make([dynamic]string, context.temp_allocator)
	append(&flags, "build", package_name, "-build-mode:test", SKALD_COLLECTION, "-debug", "-define:ODIN_TEST_THREADS=1")
	append(&flags, ..corpus_flags())
	append(&flags, ..extra)
	append(&flags, fmt.tprintf("-out:%s", out))
	odin(..flags[:])
}

// On Windows, SDL3.dll must sit next to the executables that use Skald;
// the app and every test binary are built into build/. Odin ships the DLL
// in vendor/sdl3. It is copied again when its size changes (an Odin
// upgrade).
copy_runtime_libraries :: proc() {
	when ODIN_OS == .Windows {
		source :: ODIN_ROOT + "vendor/sdl3/SDL3.dll"
		target :: "build/SDL3.dll"
		have, have_err := os.stat(target, context.temp_allocator)
		want, want_err := os.stat(source, context.temp_allocator)
		if want_err != nil {
			fail("could not find %s: %v", source, want_err)
		}
		if have_err == nil && have.size == want.size {
			return
		}
		if err := os.copy_file(target, source); err != nil {
			fail("could not copy %s to build/: %v", source, err)
		}
	}
}

style_flags :: proc(package_name: string) -> []string {
	skald_packages := SKALD_PACKAGES
	if slice.contains(skald_packages[:], package_name) {
		return slice.clone([]string{"-vet-style", "-vet-packages:" + OUR_PACKAGES}, context.temp_allocator)
	}
	return slice.clone([]string{"-strict-style"}, context.temp_allocator)
}

// The define that turns on corpus tests, if RIFTSHADOW_AREA_DIR is set.
corpus_flags :: proc() -> []string {
	dir := os.get_env("RIFTSHADOW_AREA_DIR", context.temp_allocator)
	if dir == "" {
		return nil
	}
	return slice.clone([]string{fmt.tprintf("-define:MUDCLARITY_CORPUS_DIR=%s", dir)}, context.temp_allocator)
}

// The package of a test name ("formats.test_x" -> "formats"), checked
// against TEST_PACKAGES.
package_of :: proc(name: string) -> string {
	dot := strings.index_byte(name, '.')
	packages := TEST_PACKAGES
	if dot > 0 && slice.contains(packages[:], name[:dot]) {
		return name[:dot]
	}
	fail("not a test name: %s (expected <package>.<test>, package one of %v)", name, packages)
}

// Run the Odin compiler with `args`; stop the build if it fails.
odin :: proc(args: ..string) {
	command := make([dynamic]string, context.temp_allocator)
	append(&command, "odin")
	append(&command, ..args)
	run(command[:])
}

// Run a program, sharing this process's terminal; exit with its code if it
// fails.
run :: proc(command: []string) {
	process, err := os.process_start({command = command, stdin = os.stdin, stdout = os.stdout, stderr = os.stderr})
	if err != nil {
		fail("could not run %s: %v", command[0], err)
	}
	state, wait_err := os.process_wait(process)
	if wait_err != nil {
		fail("waiting for %s: %v", command[0], wait_err)
	}
	if !state.success {
		os.exit(state.exit_code if state.exit_code != 0 else 1)
	}
}

fail :: proc(format: string, args: ..any) -> ! {
	fmt.eprintfln(format, ..args)
	os.exit(2)
}
