#!/usr/bin/env python3
# -*- coding: utf-8 -*-
'''
Copyright (C) 2023

Author: qsdrqs <qsdrqs@gmail.com>
All Right Reserved

This file is for getting the input for the flake

'''

import subprocess
import json
import os
import urllib.request
import urllib.parse
import fnmatch


def get_github_api_token():
    cred_path = os.path.expanduser('~/.git-credentials')
    try:
        with open(cred_path, 'r') as file:
            lines = file.readlines()
        for line in lines:
            obj = urllib.parse.urlparse(line.strip())
            if obj.hostname == 'github.com':
                token = obj.password
                return token

        return None
    except FileNotFoundError:
        return None

def get_repo_versions(owner, repo):
    url_template = f"https://api.github.com/repos/{owner}/{repo}/releases?page={{}}&per_page=100"

    versions = []
    page = 1
    while True:
        url = url_template.format(page)
        token = get_github_api_token()
        headers = {}
        if token:
            headers['Authorization'] = f'Bearer {token}'
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req) as response:
            if response.status != 200:
                print("HTTP error:", response.status)
                break
            data = json.load(response)
        if not data:
            break
        versions.extend([release["tag_name"] for release in data])
        page += 1
    return versions

def main():
    dotfiles_dir = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
    cmd = f'nvim --clean --headless \
        --cmd "let g:plugins_loaded=1 | let g:no_wait_headless = 1" \
        -c \'lua DumpPluginsList(); vim.cmd("q")\' \
        -u {dotfiles_dir}/.nvimrc.lua'
    result = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    plugins: list[str] = []
    for line in result.stderr.decode('utf-8').split("\r\n\r\n"):
        if line != '\r\n' and line != '':
            # remove the '\r\n' and the empty line
            line = line.replace('\r\n', '')
            plugins.append(line)

    plugins_dict = {}
    for plugin in plugins:
        tmp = plugin.split()
        plugin = tmp[0]
        opts = ' '.join(tmp[1:])
        json_opts = json.loads(opts)

        # check dependency
        if 'dependencies' in json_opts:
            for dep in json_opts['dependencies']:
                if type(dep) == str and dep.count('/') == 1:
                    dep_name = dep.split('/')[1]
                    dep_name = dep_name.replace('.', 'DOT')
                    if dep_name in plugins_dict:
                        continue
                    dep_url = f'github:{dep}'
                    plugins_dict[dep_name] = {
                        'url': dep_url,
                        'build': False,
                    }

        plugin_url: str = ""
        plugin_name: str = ""
        if plugin.count('/') == 1:
            plugin_name = plugin.split('/')[1]
            plugin_name = plugin_name.replace('.', 'DOT')
            plugin_url = f'github:{plugin}'

        else:
            if plugin != "dotfiles":
                plugin_name = plugin.split('/')[-1]
                plugin_name = plugin_name.replace('.', 'DOT')
                plugin_url = f'git+{plugin}'

        # check build
        need_build = False
        if 'build' in json_opts and json_opts['build'] == True:
            need_build = True

        # check branch
        branch = None
        if 'branch' in json_opts:
            branch = json_opts['branch']

        # check tag
        tag = None
        if 'tag' in json_opts:
            tag = json_opts['tag']

        version = None
        if 'version' in json_opts:
            version = json_opts['version']
            if not version.startswith('v'):
                version = 'v' + version
            if '*' in version:
                owner, repo = plugin.split('/')
                versions = get_repo_versions(owner, repo)
                if versions:
                    # try to find the latest version that matches the pattern
                    versions.sort(reverse=True)
                    for v in versions:
                        if fnmatch.fnmatch(v, version):
                            tag = v
                            break
                else:
                    raise Exception(f'plugin {plugin} has no releases')
            else:
                tag = version

        # check commit
        commit = None
        if 'commit' in json_opts:
            commit = json_opts['commit']

        if plugin_url != "" and plugin_name != "":
            if branch != None and commit != None:
                raise Exception(f'plugin {plugin_name} has both branch and commit')
            url = plugin_url
            if commit != None:
                url += f'?rev={commit}'
            if branch != None:
                url += f'?ref={branch}'
            if tag != None:
                url += f'/{tag}'
            plugins_dict[plugin_name] = {
                'url': url,
                'build': need_build,
            }

    with open('flake.nix', 'w') as f:
        plugin_lines = ';'.join(f'''
    {k} = {{
      url = "{v['url']}";
      flake = false;
    }}''' for k, v in plugins_dict.items())

        plugins_list = '\n        '.join(f'{{ name = "{k.replace("DOT", ".")}"; dotname = "{k}"; source = inputs.{k}; build = {str(v["build"]).lower()}; }}' for k, v in plugins_dict.items())

        f.write(f'''# Generated by dump_input.py, do not edit
{{
  description = "Neovim with plugins";
  inputs = {{
    neovim.url = "github:nix-community/neovim-nightly-overlay";
{plugin_lines};
  }};
  outputs = {{ self, ... }}@inputs:
    {{
      plugins_list = [
        {plugins_list}
      ];
    }} //
    import ./flake_out.nix {{
      inherit self inputs;
    }};
}}''')



if __name__ == '__main__':
    main()
