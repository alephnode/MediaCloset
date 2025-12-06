//go:build tools
// +build tools

package tools

// This file declares tool dependencies to ensure they are tracked in go.mod/go.sum.
// It is not compiled into the binary.

import (
	_ "github.com/99designs/gqlgen"
)
