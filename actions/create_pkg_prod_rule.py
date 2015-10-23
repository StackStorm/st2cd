#! /usr/bin/env python

import argparse
import json
import requests
import sys


def create_rule(url, rule):
    # check if rule with the same name exists
    existing_rule_id = _get_rule_id(url, rule)

    headers = {'created-from': 'Action: ' + __name__}
    # TODO: Figure out AUTH
    if existing_rule_id:
        sys.stderr.write('Updating existing rule %s\n' % existing_rule_id)
        put_url = '%s/%s' % (url, existing_rule_id)
        rule['id'] = existing_rule_id
        resp = requests.put(put_url, data=json.dumps(rule), headers=headers)
    else:
        sys.stderr.write('Creating new rule %s\n' % rule['name'])
        sys.stderr.write('url=%s, data=%s' % (url, json.dumps(rule)))
        resp = requests.post(url, data=json.dumps(rule), headers=headers)

    if resp.status_code not in [200, 201]:
        raise Exception('Failed creating rule in st2. status code: %s' % resp.status_code)


def _get_rule_id(base_url, rule):
    get_url = '%s/?name=%s' % (base_url, rule['name'])
    sys.stderr.write(get_url)
    resp = requests.get(get_url)
    if resp.status_code in [200]:
        if len(resp.json()) > 0:
            return resp.json()[0]['id']
    return None


def _get_st2_rules_url(base_url):
    if base_url.endswith('/'):
        return base_url + 'rules'
    else:
        return base_url + '/rules'


def _create_distro_rule_meta(distro, branch, dl_server, distro_release=None):
    rule_meta = {
        'name': 'st2_pkg_prod_%s_%s' % (branch, distro.lower()),
        'pack': 'st2cd',
        'description': 'Build %s production packages.' % distro.lower(),
        'enabled': True,
        'trigger': {
            'type': 'core.st2.generic.actiontrigger'
        },
        'criteria': {
            'trigger.action_ref': {
                'pattern': 'st2cd.st2workroom_test',
                'type': 'equals'
            },
            'trigger.status': {
                'pattern': 'succeeded',
                'type': 'equals'
            },
            'trigger.parameters.branch': {
                'pattern': branch,
                'type': 'equals'
            },
            'trigger.parameters.distro': {
                'pattern': distro.upper(),
                'type': 'equals'
            },
            'trigger.parameters.pkg_st2': {
                'pattern': True,
                'type': 'equals'
            }
        },
        'action': {
            'ref': 'st2cd.st2_pkg_%s' % distro.lower(),
            'parameters': {
                'repo': '{{trigger.parameters.repo}}',
                'branch': branch,
                'dl_server': dl_server,
                'environment': 'production',
                'revision': '{{trigger.parameters.revision}}',
                'build': '{{trigger.parameters.build}}'
            }
        }
    }

    # Special parameter for releases with distro numbers. RHEL6 and RHEL7
    if distro_release:
        rule_meta['action']['parameters']['distro_release'] = distro_release

    return rule_meta


def main(args):
    parser = argparse.ArgumentParser(description='Create a rule to that builds prod ' +
                                                 'packaged on a branch.')
    parser.add_argument('--branch', help='Branch to use.',
                        required=True)
    parser.add_argument('--st2-base-url', help='st2 base url.',
                        required=True)
    args = parser.parse_args()

    if args.branch in ['master']:
        sys.stderr.write('Master is not allowed branch for release.')
        sys.exit(1)

    if not args.st2_base_url:
        sys.stderr.write('st2 URL needed to create a rule.')
        sys.exit(2)

    # ubuntu14 rule
    try:
        rule_meta = _create_distro_rule_meta(distro='ubuntu14', branch=args.branch,
                                             dl_server='{{system.apt_origin_production}}')
        create_rule(_get_st2_rules_url(args.st2_base_url), rule_meta)
        sys.stdout.write('Successfully created rule %s\n' % rule_meta['name'])
    except Exception as e:
        sys.stderr.write('Failed creating rule %s: %s\n' % (rule_meta['name'], str(e)))
        sys.exit(1)

    # rhel7 rule
    try:
        rule_meta = _create_distro_rule_meta(distro='rhel7', branch=args.branch,
                                             dl_server='{{system.yum_origin_production}}',
                                             distro_release='7')
        create_rule(_get_st2_rules_url(args.st2_base_url), rule_meta)
        sys.stdout.write('Successfully created rule %s\n' % rule_meta['name'])
    except Exception as e:
        sys.stderr.write('Failed creating rule %s: %s\n' % (rule_meta['name'], str(e)))
        sys.exit(1)

    # rhel6 rule
    try:
        rule_meta = _create_distro_rule_meta(distro='rhel6', branch=args.branch,
                                             dl_server='{{system.yum_origin_production}}',
                                             distro_release='6')
        create_rule(_get_st2_rules_url(args.st2_base_url), rule_meta)
        sys.stdout.write('Successfully created rule %s\n' % rule_meta['name'])
    except Exception as e:
        sys.stderr.write('Failed creating rule %s: %s\n' % (rule_meta['name'], str(e)))
        sys.exit(1)


if __name__ == '__main__':
    main(sys.argv)
