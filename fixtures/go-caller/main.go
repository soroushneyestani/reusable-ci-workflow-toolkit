package main

import (
	"fmt"

	"github.com/google/uuid"
)

func greeting() string {
	id := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	return "hello from the Go caller: " + id.String()
}

func main() {
	fmt.Println(greeting())
}
