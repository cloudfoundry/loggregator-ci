#!/usr/bin/env python

import subprocess
import os
import json
import shutil


def run_cf(*args, **env):
    env.update({"CF_HOME": os.getcwd()})
    p = subprocess.Popen(
        ["/usr/bin/cf"] + list(args),
        env=env,
        cwd=env.get("PWD"),
        stdout=subprocess.PIPE,
    )

    return p.wait(), p.stdout.read()


def check_cf(*args, **env):
    exit_code, output = run_cf(*args, **env)
    print(output)
    if exit_code != 0:
        raise subprocess.CalledProcessError(exit_code, args)


def cf_login(api, username, password, space, org, skip_cert_verify):
    args = [
        "login",
        "-a", api,
        "-u", username,
        "-p", password,
        "-s", space,
        "-o", org,
    ]

    if skip_cert_verify == "true":
        args.append("--skip-ssl-validation")

    check_cf(*args)


def push_worker(app_name, instance_count, **kwargs):
    gopath = os.environ["GOPATH"]
    cwd=os.path.join(gopath, "src/code.cloudfoundry.org/loggregator-tools/reliability/worker")

    # build the worker bin
    exit_code = subprocess.Popen([
        "/usr/local/go/bin/go",
        "build",
    ], cwd=cwd).wait()
    if exit_code != 0:
        raise subprocess.CalledProcessError(exit_code, args)

    check_cf(
        "push",
        app_name,
        "-c", "./worker",
        "-b", "binary_buildpack",
        "-i", instance_count,
        "-m", "256M",
        "-u", "none",
        "--no-route",
        "--no-start",
        PWD=cwd,
    )

    for k, v in kwargs.items():
        check_cf("set-env", app_name, k, v)

    check_cf("start", app_name)


def push_server(app_name):
    gopath = os.environ["GOPATH"]
    cwd=os.path.join(gopath, "src/code.cloudfoundry.org/loggregator-tools/reliability/server")

    # build the server bin
    exit_code = subprocess.Popen([
        "/usr/local/go/bin/go",
        "build",
    ], cwd=cwd).wait()
    if exit_code != 0:
        raise subprocess.CalledProcessError(exit_code, args)

    check_cf(
        "push",
        app_name,
        "-c", "./server",
        "-b", "binary_buildpack",
        "-m", "256M",
        "--no-start",
        PWD=cwd,
    )

    check_cf("start", app_name)


def is_app_failed(output):
    return output.find("crashed") >= 0 or output.find("stopped") >= 0 or output.find("no running instances") >= 0

def trigger_test(app_domain, cycles, delay, timeout):
    payload = {
        "cycles": cycles,
        "delay": delay,
        "timeout": timeout,
    }
    args = [
      "/usr/bin/curl",
      app_domain + "/tests",
      "-H", "Content-Type: application/json",
      "-d", json.dumps(payload),
      "--fail",
    ]
    print "running test:", args
    subprocess.check_call(args)


def endpoints():
    p = subprocess.Popen([
        "/usr/bin/cf",
        "curl",
        "/v2/info",
    ], stdout=subprocess.PIPE, env={"CF_HOME": os.getcwd()})
    exit_code = p.wait()
    if exit_code != 0:
        raise subprocess.CalledProcessError(exit_code, args)
    info = json.load(p.stdout)
    return info["token_endpoint"], info["doppler_logging_endpoint"]


def get_cf_password():
    try:
        file = open("cf-credentials/password", "r")
        return file.read()
    except:
        return os.environ['PASSWORD']


def move_tools_to_gopath():
    cwd = os.getcwd()

    gopath = os.environ["GOPATH"]
    dest = os.path.join(gopath, "src/code.cloudfoundry.org/loggregator-tools")

    shutil.copytree(os.path.join(cwd, "loggregator-tools"), dest)

    exit_code = subprocess.Popen([
        "/usr/local/go/bin/go",
        "get",
        "./...",
    ], cwd=dest).wait()
    if exit_code != 0:
        raise subprocess.CalledProcessError(exit_code, args)


def main():
    move_tools_to_gopath()

    cf_password = get_cf_password()
    cf_login(
        os.environ['CF_API'],
        os.environ['USERNAME'],
        cf_password,
        os.environ['SPACE'],
        os.environ['ORG'],
        os.environ['SKIP_CERT_VERIFY'],
    )
    uaa_endpoint, log_endpoint = endpoints()
    push_server(os.environ['APP_NAME'])
    push_worker(
        os.environ['APP_NAME'] + '-worker',
        os.environ['WORKER_INSTANCE_COUNT'],
        UAA_ADDR=uaa_endpoint,
        CLIENT_ID=os.environ['CLIENT_ID'],
        CLIENT_SECRET=os.environ['CLIENT_SECRET'],
        DATADOG_API_KEY=os.environ['DATADOG_API_KEY'],
        LOG_ENDPOINT=log_endpoint,
        HOSTNAME=os.environ['APP_DOMAIN'],
        SKIP_CERT_VERIFY=os.environ['SKIP_CERT_VERIFY'],
        CONTROL_SERVER_ADDR='wss://'+os.environ['APP_DOMAIN']+':'+ os.environ['APP_WS_PORT']+'/workers',
    )

    # flood
    trigger_test(
        os.environ['APP_DOMAIN'],
        10000,
        "2us",
        "60s",
    )

    # flow
    trigger_test(
        os.environ['APP_DOMAIN'],
        1000,
        "1ms",
        "60s",
    )

    # drip
    trigger_test(
        os.environ['APP_DOMAIN'],
        1000,
        "500ms",
        "10m",
    )


if __name__ == "__main__":
    main()
