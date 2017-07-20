#!/usr/bin/env python

import subprocess
import os
import json


def run_cf(*args, **env):
    return subprocess.Popen(
        ["/usr/bin/cf"] + list(args),
        env=env,
        cwd=os.getcwd(),
    ).wait()


def check_cf(*args, **env):
    if run_cf(*args, **env) != 0:
        raise subprocess.CalledProcessError


def cf_login(api, username, password, space, org):
    check_cf(
        "login",
        "-a", api,
        "-u", username,
        "-p", password,
        "-s", space,
        "-o", org,
    )


def push_app(app_name, *kwargs):
    # build the nozzle bin
    gopath=os.path.join(os.getcwd(), "loggregator")
    pwd=os.path.join(gopath, "src/tools/reliability/cmd/nozzle")
    subprocess.Popen([
        "/usr/local/go/bin/go",
        "build",
    ], env={
        "GOPATH": gopath,
        "PWD": pwd,
    }).wait()

    check_cf(
        "push",
        app_name,
        "-c", "./nozzle",
        "-b", "binary_buildpack",
        "--no-start",
        PWD=pwd,
    )

    for k, v in kwargs:
        check_cf("set-env", app_name, k, v)

    check_cf("start", app_name)


def ensure_app_pushed(app_name, **kwargs):
    if run_cf("app", app_name) != 0:
        push_app(app_name, **kwargs)


def trigger_test(app_domain, cycles, delay, timeout):
    payload = '''{"cycles": {}, "delay": "{}", "timeout": "{}"}'''
    subprocess.call([
      "/usr/bin/curl",
      app_domain + "/tests",
      "-H", "Content-Type: application/json",
      "-d", payload.format(cycles, delay, timeout),
    ])


def endpoints():
    info = subprocess.Popen([
        "/usr/bin/cf",
        "curl",
        "/v2/info",
    ], cwd=os.getcwd(), stdout=subprocess.PIPE).stdout
    info = json.load(info)
    return info["token_endpoint"], info["doppler_logging_endpoint"]


def main():
    cf_login(
        os.environ['CF_API'],
        os.environ['USERNAME'],
        os.environ['PASSWORD'],
        os.environ['SPACE'],
        os.environ['ORG'],
    )
    uaa_endpoint, log_endpoint = endpoints()
    ensure_app_pushed(
        os.environ['APP_NAME'],
        UAA_ADDR=uaa_endpoint,
        CLIENT_ID=os.environ['CLIENT_ID'],
        CLIENT_SECRET=os.environ['CLIENT_SECRET'],
        DATADOG_API_KEY=os.environ['DATADOG_API_KEY'],
        LOG_ENDPOINT=log_endpoint,
    )

    # # flood
    # trigger_test(
    #     os.environ['APP_DOMAIN'],
    #     10000,
    #     "2us",
    #     "60s",
    # )

    # # flow
    # trigger_test(
    #     os.environ['APP_DOMAIN'],
    #     1000,
    #     "1ms",
    #     "60s",
    # )

    # # drip
    # trigger_test(
    #     os.environ['APP_DOMAIN'],
    #     1000,
    #     "500ms",
    #     "10m",
    # )


if __name__ == "__main__":
    main()
