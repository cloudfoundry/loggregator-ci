package main

import (
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"sync/atomic"
)

func main() {
	handler := NewSyslog()
	http.ListenAndServe(fmt.Sprintf(":%s", os.Getenv("PORT")), handler)
}

type Handler struct {
	count int64
}

func NewSyslog() *Handler {
	return &Handler{}
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path == "/drain" {
		body, err := ioutil.ReadAll(r.Body)
		if err != nil || len(body) == 0 {
			w.WriteHeader(http.StatusBadRequest)
			return
		}

		atomic.AddInt64(&h.count, 1)
		return
	}

	fmt.Fprint(w, atomic.LoadInt64(&h.count))
}
