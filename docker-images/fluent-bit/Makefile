all:
	go build -buildmode=c-shared -o out_syslog.so .

fast:
	go build out_syslog.go

clean:
	rm -rf *.so *.h *~
