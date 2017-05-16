package main

import (
	"crypto/tls"
	"fmt"
	"log"
	"os"
	"regexp"
	"sort"
	"strconv"
	"time"

	"github.com/cloudfoundry/noaa/consumer"
)

var (
	loggregatorAddr = os.Getenv("LOGGREGATOR_ADDR")
	appGuid         = os.Getenv("APP_GUID")
	authToken       = os.Getenv("CF_ACCESS_TOKEN")
)

func main() {
	re := regexp.MustCompile("[0-9]+")

	consumer := consumer.New(loggregatorAddr, &tls.Config{InsecureSkipVerify: true}, nil)
	consumer.SetDebugPrinter(ConsoleDebugPrinter{})

	start := time.Now()
	messages, err := consumer.RecentLogs(appGuid, authToken)
	fmt.Printf("Latency: %d\n", time.Since(start))

	if err != nil {
		log.Printf("Error getting recent messages: %v", err)
		return
	}

	var results []int
	for _, msg := range messages {
		matches := re.FindSubmatch(msg.GetMessage())
		if len(matches) != 1 {
			continue
		}

		i, _ := strconv.Atoi(string(matches[0]))
		results = append(results, i)
	}
	sort.Sort(sort.IntSlice(results))
	fmt.Printf("Holes: %d\n", findHoles(results))
	fmt.Printf("Total: %d\n", len(results))
}

func findHoles(results []int) int {
	if len(results) == 0 {
		return 0
	}

	holes := 0
	expected := results[0] + 1

	for _, r := range results[1:] {
		if expected != r {
			holes++
		}
		expected = r + 1
	}

	return holes
}

type ConsoleDebugPrinter struct{}

func (c ConsoleDebugPrinter) Print(title, dump string) {
	log.Println(title)
	log.Println(dump)
}
