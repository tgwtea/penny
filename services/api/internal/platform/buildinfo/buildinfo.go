// Package buildinfo reports which build of Penny is running.
package buildinfo

import "runtime/debug"

// Set at build time with -ldflags, as the Dockerfile does:
//
//	-X github.com/tgwtea/penny/services/api/internal/platform/buildinfo.version=0.1.0
//	-X github.com/tgwtea/penny/services/api/internal/platform/buildinfo.commit=3f2c1a9
var (
	version = ""
	commit  = ""
)

// Info identifies a build.
type Info struct {
	Version string // release version, or "dev"
	Commit  string // git commit, or "unknown"
}

// Read returns the running build's identity. Without ldflags it falls back
// to the commit Go embeds when building inside a git checkout.
func Read() Info {
	info := Info{Version: version, Commit: commit}
	if info.Version == "" {
		info.Version = "dev"
	}
	if info.Commit == "" {
		info.Commit = vcsRevision()
	}
	return info
}

func vcsRevision() string {
	bi, ok := debug.ReadBuildInfo()
	if !ok {
		return "unknown"
	}
	for _, s := range bi.Settings {
		if s.Key == "vcs.revision" && s.Value != "" {
			if len(s.Value) > 12 {
				return s.Value[:12]
			}
			return s.Value
		}
	}
	return "unknown"
}
