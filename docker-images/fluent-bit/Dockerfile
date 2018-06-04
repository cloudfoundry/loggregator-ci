FROM fluent/fluent-bit:0.13

COPY /out_syslog.so /fluent-bit/bin/out_syslog.so

CMD ["/fluent-bit/bin/fluent-bit", "-e", "/fluent-bit/bin/out_syslog.so", "-c", "/fluent-bit/etc/fluent-bit.conf"]
