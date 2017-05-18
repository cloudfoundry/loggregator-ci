package main

import (
	"crypto/tls"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/cloudfoundry/noaa/consumer"
)

var (
	loggregatorAddr = os.Getenv("LOGGREGATOR_ADDR")
	appGuid         = os.Getenv("APP_GUID")
	authToken       = os.Getenv("CF_ACCESS_TOKEN")
)

func main() {
	validateSettings()

	consumer := consumer.New(loggregatorAddr, &tls.Config{InsecureSkipVerify: true}, nil)
	consumer.SetDebugPrinter(ConsoleDebugPrinter{})

	start := time.Now()
	_, err := consumer.ContainerMetrics(appGuid, authToken)
	if err != nil {
		log.Fatalf("Error getting container metrics: %v", err)
	}
	fmt.Printf("Latency: %d\n", time.Since(start))
}

func validateSettings() {
	if loggregatorAddr == "" {
		log.Fatal("LOGGREGATOR_ADDR is not set")
	}
	if appGuid == "" {
		log.Fatal("APP_GUID is not set")
	}
	if authToken == "" {
		log.Fatal("CF_ACCESS_TOKEN is not set")
	}
}

type ConsoleDebugPrinter struct{}

func (c ConsoleDebugPrinter) Print(title, dump string) {
	log.Println(title)
	log.Println(dump)
}
