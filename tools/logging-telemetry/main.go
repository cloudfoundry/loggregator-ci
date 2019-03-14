package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	envstruct "code.cloudfoundry.org/go-envstruct"
	datadog "github.com/zorkian/go-datadog-api"
)

var (
	logger *log.Logger = log.New(os.Stderr, "", log.LstdFlags)
)

func main() {
	cfg := LoadConfig()
	sen := "Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, ea	que ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo."

	logMarker := fmt.Sprintf("[test-message]: %s", sen)
	if !cfg.Producer {
		client := datadog.NewClient(cfg.DataDogAPIKey, "")

		logger.Fatal(http.ListenAndServe(
			fmt.Sprintf(":%d", cfg.Port),
			measure(cfg, client, logMarker),
		))
	}

	writeLogs(cfg, logMarker)
	for range time.Tick(cfg.TestFrequency) {
		writeLogs(cfg, logMarker)
	}
}

func measure(cfg Config, datadogClient *datadog.Client, logMarker string) http.Handler {
	drainCounts := make([]int, 5)
	firstMessageTimes := make([]time.Time, 5)
	var mu sync.Mutex

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		drainIndex, err := strconv.Atoi(r.URL.Query().Get("drain_num"))
		if err != nil {
			drainIndex = 1
		}
		drainIndex -= 1

		body, err := ioutil.ReadAll(r.Body)
		defer r.Body.Close()

		if err != nil {
			logger.Printf("failed to read request body")

			w.WriteHeader(http.StatusBadRequest)
			return
		}

		if !bytes.Contains(body, []byte(logMarker)) {
			return
		}

		mu.Lock()
		drainCounts[drainIndex]++
		if firstMessageTimes[drainIndex].IsZero() {
			firstMessageTimes[drainIndex] = time.Now()
		}

		since := time.Since(firstMessageTimes[drainIndex])
		if since < cfg.TestDuration+cfg.TestLatency+(2*time.Second) {
			mu.Unlock()
			return
		}

		drainCount := drainCounts[drainIndex]
		firstMessageTimes[drainIndex] = time.Time{}
		drainCounts[drainIndex] = 0
		mu.Unlock()

		report(cfg, datadogClient, drainCount, drainIndex)
	})
}

func toDataDogPoint(value int, t time.Time) []datadog.DataPoint {
	x, y := float64(t.Unix()), float64(value)
	return []datadog.DataPoint{
		[2]*float64{&x, &y},
	}
}

func report(
	cfg Config,
	datadogClient *datadog.Client,
	drainCount int,
	index int,
) {
	now := time.Now()
	metrics := []datadog.Metric{
		{
			Metric: datadog.String("syslog.smoke.actual"),
			Points: toDataDogPoint(drainCount, now),
			Host:   datadog.String(cfg.VcapApplication.SystemDomain),
			Tags: []string{
				"app:" + cfg.VcapApplication.ApplicationName,
				fmt.Sprintf("drain:%d", index),
			},
		},
		{
			Metric: datadog.String("syslog.smoke.expected"),
			Points: toDataDogPoint(cfg.TestCycles, now),
			Host:   datadog.String(cfg.VcapApplication.SystemDomain),
			Tags: []string{
				"app:" + cfg.VcapApplication.ApplicationName,
				fmt.Sprintf("drain:%d", index),
			},
		},
		{
			Metric: datadog.String("syslog.smoke.rate"),
			Points: toDataDogPoint(int(time.Duration(cfg.TestCycles)*time.Second/cfg.TestDuration), now),
			Host:   datadog.String(cfg.VcapApplication.SystemDomain),
			Tags: []string{
				"app:" + cfg.VcapApplication.ApplicationName,
				fmt.Sprintf("drain:%d", index),
			},
		},
	}

	err := datadogClient.PostMetrics(metrics)
	if err != nil {
		logger.Printf("Failed to post metrics: %s", err)
	}
	logger.Printf("Test results: actual is %d, expected is %d", drainCount, cfg.TestCycles)
}

func writeLogs(cfg Config, logMarker string) {
	logFrequency := cfg.TestDuration / time.Duration(cfg.TestCycles)

	for i := 0; i < cfg.TestCycles; i++ {
		fmt.Printf("%s Message\n", logMarker)

		time.Sleep(logFrequency)
	}
}

func LoadConfig() Config {
	cfg := Config{
		TestLatency: 5 * time.Second,
	}
	if err := envstruct.Load(&cfg); err != nil {
		logger.Fatal(err)
	}
	if !cfg.Producer && cfg.DataDogAPIKey == "" {
		logger.Fatal("Consumer requires DATADOG_API_KEY")
	}
	if !cfg.Producer && cfg.Port == 0 {
		logger.Fatal("Consumer requires PORT")
	}
	cfg.VcapApplication.SystemDomain = strings.Replace(cfg.VcapApplication.CAPIAddr, "https://api.", "", 1)
	envstruct.WriteReport(&cfg)
	return cfg
}

type VcapApplication struct {
	CAPIAddr        string `json:"cf_api"`
	SystemDomain    string
	ApplicationName string `json:"application_name"`
}

func (a *VcapApplication) UnmarshalEnv(data string) error {
	return json.Unmarshal([]byte(data), a)
}

type Config struct {
	// Port is used to read drained log messages.
	Port int `env:"PORT, report"`

	// VcapApplication is information about the app that cf supplies
	VcapApplication VcapApplication `env:"VCAP_APPLICATION, required"`

	// TestFrequency is how often to run the tests.
	TestFrequency time.Duration `env:"TEST_FREQUENCY, required, report"`

	// TestDuration is how long the test emits data.
	TestDuration time.Duration `env:"TEST_DURATION, required, report"`

	// TestCycles is how many log lines to emit.
	TestCycles int `env:"TEST_CYCLES, required, report"`

	// TestLatency is how long to wait for messages.
	TestLatency time.Duration `env:"TEST_LATENCY, report"`

	// DataDogAPIKey is the Datadog API key.
	DataDogAPIKey string `env:"DATADOG_API_KEY"`

	// Producer writes logs, defaults to consumer which reads in messages and
	// generates reports
	Producer bool `env:"PRODUCER, report"`
}
