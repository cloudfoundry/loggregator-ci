package main

import (
	"flag"
	"fmt"
	"time"
)

var logMessage string

func main() {
	logsPerSecond := flag.Uint("logs-per-second", 1000, "Log messages to emit per second. Default: 1000")
	logSize := flag.Uint("log-bytes", 1000, "Length of log messages in bytes. Default: 1000")
	flag.Parse()

	for i := uint(0); i < *logSize; i++ {
		logMessage += "!"
	}

	interval := time.Second / time.Duration(*logsPerSecond)
	for {
		startTime := time.Now()
		emitLog()
		timeToSleep := interval - time.Since(startTime)
		time.Sleep(timeToSleep)
	}
}

func emitLog() {
	fmt.Printf("%s\n", logMessage)
}
