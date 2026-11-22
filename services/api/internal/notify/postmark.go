package notify

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// PostmarkURL is Postmark's send endpoint.
const PostmarkURL = "https://api.postmarkapp.com/email"

// PostmarkMailer sends through Postmark's HTTPS API, the transactional
// provider behind notify.Mailer outside local development (ADR 014).
type PostmarkMailer struct {
	token  string
	from   Address
	url    string
	client *http.Client
}

// NewPostmarkMailer returns a mailer using the server token. url overrides
// PostmarkURL in tests.
func NewPostmarkMailer(token string, from Address, url string) *PostmarkMailer {
	if url == "" {
		url = PostmarkURL
	}
	return &PostmarkMailer{token: token, from: from, url: url, client: &http.Client{Timeout: 15 * time.Second}}
}

// Name is "postmark".
func (m *PostmarkMailer) Name() string { return "postmark" }

type postmarkHeader struct {
	Name  string `json:"Name"`
	Value string `json:"Value"`
}

type postmarkMessage struct {
	From          string           `json:"From"`
	To            string           `json:"To"`
	Subject       string           `json:"Subject"`
	TextBody      string           `json:"TextBody"`
	HTMLBody      string           `json:"HtmlBody"`
	Tag           string           `json:"Tag"`
	MessageStream string           `json:"MessageStream"`
	Headers       []postmarkHeader `json:"Headers,omitempty"`
	Attachments   []postmarkFile   `json:"Attachments,omitempty"`
}

type postmarkFile struct {
	Name        string `json:"Name"`
	Content     string `json:"Content"`
	ContentType string `json:"ContentType"`
}

type postmarkResult struct {
	MessageID string `json:"MessageID"`
	ErrorCode int    `json:"ErrorCode"`
	Message   string `json:"Message"`
}

// Send delivers msg.
func (m *PostmarkMailer) Send(ctx context.Context, msg Message) (string, error) {
	pm := postmarkMessage{
		From: formatAddress(m.from), To: formatAddress(msg.To), Subject: msg.Subject,
		TextBody: msg.Text, HTMLBody: msg.HTML, Tag: string(msg.Category), MessageStream: "outbound",
	}
	if msg.Unsubscribe != "" {
		pm.Headers = []postmarkHeader{
			{Name: "List-Unsubscribe", Value: "<" + msg.Unsubscribe + ">"},
			{Name: "List-Unsubscribe-Post", Value: "List-Unsubscribe=One-Click"},
		}
	}
	for _, a := range msg.Attachments {
		pm.Attachments = append(pm.Attachments, postmarkFile{Name: a.Filename, Content: base64.StdEncoding.EncodeToString(a.Content), ContentType: a.ContentType})
	}
	body, err := json.Marshal(pm)
	if err != nil {
		return "", fmt.Errorf("encode message: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, m.url, bytes.NewReader(body))
	if err != nil {
		return "", fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Postmark-Server-Token", m.token)
	resp, err := m.client.Do(req)
	if err != nil {
		return "", fmt.Errorf("postmark send: %w", err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<16))
	var result postmarkResult
	if err := json.Unmarshal(raw, &result); err != nil {
		return "", fmt.Errorf("postmark send: status %d", resp.StatusCode)
	}
	if resp.StatusCode != http.StatusOK || result.ErrorCode != 0 {
		return "", fmt.Errorf("postmark send: status %d, error %d: %s", resp.StatusCode, result.ErrorCode, result.Message)
	}
	return result.MessageID, nil
}
