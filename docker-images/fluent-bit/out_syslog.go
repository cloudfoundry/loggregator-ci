package main

import (
	"net"

	"code.cloudfoundry.org/rfc5424"
	"github.com/fluent/fluent-bit-go/output"
)
import (
	"C"
	"fmt"
	"unsafe"
)

var conn net.Conn

//export FLBPluginRegister
func FLBPluginRegister(ctx unsafe.Pointer) int {
	return output.FLBPluginRegister(ctx, "syslog", "syslog output plugin that follows RFC 5424")
}

//export FLBPluginInit
// (fluentbit will call this)
// ctx (context) pointer to fluentbit context (state/ c code)
func FLBPluginInit(ctx unsafe.Pointer) int {
	addr := output.FLBPluginConfigKey(ctx, "addr")
	fmt.Printf("[out_syslog] addr = '%s'\n", addr)
	var err error
	conn, err = net.Dial("tcp", addr)
	if err != nil {
		return output.FLB_ERROR
	}
	return output.FLB_OK
}

//export FLBPluginFlush
func FLBPluginFlush(data unsafe.Pointer, length C.int, tag *C.char) int {
	var (
		ret    int
		ts     interface{}
		record map[interface{}]interface{}
	)

	dec := output.NewDecoder(data, int(length))

	for {
		ret, ts, record = output.GetRecord(dec)
		if ret != 0 {
			break
		}

		timestamp := ts.(output.FLBTime).Time

		msg := rfc5424.Message{
			Priority:  rfc5424.Info + rfc5424.User,
			Timestamp: timestamp,
			Hostname:  "syslog-fluentbit-test",
		}
		for k, v := range record {
			if key, ok := k.(string); ok && key == "log" {
				msg.Message = []byte(fmt.Sprintf("%s", v))
			}
		}
		msg.WriteTo(conn)
	}

	return output.FLB_OK
}

//export FLBPluginExit
func FLBPluginExit() int {
	return output.FLB_OK
}

func main() {
}
