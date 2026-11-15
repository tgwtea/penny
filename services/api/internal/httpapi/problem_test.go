package httpapi

import (
	"errors"
	"fmt"
	"net/http"
	"testing"

	"github.com/tgwtea/penny/services/api/internal/apperr"
)

func TestKindForMapsEveryServiceError(t *testing.T) {
	tests := []struct {
		err        error
		wantStatus int
		wantKnown  bool
	}{
		{apperr.ErrValidation, http.StatusBadRequest, true},
		{apperr.ErrUnauthenticated, http.StatusUnauthorized, true},
		{apperr.ErrForbidden, http.StatusForbidden, true},
		{apperr.ErrNotFound, http.StatusNotFound, true},
		{apperr.ErrConflict, http.StatusConflict, true},
		{apperr.ErrPreconditionFailed, http.StatusPreconditionFailed, true},
		{apperr.New(apperr.ErrNotFound, "No such lesson."), http.StatusNotFound, true},
		{fmt.Errorf("load lesson: %w", apperr.ErrForbidden), http.StatusForbidden, true},
		{errors.New("connection reset"), http.StatusInternalServerError, false},
	}
	for _, tt := range tests {
		t.Run(tt.err.Error(), func(t *testing.T) {
			kind, known := kindFor(tt.err)
			if kind.Status != tt.wantStatus || known != tt.wantKnown {
				t.Errorf("kindFor(%v) = %d, %v; want %d, %v", tt.err, kind.Status, known, tt.wantStatus, tt.wantKnown)
			}
		})
	}
}
