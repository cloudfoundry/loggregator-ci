package main

import (
	"bytes"
	"crypto/tls"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"net/url"
	"os"
	"sync/atomic"
	"time"

	"github.com/cloudfoundry/noaa/consumer"
	"github.com/cloudfoundry/sonde-go/events"
)

var (
	logMessage       string
	messagesSent     int64
	messagesReceived int64

	tlsConfig *tls.Config = &tls.Config{
		InsecureSkipVerify: true,
	}

	httpClient *http.Client = &http.Client{
		Timeout: 30 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: tlsConfig,
		},
	}

	reportReadMessages bool
)

const datadogAddr = "https://app.datadoghq.com/api/v1/series"

type VCAPApplication struct {
	APIAddr string `json:"cf_api"`
	AppID   string `json:"application_id"`
	AppName string `json:"application_name"`
}

type V2Info struct {
	DopplerAddr string `json:"doppler_logging_endpoint"`
	UAAAddr     string `json:"token_endpoint"`
}

type AuthInfo struct {
	ClientID     string
	ClientSecret string
}

func main() {
	logsPerSecond := flag.Uint("logs-per-second", 1000, "Log messages to emit per second. Default: 1000")
	logSize := flag.Uint("log-bytes", 1000, "Length of log messages in bytes. Default: 1000")
	datadogAPIKey := flag.String("datadog-api-key", "", "Datadog API key for emitting metrics.")

	var authInfo AuthInfo
	flag.StringVar(&authInfo.ClientID, "client-id", "", "ID of client used for authentication.")
	flag.StringVar(&authInfo.ClientSecret, "client-secret", "", "Secret used for authentication.")

	flag.Parse()

	vcapApp := loadVCAP()
	reportReadMessages = os.Getenv("INSTANCE_INDEX") == "0"
	if reportReadMessages {
		v2Info, err := getV2Info(vcapApp.APIAddr)
		if err != nil {
			log.Fatalf("failed to get API info: %s", err)
		}

		go readLogsLoop(vcapApp, v2Info, authInfo)
	}

	go report(vcapApp.AppName, vcapApp.APIAddr, *datadogAPIKey)

	for i := uint(0); i < *logSize; i++ {
		logMessage += "?"
	}

	emitLogs(*logsPerSecond)
}

func emitLogs(logsPerSecond uint) {
	interval := time.Second / time.Duration(logsPerSecond)
	for {
		startTime := time.Now()
		emitLog()
		timeToSleep := interval - time.Since(startTime)
		time.Sleep(timeToSleep)
	}
}

func loadVCAP() *VCAPApplication {
	var vcapApp VCAPApplication
	err := json.Unmarshal([]byte(os.Getenv("VCAP_APPLICATION")), &vcapApp)
	if err != nil {
		log.Fatalf("failed to unmarshal VCAP_APPLICATION: %s", err)
	}

	return &vcapApp
}

func report(appName, host, datadogAPIKey string) {
	dURL, err := url.Parse(datadogAddr)
	if err != nil {
		log.Fatalf("Failed to parse datadog URL: %s", err)
	}
	query := url.Values{
		"api_key": []string{datadogAPIKey},
	}
	dURL.RawQuery = query.Encode()

	ticker := time.NewTicker(5 * time.Minute)
	for range ticker.C {
		sent := atomic.SwapInt64(&messagesSent, 0)
		received := atomic.SwapInt64(&messagesReceived, 0)

		data, err := buildMessagesBody(host, appName, sent, received)
		if err != nil {
			log.Printf("failed to build request body for datadog: %s", err)
			continue
		}

		log.Printf("Sending data to datadog: %s", data)

		response, err := httpClient.Post(dURL.String(), "application/json", bytes.NewBuffer(data))
		if err != nil {
			log.Printf("failed to post to datadog: %s", err)
			continue
		}

		if response.StatusCode > 299 || response.StatusCode < 200 {
			log.Printf("Expected successful status code from Datadog, got %d", response.StatusCode)
			continue
		}
	}
}

type Metric struct {
	Metric string    `json:"metric"`
	Points [][]int64 `json:"points"`
	Type   string    `json:"type"`
	Host   string    `json:"host"`
	Tags   []string  `json:"tags"`
}

func buildMessagesBody(host, appName string, sent, received int64) ([]byte, error) {
	currentTime := time.Now()

	metrics := []Metric{
		{
			Metric: "capacity_planning.messages_sent",
			Points: [][]int64{
				[]int64{currentTime.Unix(), sent},
			},
			Type: "gauge",
			Host: host,
			Tags: []string{appName},
		},
	}

	if reportReadMessages {
		metrics = append(metrics, Metric{
			Metric: "capacity_planning.messages_received",
			Points: [][]int64{
				[]int64{currentTime.Unix(), received},
			},
			Type: "gauge",
			Host: host,
			Tags: []string{appName},
		})
	}

	body := map[string][]Metric{"series": metrics}

	return json.Marshal(&body)
}

func readLogsLoop(vcapApp *VCAPApplication, v2Info *V2Info, authInfo AuthInfo) {
	for {
		authToken, err := authenticateWithUaa(v2Info.UAAAddr, authInfo)
		if err != nil {
			log.Printf("failed to authenticate with UAA: %s", err)
			time.Sleep(time.Second)
			continue
		}

		readLogs(vcapApp.AppID, v2Info.DopplerAddr, authToken)
	}
}

func readLogs(appID, dopplerAddr, authToken string) {
	cmr := consumer.New(dopplerAddr, tlsConfig, nil)

	msgChan, errChan := cmr.Stream(appID, authToken)

	go func() {
		for err := range errChan {
			if err == nil {
				return
			}

			log.Println(err)
		}
	}()

	for msg := range msgChan {
		if msg == nil {
			return
		}

		if msg.GetEventType() == events.Envelope_LogMessage {
			log := msg.GetLogMessage()
			if bytes.Contains(log.GetMessage(), []byte(logMessage)) {
				atomic.AddInt64(&messagesReceived, 1)
			}
		}
	}
}

func emitLog() {
	atomic.AddInt64(&messagesSent, 1)
	fmt.Printf("%s\n", logMessage)
}

func authenticateWithUaa(uaaAddr string, authInfo AuthInfo) (string, error) {
	response, err := httpClient.PostForm(uaaAddr+"/oauth/token", url.Values{
		"response_type": []string{"token"},
		"grant_type":    []string{"client_credentials"},
		"client_id":     []string{authInfo.ClientID},
		"client_secret": []string{authInfo.ClientSecret},
	})
	if err != nil {
		return "", err
	}
	if response.StatusCode != http.StatusOK {
		return "", fmt.Errorf("Expected 200 status code from /oauth/token, got %d", response.StatusCode)
	}

	body, err := ioutil.ReadAll(response.Body)
	response.Body.Close()
	if err != nil {
		return "", err
	}

	oauthResponse := make(map[string]interface{})
	err = json.Unmarshal(body, &oauthResponse)
	if err != nil {
		return "", err
	}

	accessTokenInterface, ok := oauthResponse["access_token"]
	if !ok {
		return "", errors.New("No access_token on UAA oauth response")
	}

	accessToken, ok := accessTokenInterface.(string)
	if !ok {
		return "", errors.New("access_token on UAA oauth response not a string")
	}

	return "bearer " + accessToken, nil
}

func getV2Info(uaaAddr string) (*V2Info, error) {
	response, err := httpClient.Get(uaaAddr + "/v2/info")
	if err != nil {
		return nil, err
	}
	if response.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("Expected 200 status code from /v2/info, got %d", response.StatusCode)
	}

	body, err := ioutil.ReadAll(response.Body)
	response.Body.Close()
	if err != nil {
		return nil, err
	}

	var v2Info V2Info
	err = json.Unmarshal(body, &v2Info)
	if err != nil {
		return nil, err
	}

	return &v2Info, nil
}
