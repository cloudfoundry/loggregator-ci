package main

import (
	"bytes"
	"fmt"
	"log"
	"os"
	"os/exec"
	"sync"

	envstruct "code.cloudfoundry.org/go-envstruct"
)

func main() {
	cfg := LoadConfig()

	log.Printf("deploying %d apps to %d spaces", cfg.AppCount(), cfg.SpaceCount())
	log.Printf("a total of %d app drains will be created", cfg.TotalDrainCount())

	// Start Worker Pool
	var wg sync.WaitGroup
	wg.Add(cfg.WorkerCount)

	taskChan := make(chan Task)
	for i := 0; i < cfg.WorkerCount; i++ {
		go func(idx int) {
			defer wg.Done()
			log.Printf("starting worker %d", idx)
			NewWorker(i, taskChan).Run()
		}(i)
	}

	// Queue Deploy Work
	for spaceIndex := 0; spaceIndex < cfg.SpaceCount(); spaceIndex++ {
		spaceID := cfg.StartingSpaceID + spaceIndex
		log.Printf("creating executor for space %d", spaceID)
		executor, err := NewCFExecutor(spaceID, cfg)
		if err != nil {
			log.Printf("failed to create executor: %s", err)
		}

		for appIndex := 0; appIndex < cfg.AppsPerSpace; appIndex++ {
			taskChan <- Task{
				SpaceID:  spaceID,
				AppID:    appIndex,
				Config:   cfg,
				Executor: executor,
			}
		}
	}

	close(taskChan)
	wg.Wait()
}

type Config struct {
	SystemDomain      string `env:"SYSTEM_DOMAIN,        required, report"`
	APIEndpoint       string `env:"API_ENDPOINT,        required, report"`
	SkipSSLValidation bool   `env:"SKIP_SSL_VALIDATION, report"`
	Org               string `env:"ORG,                 required, report"`
	Username          string `env:"USERNAME,            required, report"`
	Password          string `env:"PASSWORD,            required"`
	ScriptCommand     string `env:"SCRIPT_COMMAND,      required, report"`
	ScriptCommandDir  string `env:"SCRIPT_COMMAND_DIR,  required, report"`
	DropletGUID       string `env:"DROPLET_GUID,        required, report"`

	SpacePrefix     string `env:"SPACE_PREFIX,      report"`
	AppPrefix       string `env:"APP_PREFIX,        report"`
	AppsPerSpace    int    `env:"APPS_PER_SPACE,    report"`
	StartingSpaceID int    `env:"STARTING_SPACE_ID, report"`
	EndingSpaceID   int    `env:"ENDING_SPACE_ID,   report"`

	DatadogAPIKey string `env:"DATADOG_API_KEY, required"`

	DrainCount  int `env:"DRAIN_COUNT, report"`
	WorkerCount int `env:"WORKER_COUNT,  report"`
}

func (c Config) AppCount() int {
	return c.AppsPerSpace * c.SpaceCount()
}

func (c Config) TotalDrainCount() int {
	return c.DrainCount * c.AppCount()
}

func (c Config) SpaceCount() int {
	return c.EndingSpaceID - c.StartingSpaceID
}

func LoadConfig() Config {
	cfg := Config{
		DrainCount:  5,
		WorkerCount: 10,
	}

	if err := envstruct.Load(&cfg); err != nil {
		log.Fatalf("failed to load config from environment: %s", err)
	}

	if cfg.EndingSpaceID < cfg.StartingSpaceID {
		log.Fatalf("STARTING_SPACE_ID cannot be larger than ENDING_SPACE_ID")
	}

	_ = envstruct.WriteReport(&cfg)

	return cfg
}

type Task struct {
	SpaceID  int
	AppID    int
	Config   Config
	Executor *CFExecutor
}

func (t Task) BaseAppName() string {
	return fmt.Sprintf("%d-%d-%s", t.SpaceID, t.AppID, t.Config.AppPrefix)
}

func (t Task) ConsumerAppName() string {
	return fmt.Sprintf("%s-consumer", t.BaseAppName())
}

func (t Task) ProducerAppName() string {
	return fmt.Sprintf("%s-producer", t.BaseAppName())
}

type Worker struct {
	ID       int
	taskChan chan Task
}

func NewWorker(id int, tc chan Task) *Worker {
	return &Worker{
		ID:       id,
		taskChan: tc,
	}
}

func (w *Worker) Run() {
	for t := range w.taskChan {
		log.Printf("deploying %s", t.BaseAppName())
		out, err := t.Executor.Exec(
			t.Config.ScriptCommand,
			t.BaseAppName(),
			t.Config.SystemDomain,
			t.Config.DatadogAPIKey,
			t.Config.DropletGUID,
		)
		if err != nil {
			log.Printf("ERROR: %s", err)
			log.Println("STDOUT:")
			log.Println(out.Stderr.String())
			log.Println("STDERR:")
			log.Println(out.Stdout.String())
		}
	}
}

type CFExecutor struct {
	CFHome     string
	CommandDir string
}

func NewCFExecutor(spaceID int, cfg Config) (*CFExecutor, error) {
	space := fmt.Sprintf("%s-%d", cfg.SpacePrefix, spaceID)
	spaceHome := "/tmp/" + space
	currentDrainPluginPath := fmt.Sprintf("%s/.cf/plugins/drains", os.Getenv("HOME"))

	os.MkdirAll(spaceHome, os.ModeDir)

	e := &CFExecutor{
		CFHome:     spaceHome,
		CommandDir: cfg.ScriptCommandDir,
	}

	installPlugin := []string{
		"install-plugin",
		currentDrainPluginPath,
		"-f",
	}

	e.CF(installPlugin...)

	login := []string{
		"login",
		"-a", cfg.APIEndpoint,
		"-u", cfg.Username,
		"-p", cfg.Password,
		"-o", cfg.Org,
		"-s", space,
	}

	if cfg.SkipSSLValidation {
		login = append(login, "--skip-ssl-validation")
	}

	out, err := e.CF(login...)
	if err != nil {
		log.Printf("ERROR: %s", err)
		log.Println("STDOUT:")
		log.Println(out.Stderr.String())
		log.Println("STDERR:")
		log.Println(out.Stdout.String())
	}
	return e, err
}

func (e *CFExecutor) CF(args ...string) (*Output, error) {
	return e.Exec("cf", args...)
}

func (e *CFExecutor) Exec(cmd string, args ...string) (*Output, error) {
	c := exec.Command(cmd, args...)
	c.Env = append(os.Environ(), fmt.Sprintf("CF_HOME=%s", e.CFHome))
	c.Dir = e.CommandDir

	out := NewOutput()
	c.Stdout = out.Stdout
	c.Stderr = out.Stderr

	return out, c.Run()
}

type Output struct {
	Stderr *bytes.Buffer
	Stdout *bytes.Buffer
}

func NewOutput() *Output {
	return &Output{
		Stderr: bytes.NewBuffer(nil),
		Stdout: bytes.NewBuffer(nil),
	}
}
