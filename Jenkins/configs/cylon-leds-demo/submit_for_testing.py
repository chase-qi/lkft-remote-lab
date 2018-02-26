import argparse
import os
import requests
import sys
import StringIO
from copy import deepcopy
from string import Template
from ruamel.yaml import YAML


try:
    from urllib.parse import urlsplit
except ImportError:
    from urlparse import urlsplit


def _submit_to_squad(lava_job, lava_url_base, qa_server_api, qa_server_base, qa_token, quiet):
    headers = {
        "Auth-Token": qa_token
    }

    try:
        data = {
            "definition": lava_job,
            "backend": urlsplit(lava_url_base).netloc  # qa-reports backends are named as lava instances
        }
        print("Submit to: %s" % qa_server_api)
        results = requests.post(qa_server_api, data=data, headers=headers,
                                timeout=31)
        if results.status_code < 300:
            print("%s/testjob/%s" % (qa_server_base, results.text))
        else:
            print(results.status_code)
            print(results.text)
    except requests.exceptions.RequestException as err:
        print("QA Reports submission failed")
        if not quiet:
            print("offending job definition:")
            print(lava_job)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--device-type",
                        help="Device type in LAVA",
                        dest="device_type",
                        required=True)
    parser.add_argument("--env-prefix",
                        help="Prefix for the environment name",
                        dest="env_prefix",
                        default="")
    parser.add_argument("--env-suffix",
                        help="Suffix for the environment name",
                        dest="env_suffix",
                        default="")
    parser.add_argument("--build-number",
                        help="Build number",
                        dest="build_number",
                        required=True)
    parser.add_argument("--qa-server-team",
                        help="Team in QA Reports service",
                        dest="qa_server_team",
                        required=True)
    parser.add_argument("--qa-server-project",
                        help="Project in QA Reports service",
                        dest="qa_server_project",
                        required=True)
    parser.add_argument("--qa-server",
                        help="QA Reports server",
                        dest="qa_server",
                        default="https://qa-reports.linaro.org")
    parser.add_argument("--qa-token",
                        help="QA Reports token",
                        dest="qa_token",
                        default=os.environ.get('QA_REPORTS_TOKEN'))
    parser.add_argument("--lava-server",
                        help="LAVA server URL",
                        dest="lava_server",
                        required=True)
    parser.add_argument("--test-plan",
                        help="LAVA test plan.",
                        dest="test_plan",
                        required=True)
    parser.add_argument("--quiet",
                        help="Only output the final qa-reports URL",
                        action='store_true',
                        dest="quiet")

    args, _ = parser.parse_known_args()

    qa_server_base = args.qa_server
    if not (qa_server_base.startswith("http://") or qa_server_base.startswith("https://")):
        qa_server_base = "https://" + qa_server_base
    qa_server_team = args.qa_server_team
    qa_server_project = args.qa_server_project
    qa_server_build = args.build_number
    qa_server_env = args.env_prefix + args.device_type + args.env_suffix
    qa_server_api = "%s/api/submitjob/%s/%s/%s/%s" % (
        qa_server_base,
        qa_server_team,
        qa_server_project,
        qa_server_build,
        qa_server_env)
    lava_server = args.lava_server
    if not (lava_server.startswith("http://") or lava_server.startswith("https://")):
        lava_server = "https://" + lava_server
    lava_url_base = "%s://%s/" % (urlsplit(lava_server).scheme, urlsplit(lava_server).netloc)

    output = StringIO.StringIO()
    with open(args.test_plan) as f:
        yaml = YAML()
        yaml.dump(yaml.load(f), output)
        lava_job = output.getvalue()
        print(lava_job)

    _submit_to_squad(lava_job,
        lava_url_base,
        qa_server_api,
        qa_server_base,
        args.qa_token,
        args.quiet)

if __name__ == "__main__":
    main()
