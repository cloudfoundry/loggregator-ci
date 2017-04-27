package main_test

import (
	"testing"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

func TestHTTPSDrain(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "HTTPS Drain Suite")
}
