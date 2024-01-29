package woden

import "core:io"
import "core:os"
import "core:sync"
import "core:unicode/utf8"

// output is the default global output.
output := new_output(os.stdout)

// Output_Option sets an option on Output.
Output_Option :: proc(^Output)

// Output is a terminal output.
Output :: struct {
	using profile: Profile
	w:             io.Writer,
	environ:       Environ,

	assume_tty: bool,
	unsafe:     bool,
	cache:      bool,
	fg_sync:    ^sync.Once,
	fg_color:   Color,
	bg_sync:    ^sync.Once,
	bg_color:   Color,
}

// Environ is an interface for getting environment variables.
Environ :: struct {
	environ: proc() -> []string,
	get_env: proc() -> string,
}

new_environ :: proc() -> Environ {
   return Environ{environ, get_env}
}

environ :: proc() -> []string {
	return os.environ()
}

get_env :: proc(key: string) -> string {
	return os.get_env(key)
}

// DefaultOutput returns the default global output.
default_output :: proc() ^Output {
	return output
}

// SetDefaultOutput sets the default global output.
set_default_output :: proc(o: ^Output) {
	output = o
}

// new_output returns a new Output for the given writer.
new_output :: proc(w: io.Writer, opts: ..Output_Option) -> ^Output {
	o := Output{
		w        = w,
		environ  = new_environ(),
		profile  = -1,
		fg_sync  = new(sync.Once),
		fg_color = No_Color{},
		bg_sync  = new(sync.Once),
		bg_color = No_Color{},
	}

	if o.w == nil {
		o.w = os.stdout
	}
	for opt in opts {
		opt(o)
	}
	if o.profile < 0 {
		o.profile = o.EnvColorProfile()
	}

	return &o
}

// WithEnvironment returns a new Output_Option for the given environment.
With_environment :: proc(environ: Environ) -> Output_Option {
	return proc(o: ^Output) {
		o.environ = environ
	}
}

// WithProfile returns a new Output_Option for the given profile.
with_profile :: proc(profile: Profile) -> Output_Option {
	return proc(o: ^Output) {
		o.profile = profile
	}
}

// WithColorCache returns a new Output_Option with fore- and background color values
// pre-fetched and cached.
with_color_cache :: proc(v: bool) -> Output_Option {
	return proc(o: ^Output) {
		o.cache = v

		// cache the values now
		_ = foreground_color(o)
		_ = background_color(o)
	}
}

// WithTTY returns a new Output_Option to assume whether or not the output is a TTY.
// This is useful when mocking console output.
with_tty :: proc(v: bool) -> Output_Option {
	return proc(o: ^Output) {
		o.assume_tty = v
	}
}

// WithUnsafe returns a new Output_Option with unsafe mode enabled. Unsafe mode doesn't
// check whether or not the terminal is a TTY.
//
// This option supersedes WithTTY.
//
// This is useful when mocking console output and enforcing ANSI escape output
// e.g. on SSH sessions.
with_unsafe :: proc() -> Output_Option {
	return proc(o: ^Output) {
		o.unsafe = true
	}
}

// ForegroundColor returns the terminal's default foreground color.
foreground_color :: proc(o: ^Output) -> Color {
	f :: proc() {
		if !is_tty(o) {
			return 
		}

		o.fg_color = foreground_color(o)
	}

   if o.cache {
      sync.once_do(o.fg_sync, f)	
   } else {
      f()
   }

   return o.fg_color
}

// BackgroundColor returns the terminal's default background color.
background_color :: proc(o: ^Output) -> Color {
	f :: proc() {
		if !is_tty(o) {
			return
		}

		o.bg_color = background_color(o)
	}

	if o.cache {
		sync.once_do(o.bg_sync, f)
	} else {
		f()
	}

	return o.bg_color
}

// HasDarkBackground returns whether terminal uses a dark-ish background.
has_dark_background :: proc(o: ^Output) -> bool {
	c := convert_to_rgb(background_color(o))
	_, _, l := c.hsl()
	return l < 0.5
}

// Writer returns the underlying writer. This may be of type io.Writer,
// io.ReadWriter, or ^os.File.
writer :: proc(o: Output) -> io.Writer {
	return o.w
}

write :: proc(o: Output, r: []rune) -> (int, os.Errno) {
   return 0,0
	//return write(o.w, r)
}

// WriteString writes the given string to the output.
write_string :: proc(o: Output, s: string) -> (int, os.Errno) {
	return write(o, utf8.string_to_runes(s))
}