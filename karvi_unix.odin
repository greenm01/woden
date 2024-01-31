package karvi

import "core:time"
import "core:io"
import "core:fmt"
import "core:strings"

// Linux, Darwin FreeBSD, OpenBSD 
when ODIN_OS != .Windows {


/*
import (
	"fmt"
	"io"
	"strconv"
	"strings"
	"time"

	"golang.org/x/sys/unix"
)
*/


// timeout for OSC queries
OSC_TIMEOUT :: 5 * time.Second

// ColorProfile returns the supported color profile:
// Ascii, ANSI, ANSI256, or TrueColor.
output_color_profile :: proc(o: ^Output) -> Profile {
	using Profile
	if is_tty(o) {
		return Ascii
	}

	if getenv("GOOGLE_CLOUD_SHELL") == "true" {
		return True_Color
	}

	term := getenv("TERM")
	color_term := getenv("COLORTERM")

	switch strings.to_lower(color_term) {
	case "24bit":
		fallthrough
	case "truecolor":
		if strings.HasPrefix(term, "screen") {
			// tmux supports TrueColor, screen only ANSI256
			if getenv("TERM_PROGRAM") != "tmux" {
				return ANSI256
			}
		}
		return True_Color
	case "yes":
		fallthrough
	case "true":
		return ANSI256
	}

	switch term {
	case "xterm-kitty", "wezterm", "xterm-ghostty":
		return True_Color
	case "linux":
		return ANSI
	}

	if strings.contains(term, "256color") {
		return ANSI256
	}
	if strings.contains(term, "color") {
		return ANSI
	}
	if strings.contains(term, "ansi") {
		return ANSI
	}

	return Ascii
}

/*
output_foreground_color :: proc(o: Output) -> Color {
	using Error
	s, err := term_status_report(o, 10)
	if err == No_Error {
		c, err := x_term_color(s)
		if err == No_Error {
			return c
		}
	}

	color_fgbg := get_env(o.environ, "COLORFGBG")
	if strings.contains(color_fgbg, ";") {
		c := strings.split(color_fgbg, ";")
		i, err := strconv.atoi(c[0])
		if err == No_Error {
			return ANSI_Color(i)
		}
	}

	// default gray
	return ANSI_Color(7)
}

output_background_color :: proc(o: Output) -> Color {
	s, err := term_status_report(o, 11)
	if err == nil {
		c, err := xTermColor(s)
		if err == nil {
			return c
		}
	}

	color_fgbg := get_env(o.environ, "COLORFGBG")
	if strings.Contains(color_fgbg, ";") {
		c := strings.Split(color_fgbg, ";")
		i, err := strconv.atoi(c[len(c)-1])
		if err == nil {
			return ANSIColor(i)
		}
	}

	// default black
	return ANSIColor(0)
}

waitForData :: proc(o: ^Output, timeout: time.Duration) -> error {
	fd := o.TTY().Fd()
	tv := unix.NsecToTimeval(int64(timeout))
	var readfds unix.FdSet
	readfds.Set(int(fd))

	for {
		n, err := unix.Select(int(fd)+1, &readfds, nil, nil, &tv)
		if err == unix.EINTR {
			continue
		}
		if err != nil {
			return err
		}
		if n == 0 {
			return fmt.Errorf("timeout")
		}

		break
	}

	return nil
}

readNextByte :: proc(o: ^Output) -> (byte, error) {
	if !o.unsafe {
		if err := o.waitForData(OSC_TIMEOUT); err != nil {
			return 0, err
		}
	}

	var b [1]byte
	n, err := o.TTY().Read(b[:])
	if err != nil {
		return 0, err
	}

	if n == 0 {
		panic("read returned no data")
	}

	return b[0], nil
}

// readNextResponse reads either an OSC response or a cursor position response:
//   - OSC response: "\x1b]11;rgb:1111/1111/1111\x1b\\"
//   - cursor position response: "\x1b[42;1R"
readNextResponse :: proc(o: ^Output) -> (response string, isOSC bool, err error) {
	start, err := o.readNextByte()
	if err != nil {
		return "", false, err
	}

	// first byte must be ESC
	for start != ESC {
		start, err = o.readNextByte()
		if err != nil {
			return "", false, err
		}
	}

	response += string(start)

	// next byte is either '[' (cursor position response) or ']' (OSC response)
	tpe, err := o.readNextByte()
	if err != nil {
		return "", false, err
	}

	response += string(tpe)

	var oscResponse bool
	switch tpe {
	case '[':
		oscResponse = false
	case ']':
		oscResponse = true
	default:
		return "", false, Err_Status_Report
	}

	for {
		b, err := o.readNextByte()
		if err != nil {
			return "", false, err
		}

		response += string(b)

		if oscResponse {
			// OSC can be terminated by BEL (\a) or ST (ESC)
			if b == BEL || strings.HasSuffix(response, string(ESC)) {
				return response, true, nil
			}
		} else {
			// cursor position response is terminated by 'R'
			if b == 'R' {
				return response, false, nil
			}
		}

		// both responses have less than 25 bytes, so if we read more, that's an error
		if len(response) > 25 {
			break
		}
	}

	return "", false, Err_Status_Report
}

term_status_report :: proc(o: Output, sequence: int) -> (string, Error) {
	// screen/tmux can't support OSC, because they can be connected to multiple
	// terminals concurrently.
	term := get_env(o.environ, "TERM")
	if strings.has_prefix(term, "screen") || strings.has_prefix(term, "tmux") || strings.has_prefix(term, "dumb") {
		return "", Err_Status_Report
	}

	tty := o.TTY()
	if tty == nil {
		return "", Err_Status_Report
	}

	if !o.unsafe {
		fd := int(tty.Fd())
		// if in background, we can't control the terminal
		if !isForeground(fd) {
			return "", Err_Status_Report
		}

		t, err := unix.IoctlGetTermios(fd, tcgetattr)
		if err != nil {
			return "", fmt.Errorf("%s: %s", Err_Status_Report, err)
		}
		defer unix.IoctlSetTermios(fd, tcsetattr, t) //nolint:errcheck

		noecho := ^t
		noecho.Lflag = noecho.Lflag &^ unix.ECHO
		noecho.Lflag = noecho.Lflag &^ unix.ICANON
		if err := unix.IoctlSetTermios(fd, tcsetattr, &noecho); err != nil {
			return "", fmt.Errorf("%s: %s", Err_Status_Report, err)
		}
	}

	// first, send OSC query, which is ignored by terminal which do not support it
	fmt.Fprintf(tty, OSC+"%d;?"+ST, sequence)

	// then, query cursor position, should be supported by all terminals
	fmt.Fprintf(tty, CSI+"6n")

	// read the next response
	res, isOSC, err := o.readNextResponse()
	if err != nil {
		return "", fmt.Errorf("%s: %s", Err_Status_Report, err)
	}

	// if this is not OSC response, then the terminal does not support it
	if !isOSC {
		return "", Err_Status_Report
	}

	// read the cursor query response next and discard the result
	_, _, err = o.readNextResponse()
	if err != nil {
		return "", err
	}

	// fmt.Println("Rcvd", res[1:])
	return res, nil
}

// enable_virtual_terminal_processing enables virtual terminal processing on
// Windows for w and returns a function that restores w to its previous state.
// On non-Windows platforms, or if w does not refer to a terminal, then it
// returns a non-nil no-op function and no error.
enable_virtual_terminal_processing :: proc(_: io.Writer) -> (proc() -> Error, Error) {
	return proc() -> error { return No_Error }, No_Error
}

*/
}

