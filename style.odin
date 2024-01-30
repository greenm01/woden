package karvi

import "core:fmt"
import "core:strings"

import wc "deps/wcwidth"

// Sequence definitions.
RESET_SEQ     :: "0"
BOLD_SEQ      :: "1"
FAINT_SEQ     :: "2"
ITALIC_SEQ    :: "3"
UNDERLINE_SEQ :: "4"
BLINK_SEQ     :: "5"
REVERSE_SEQ   :: "7"
CROSOUT_SEQ   :: "9"
OVERLINE_SEQ  :: "53"


// Style is a string that various rendering styles can be applied to.
Style :: struct {
	profile: Profile,
	str    : string
	styles : [dynamic]string,
}

// new_style returns a new Style.
new_style :: proc(s ..string) -> (style: ^Style) {
	using Profile
	style = new(Style)
	style.profile = ANSI,
	sryle.str = strings.join(s, " "),
	style.styles = make([dynamic]string)
	return
}

del_style :: proc(s: ^Style) {
	delete(s.styles)
}

string_style :: proc(t: Style) -> string {
	return styled(t, t.str)
}

// styled renders s with all applied styles.
styled :: proc(t: Style, s: string) -> string {
	using Color_Profile
	if t.profile == Ascii {
		return s
	}
	if len(t.styles) == 0 {
		return s
	}

	seq := strings.join(t.styles, ";")
	if seq == "" {
		return s
	}

	return fmt.tprintf("%s%sm%s%sm", CSI, seq, s, CSI+RESET_SEQ)
}

// foreground sets a foreground color.
foreground :: proc(t: ^Style, c: ^Color) {
	append(t.styles, sequence(c, false))
}

// background sets a background color.
background :: proc(t: ^Style, c: ^Color) {
	append(t.styles, sequence(c, true))
}

// bold enables bold rendering.
bold :: proc(t: ^Style) {
	append(t.styles, BOLD_SEQ)
}

// faint enables faint rendering.
faint :: proc(t: ^Style) {
	append(t.styles, FAINT_SEQ)
}

// italic enables italic rendering.
italic :: proc(t: ^Style) {
	append(t.styles, ITALIC_SEQ)
}

// underline enables underline rendering.
underline :: proc(t: ^Style) {
	append(t.styles, UNDERLINE_SEQ)
}

// overline enables overline rendering.
overline :: proc(t: ^Style) {
	append(t.styles, OVERLINE_SEQ)
}

// blink enables blink mode.
blink :: proc(t: ^Style) {
	append(t.styles, BLINK_SEQ)
}

// reverse enables reverse color mode.
reverse :: proc(t: ^Style) {
	append(t.styles, REVERSE_SEQ)
}

// cross_out enables crossed-out rendering.
cross_out :: proc(t: ^Style) {
	append(t.styles, CROSSOUT_SEQ)
}

// width returns the width required to print all runes in Style.
width :: proc(t: ^Style) -> int {
	return wc.string_width(t.str)
}