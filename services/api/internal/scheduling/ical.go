package scheduling

import (
	"fmt"
	"strings"
	"time"
	"unicode/utf8"
)

// calendarOf renders lessons as an RFC 5545 calendar for subscribing from
// Google or Apple Calendar. Events carry students' first names and the
// place, never notes, contacts or full names: the feed leaves Penny.
func calendarOf(name, timezone string, lessons []Lesson, now time.Time) []byte {
	var b strings.Builder
	line := func(s string) { b.WriteString(fold(s)) }
	line("BEGIN:VCALENDAR")
	line("VERSION:2.0")
	line("PRODID:-//Penny//Lessons//EN")
	line("CALSCALE:GREGORIAN")
	line("METHOD:PUBLISH")
	line("X-WR-CALNAME:" + escapeText("Penny: "+name))
	line("X-WR-TIMEZONE:" + escapeText(timezone))
	stamp := now.UTC().Format(icalTime)
	for _, l := range lessons {
		line("BEGIN:VEVENT")
		line("UID:" + l.ID.String() + "@penny")
		line("DTSTAMP:" + stamp)
		line("DTSTART:" + l.StartsAt.UTC().Format(icalTime))
		line("DTEND:" + l.EndsAt.UTC().Format(icalTime))
		line("SEQUENCE:" + fmt.Sprint(l.Version))
		line("SUMMARY:" + escapeText(eventSummary(l)))
		if l.Location != nil {
			where := l.Location.Name
			if l.Location.Address != "" {
				where += ", " + l.Location.Address
			}
			line("LOCATION:" + escapeText(where))
			if l.Location.MeetingURL != "" {
				line("URL:" + l.Location.MeetingURL)
			}
		}
		if l.Status == StatusCancelled {
			line("STATUS:CANCELLED")
		} else {
			line("STATUS:CONFIRMED")
		}
		line("END:VEVENT")
	}
	line("END:VCALENDAR")
	return []byte(b.String())
}

const icalTime = "20060102T150405Z"

// eventSummary is "Guitar, Grade 5: Arjun, Sofia", or "Lesson: ..." without
// a title. Only first names leave Penny.
func eventSummary(l Lesson) string {
	title := l.Title
	if title == "" {
		title = "Lesson"
	}
	if l.Status == StatusCancelled {
		title = "Cancelled: " + title
	}
	names := make([]string, 0, len(l.Students))
	for _, s := range l.Students {
		first, _, _ := strings.Cut(strings.TrimSpace(s.Name), " ")
		names = append(names, first)
	}
	if len(names) == 0 {
		return title
	}
	return title + ": " + strings.Join(names, ", ")
}

// escapeText escapes a TEXT value (RFC 5545, 3.3.11).
func escapeText(s string) string {
	return strings.NewReplacer(`\`, `\\`, ";", `\;`, ",", `\,`, "\r\n", `\n`, "\n", `\n`, "\r", `\n`).Replace(s)
}

// fold breaks a content line into 75-octet pieces with CRLF and a leading
// space (RFC 5545, 3.1), never inside a UTF-8 character.
func fold(s string) string {
	const limit = 75
	var b strings.Builder
	width := limit
	for len(s) > width {
		cut := width
		for cut > 0 && !utf8.RuneStart(s[cut]) {
			cut--
		}
		b.WriteString(s[:cut])
		b.WriteString("\r\n ")
		s = s[cut:]
		width = limit - 1
	}
	b.WriteString(s)
	b.WriteString("\r\n")
	return b.String()
}
