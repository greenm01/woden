package karvi_test

import "core:testing"
import "core:os"
import "core:fmt"
import "core:strings"

import kv "../"

/*
import (
	"bytes"
	"fmt"
	"image/color"
	"io"
	"os"
	"strings"
	"testing"
	"text/template"
)
*/

expect  :: testing.expect
log     :: testing.log
errorf  :: testing.errorf

@(test)
test_term_env :: proc(t: ^testing.T) {
	using kv.Profile

	kv.init()
	defer kv.close()

	o := kv.new_output(os.stdout)
	test := o.profile == ANSI256
	err := fmt.tprintf("Expected %d got %d", ANSI256, o.profile)
	expect(t, test, err)
	    
	fg := kv.output_fg_color(o)
	fgseq := kv.sequence(fg, false)
	fgexp := "37"
	test = fgseq == fgexp && fgseq != ""
	err = fmt.tprintf("Expected %s got %s", fgexp, fgseq)
	expect(t, test, err)

	bg := kv.output_bg_color(o)
	bgseq := kv.sequence(bg, true)
	bgexp := "48;2;0;0;0"
	test = bgseq == bgexp && bgseq != ""
	err = fmt.tprintf("Expected %s got %s", bgexp, bgseq)
	expect(t, test, err)

	_ = kv.has_dark_background()
}

@(test)
test_rende_ring :: proc(t: ^testing.T) {
	using kv.Profile
	out := kv.new_style("foobar", True_Color)
	test := kv.get_string(out) == "foobar" 
	expect(t, test, "Unstyled strings should be returned as plain text")

	kv.set_style_foreground(out, kv.new_rgb_color("#abcdef"))
	kv.set_style_background(out, kv.new_ansi256_color(69))
	kv.enable_bold(out)
	kv.enable_italic(out)
	kv.enable_faint(out)
	kv.enable_underline(out)
	kv.enable_blink(out)

	exp := "\x1b[38;2;171;205;239;48;5;69;1;3;2;4;5mfoobar\x1b[0m"
	test = kv.get_string(out) == exp 
	err := fmt.tprintf("Expected %s, got %s", exp, kv.get_string(out))
	expect(t, test, err)

	exp = "foobar"
	mono := kv.new_style(exp, Ascii)
	kv.set_style_foreground(mono, kv.new_rgb_color("#abcdef"))
	test = kv.get_string(mono) == exp
	err = fmt.tprintf("Ascii profile should not apply color styles")
	expect(t, test, err)
}

@(test)
test_color_conversion :: proc(t: ^testing.T) {
	// ANSI color
	a := kv.new_ansi_color(7)
	c := kv.convert_to_hex(a)

	exp := "#c0c0c0"
	test := kv.hex(c) == exp 
	err := fmt.tprintf("Expected %s, got %s", exp, kv.hex(c))
	expect(t, test, err)

	// ANSI-256 color
	a256 := kv.new_ansi256_color(91)
	c = kv.convert_to_hex(a256)

	exp = "#8700af"
	test = kv.hex(c) == exp 
	err = fmt.tprintf("Expected %s, got %s", exp, kv.hex(c))
	expect(t, test, err)

	// hex color
	hex := "#87ff00"
	argb := kv.new_hex_color(hex)
	clr := kv.hex_to_ansi256(argb)
	test = clr.color == hex
	err = fmt.tprintf("Expected %s, got %s", hex, clr.color)
	expect(t, test, err)
}

/*
func TestFromColor(t *testing.T) {
	// color.Color interface
	c := TrueColor.FromColor(color.RGBA{255, 128, 0, 255})
	exp := "38;2;255;128;0"
	if c.Sequence(false) != exp {
		t.Errorf("Expected %s, got %s", exp, c.Sequence(false))
	}
}

func TestAscii(t *testing.T) {
	c := Ascii.Color("#abcdef")
	if c.Sequence(false) != "" {
		t.Errorf("Expected empty sequence, got %s", c.Sequence(false))
	}
}

func TestANSIProfile(t *testing.T) {
	p := ANSI

	c := p.Color("#e88388")
	exp := "91"
	if c.Sequence(false) != exp {
		t.Errorf("Expected %s, got %s", exp, c.Sequence(false))
	}
	if _, ok := c.(ANSIColor); !ok {
		t.Errorf("Expected type termenv.ANSIColor, got %T", c)
	}

	c = p.Color("82")
	exp = "92"
	if c.Sequence(false) != exp {
		t.Errorf("Expected %s, got %s", exp, c.Sequence(false))
	}
	if _, ok := c.(ANSIColor); !ok {
		t.Errorf("Expected type termenv.ANSIColor, got %T", c)
	}

	c = p.Color("2")
	exp = "32"
	if c.Sequence(false) != exp {
		t.Errorf("Expected %s, got %s", exp, c.Sequence(false))
	}
	if _, ok := c.(ANSIColor); !ok {
		t.Errorf("Expected type termenv.ANSIColor, got %T", c)
	}
}

func TestANSI256Profile(t *testing.T) {
	p := ANSI256

	c := p.Color("#abcdef")
	exp := "38;5;153"
	if c.Sequence(false) != exp {
		t.Errorf("Expected %s, got %s", exp, c.Sequence(false))
	}
	if _, ok := c.(ANSI256Color); !ok {
		t.Errorf("Expected type termenv.ANSI256Color, got %T", c)
	}

	c = p.Color("139")
	exp = "38;5;139"
	if c.Sequence(false) != exp {
		t.Errorf("Expected %s, got %s", exp, c.Sequence(false))
	}
	if _, ok := c.(ANSI256Color); !ok {
		t.Errorf("Expected type termenv.ANSI256Color, got %T", c)
	}

	c = p.Color("2")
	exp = "32"
	if c.Sequence(false) != exp {
		t.Errorf("Expected %s, got %s", exp, c.Sequence(false))
	}
	if _, ok := c.(ANSIColor); !ok {
		t.Errorf("Expected type termenv.ANSIColor, got %T", c)
	}
}

func TestTrueColorProfile(t *testing.T) {
	p := TrueColor

	c := p.Color("#abcdef")
	exp := "38;2;171;205;239"
	if c.Sequence(false) != exp {
		t.Errorf("Expected %s, got %s", exp, c.Sequence(false))
	}
	if _, ok := c.(RGBColor); !ok {
		t.Errorf("Expected type termenv.HexColor, got %T", c)
	}

	c = p.Color("139")
	exp = "38;5;139"
	if c.Sequence(false) != exp {
		t.Errorf("Expected %s, got %s", exp, c.Sequence(false))
	}
	if _, ok := c.(ANSI256Color); !ok {
		t.Errorf("Expected type termenv.ANSI256Color, got %T", c)
	}

	c = p.Color("2")
	exp = "32"
	if c.Sequence(false) != exp {
		t.Errorf("Expected %s, got %s", exp, c.Sequence(false))
	}
	if _, ok := c.(ANSIColor); !ok {
		t.Errorf("Expected type termenv.ANSIColor, got %T", c)
	}
}

func TestStyles(t *testing.T) {
	s := String("foobar").Foreground(TrueColor.Color("2"))

	exp := "\x1b[32mfoobar\x1b[0m"
	if s.String() != exp {
		t.Errorf("Expected %s, got %s", exp, s.String())
	}
}

func TestTemplateHelpers(t *testing.T) {
	p := TrueColor

	exp := String("Hello World")
	basetpl := `{{ %s "Hello World" }}`
	wraptpl := `{{ %s (%s "Hello World") }}`

	tt := []struct {
		Template string
		Expected string
	}{
		{
			Template: fmt.Sprintf(basetpl, "Bold"),
			Expected: exp.Bold().String(),
		},
		{
			Template: fmt.Sprintf(basetpl, "Faint"),
			Expected: exp.Faint().String(),
		},
		{
			Template: fmt.Sprintf(basetpl, "Italic"),
			Expected: exp.Italic().String(),
		},
		{
			Template: fmt.Sprintf(basetpl, "Underline"),
			Expected: exp.Underline().String(),
		},
		{
			Template: fmt.Sprintf(basetpl, "Overline"),
			Expected: exp.Overline().String(),
		},
		{
			Template: fmt.Sprintf(basetpl, "Blink"),
			Expected: exp.Blink().String(),
		},
		{
			Template: fmt.Sprintf(basetpl, "Reverse"),
			Expected: exp.Reverse().String(),
		},
		{
			Template: fmt.Sprintf(basetpl, "CrossOut"),
			Expected: exp.CrossOut().String(),
		},
		{
			Template: fmt.Sprintf(wraptpl, "Underline", "Bold"),
			Expected: String(exp.Bold().String()).Underline().String(),
		},
		{
			Template: `{{ Color "#ff0000" "foobar" }}`,
			Expected: String("foobar").Foreground(p.Color("#ff0000")).String(),
		},
		{
			Template: `{{ Color "#ff0000" "#0000ff" "foobar" }}`,
			Expected: String("foobar").
				Foreground(p.Color("#ff0000")).
				Background(p.Color("#0000ff")).
				String(),
		},
		{
			Template: `{{ Foreground "#ff0000" "foobar" }}`,
			Expected: String("foobar").Foreground(p.Color("#ff0000")).String(),
		},
		{
			Template: `{{ Background "#ff0000" "foobar" }}`,
			Expected: String("foobar").Background(p.Color("#ff0000")).String(),
		},
	}

	for i, v := range tt {
		tpl, err := template.New(fmt.Sprintf("test_%d", i)).Funcs(TemplateFuncs(p)).Parse(v.Template)
		if err != nil {
			t.Error(err)
		}

		var buf bytes.Buffer
		err = tpl.Execute(&buf, nil)
		if err != nil {
			t.Error(err)
		}

		if buf.String() != v.Expected {
			v1 := strings.ReplaceAll(v.Expected, "\x1b", "")
			v2 := strings.ReplaceAll(buf.String(), "\x1b", "")
			t.Errorf("Expected %s, got %s", v1, v2)
		}
	}
}

func TestEnvNoColor(t *testing.T) {
	tests := []struct {
		name     string
		environ  []string
		expected bool
	}{
		{"no env", nil, false},
		{"no_color", []string{"NO_COLOR", "Y"}, true},
		{"no_color+clicolor=1", []string{"NO_COLOR", "Y", "CLICOLOR", "1"}, true},
		{"no_color+clicolor_force=1", []string{"NO_COLOR", "Y", "CLICOLOR_FORCE", "1"}, true},
		{"clicolor=0", []string{"CLICOLOR", "0"}, true},
		{"clicolor=1", []string{"CLICOLOR", "1"}, false},
		{"clicolor_force=1", []string{"CLICOLOR_FORCE", "0"}, false},
		{"clicolor_force=0", []string{"CLICOLOR_FORCE", "1"}, false},
		{"clicolor=0+clicolor_force=1", []string{"CLICOLOR", "0", "CLICOLOR_FORCE", "1"}, false},
		{"clicolor=1+clicolor_force=1", []string{"CLICOLOR", "1", "CLICOLOR_FORCE", "1"}, false},
		{"clicolor=0+clicolor_force=0", []string{"CLICOLOR", "0", "CLICOLOR_FORCE", "0"}, true},
		{"clicolor=1+clicolor_force=0", []string{"CLICOLOR", "1", "CLICOLOR_FORCE", "0"}, false},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			defer func() {
				os.Unsetenv("NO_COLOR")
				os.Unsetenv("CLICOLOR")
				os.Unsetenv("CLICOLOR_FORCE")
			}()
			for i := 0; i < len(test.environ); i += 2 {
				os.Setenv(test.environ[i], test.environ[i+1])
			}
			out := NewOutput(os.Stdout)
			actual := out.EnvNoColor()
			if test.expected != actual {
				t.Errorf("expected %t but was %t", test.expected, actual)
			}
		})
	}
}

func TestPseudoTerm(t *testing.T) {
	buf := &bytes.Buffer{}
	o := NewOutput(buf)
	if o.Profile != Ascii {
		t.Errorf("Expected %d, got %d", Ascii, o.Profile)
	}

	fg := o.ForegroundColor()
	fgseq := fg.Sequence(false)
	if fgseq != "" {
		t.Errorf("Expected empty response, got %s", fgseq)
	}

	bg := o.BackgroundColor()
	bgseq := bg.Sequence(true)
	if bgseq != "" {
		t.Errorf("Expected empty response, got %s", bgseq)
	}

	exp := "foobar"
	out := o.String(exp)
	out = out.Foreground(o.Color("#abcdef"))
	o.Write([]byte(out.String()))

	if buf.String() != exp {
		t.Errorf("Expected %s, got %s", exp, buf.String())
	}
}

func TestCache(t *testing.T) {
	o := NewOutput(os.Stdout, WithColorCache(true), WithProfile(TrueColor))

	if o.cache != true {
		t.Errorf("Expected cache to be active, got %t", o.cache)
	}
}

func TestEnableVirtualTerminalProcessing(t *testing.T) {
	// EnableVirtualTerminalProcessing should always return a non-nil
	// restoreFunc, and in tests it should never return an error.
	restoreFunc, err := EnableVirtualTerminalProcessing(NewOutput(os.Stdout))
	if restoreFunc == nil || err != nil {
		t.Fatalf("expected non-<nil>, <nil>, got %p, %v", restoreFunc, err)
	}
	// In tests, restoreFunc should never return an error.
	if err := restoreFunc(); err != nil {
		t.Fatalf("expected <nil>, got %v", err)
	}
}

func TestWithTTY(t *testing.T) {
	for _, v := range []bool{true, false} {
		o := NewOutput(io.Discard, WithTTY(v))
		if o.isTTY() != v {
			t.Fatalf("expected WithTTY(%t) to set isTTY to %t", v, v)
		}
	}
}
*/
