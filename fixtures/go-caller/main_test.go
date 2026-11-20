package main

import "testing"

func TestGreeting(t *testing.T) {
	const want = "hello from the Go caller: 00000000-0000-0000-0000-000000000001"
	if got := greeting(); got != want {
		t.Fatalf("greeting() = %q, want %q", got, want)
	}
}
