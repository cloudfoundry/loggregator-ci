package main_test

import (
	"testing"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

func TestSyslogDrain(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "SyslogDrain Suite")
}
