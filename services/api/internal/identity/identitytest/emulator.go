package identitytest

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"testing"
	"time"
)

// EmulatorProject is the demo project the local Firebase Auth emulator runs
// (tools/firebase-emulator).
const EmulatorProject = "demo-penny"

// Emulator drives the Firebase Auth emulator's REST API, to get real
// emulator ID tokens in end-to-end tests.
type Emulator struct {
	host   string
	client *http.Client
}

// NewEmulator returns a client for the emulator named by
// PENNY_TEST_FIREBASE_AUTH_EMULATOR_HOST (such as localhost:9099), skipping
// the test when it is not set.
func NewEmulator(t testing.TB) *Emulator {
	t.Helper()
	host := os.Getenv("PENNY_TEST_FIREBASE_AUTH_EMULATOR_HOST")
	if host == "" {
		t.Skip("set PENNY_TEST_FIREBASE_AUTH_EMULATOR_HOST to run tests against the Firebase Auth emulator")
	}
	return &Emulator{host: host, client: &http.Client{Timeout: 10 * time.Second}}
}

// Host is the emulator's host:port.
func (e *Emulator) Host() string { return e.host }

// Account is a person created in the emulator.
type Account struct {
	UID      string
	Email    string
	Password string
	IDToken  string
}

// SignUp creates an account with a unique email and returns it, signed in.
// Its email is not verified.
func (e *Emulator) SignUp(ctx context.Context, name string) (Account, error) {
	suffix := make([]byte, 4)
	if _, err := rand.Read(suffix); err != nil {
		return Account{}, err
	}
	a := Account{Email: fmt.Sprintf("%s-%s@example.com", name, hex.EncodeToString(suffix)), Password: "correct horse battery"}
	var out struct {
		IDToken string `json:"idToken"`
		LocalID string `json:"localId"`
	}
	err := e.post(ctx, "/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-api-key", "", map[string]any{
		"email": a.Email, "password": a.Password, "displayName": name, "returnSecureToken": true,
	}, &out)
	a.UID, a.IDToken = out.LocalID, out.IDToken
	return a, err
}

// VerifyEmail marks the account's email verified, as clicking the link in
// the verification email would, and signs in again so IDToken says so.
func (e *Emulator) VerifyEmail(ctx context.Context, a *Account) error {
	err := e.post(ctx, "/identitytoolkit.googleapis.com/v1/projects/"+EmulatorProject+"/accounts:update", "owner",
		map[string]any{"localId": a.UID, "emailVerified": true}, nil)
	if err != nil {
		return err
	}
	var out struct {
		IDToken string `json:"idToken"`
	}
	err = e.post(ctx, "/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-api-key", "",
		map[string]any{"email": a.Email, "password": a.Password, "returnSecureToken": true}, &out)
	a.IDToken = out.IDToken
	return err
}

// post sends a JSON request; bearer "owner" is the emulator's admin token.
func (e *Emulator) post(ctx context.Context, path, bearer string, body, out any) error {
	b, err := json.Marshal(body)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "http://"+e.host+path, bytes.NewReader(b))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	if bearer != "" {
		req.Header.Set("Authorization", "Bearer "+bearer)
	}
	resp, err := e.client.Do(req)
	if err != nil {
		return fmt.Errorf("auth emulator %s: %w", path, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		var problem bytes.Buffer
		_, _ = problem.ReadFrom(resp.Body)
		return fmt.Errorf("auth emulator %s: %d %s", path, resp.StatusCode, problem.String())
	}
	if out == nil {
		return nil
	}
	return json.NewDecoder(resp.Body).Decode(out)
}
