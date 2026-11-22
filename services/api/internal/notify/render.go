package notify

import (
	"bytes"
	"embed"
	"fmt"
	htmltemplate "html/template"
	"strings"
	texttemplate "text/template"
)

//go:embed templates/*.tmpl
var templateFiles embed.FS

// Rendered is an email's subject and two bodies.
type Rendered struct {
	Subject string
	Text    string
	HTML    string
}

// render fills in the named email ("lesson_reminder") from data, in plain
// text and HTML. The HTML is escaped by html/template; the text is not
// HTML, so text/template is right there.
func render(name string, data any) (Rendered, error) {
	txt, err := texttemplate.ParseFS(templateFiles, "templates/"+name+".txt.tmpl")
	if err != nil {
		return Rendered{}, fmt.Errorf("parse %s text: %w", name, err)
	}
	html, err := htmltemplate.ParseFS(templateFiles, "templates/layout.html.tmpl", "templates/"+name+".html.tmpl")
	if err != nil {
		return Rendered{}, fmt.Errorf("parse %s html: %w", name, err)
	}
	var subject, text, body bytes.Buffer
	if err := txt.ExecuteTemplate(&subject, "subject", data); err != nil {
		return Rendered{}, fmt.Errorf("render %s subject: %w", name, err)
	}
	if err := txt.ExecuteTemplate(&text, "text", data); err != nil {
		return Rendered{}, fmt.Errorf("render %s text: %w", name, err)
	}
	if err := html.ExecuteTemplate(&body, "layout", data); err != nil {
		return Rendered{}, fmt.Errorf("render %s html: %w", name, err)
	}
	return Rendered{
		Subject: strings.TrimSpace(subject.String()),
		Text:    strings.TrimLeft(text.String(), "\n"),
		HTML:    body.String(),
	}, nil
}

// LessonReminder is what a lesson reminder says.
type LessonReminder struct {
	ContactName      string
	StudentFirstName string
	TeamName         string
	Tutors           string // "Mei Lin Tan" or "Mei Lin Tan and Aisha Rahman"
	Day              string // "tomorrow", "today" or "on Saturday"
	Date             string // "Thursday 20 November"
	StartTime        string // "16:00"
	EndTime          string
	Place            string
	Address          string
	MeetingURL       string
	Policy           string
	UnsubscribeURL   string
	UnsubscribeText  string
}

// Invitation is what a team invitation says.
type Invitation struct {
	InviteeName     string
	InviterName     string
	TeamName        string
	Role            string
	Email           string
	SignInURL       string
	UnsubscribeURL  string
	UnsubscribeText string
}
