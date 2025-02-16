#!/bin/sh
#<pre>

############################################################
# <h1>Cheat Sheet at CHEATSHEET_URL</h1>
# <meta http-equiv="refresh" content="3; URL='CHEATSHEET_URL'" />
############################################################

#set -x

__install_webi() {

    #WEBI_PKG=
    #WEBI_HOST=https://webinstall.dev
    export WEBI_HOST

    if test -z "$WEBI_WELCOME"; then
        echo ""
        printf "Thanks for using webi to install '\e[32m%s\e[0m' on '\e[33m%s/%s\e[0m'.\n" "${WEBI_PKG-}" "$(uname -s)/$(uname -r)" "$(uname -m)"
        echo "Have a problem? Experience a bug? Please let us know:"
        printf "        \e[2m\e[36mhttps://github.com/webinstall/webi-installers/issues\e[0m\n"
        echo ""
        printf "\e[35mLovin'\e[0m it? Say thanks with a \e[1m\e[33mStar on GitHub\e[0m:\n"
        printf "        \e[36mhttps://github.com/webinstall/webi-installers\e[0m\n"
        echo ""
    fi

    WEBI_WELCOME=true
    export WEBI_WELCOME

    set -e
    set -u

    mkdir -p "$HOME/.local/bin"

    cat << EOF > "$HOME/.local/bin/webi"
#!/bin/sh

set -e
set -u
#set -x

__webi_main() {

    my_date="\$(date +%F_%H-%M-%S)"
    export WEBI_TIMESTAMP="\${my_date}"
    export _webi_tmp="\${_webi_tmp:-\$(
        mktemp -d -t "webi-\$WEBI_TIMESTAMP.XXXXXXXX"
    )}"

    if [ -n "\${_WEBI_PARENT:-}" ]; then
        export _WEBI_CHILD=true
    else
        export _WEBI_CHILD=
    fi
    export _WEBI_PARENT=true

    my_os="\$(uname -s)"
    my_arch="\$(uname -m)"

    ##
    ## Detect acceptable package formats
    ##

    my_ext=""
    set +e
    # NOTE: the order here is least favorable to most favorable
    if [ -n "\$(command -v pkgutil)" ]; then
        my_ext="pkg,\$my_ext"
    fi
    # disable this check for the sake of building the macOS installer on Linux
    #if [ -n "\$(command -v diskutil)" ]; then
        # note: could also detect via hdiutil
        my_ext="dmg,\$my_ext"
    #fi
    if [ -n "\$(command -v git)" ]; then
        my_ext="git,\$my_ext"
    fi
    if [ -n "\$(command -v unxz)" ]; then
        my_ext="xz,\$my_ext"
    fi
    if [ -n "\$(command -v unzip)" ]; then
        my_ext="zip,\$my_ext"
    fi
    # for mac/linux 'exe' refers to the uncompressed binary without extension
    my_ext="exe,\$my_ext"
    if [ -n "\$(command -v tar)" ]; then
        my_ext="tar,\$my_ext"
    fi
    my_ext="\$(echo "\$my_ext" | sed 's/,$//')" # nix trailing comma
    set -e


    ##
    ## Detect http client
    ##

    set +e
    WEBI_CURL="\$(command -v curl)"
    export WEBI_URL
    WEBI_WGET="\$(command -v wget)"
    export WEBI_WGET
    set -e

    my_libc=''
    if ldd /bin/ls 2> /dev/null | grep -q 'musl' 2> /dev/null; then
        my_libc=' musl-native'
    fi

    export WEBI_HOST="\${WEBI_HOST:-https://webinstall.dev}"

    # ex: Darwin or Linux
    my_sys="\$(uname -s)"
    # ex: 22.6.0
    my_rev="\$(uname -r)"
    # ex: arm64
    my_machine="\$(uname -m)"

    export WEBI_UA="\${my_sys}/\${my_rev} \${my_machine}/unknown \${my_libc}"

    webinstall() {

        my_package="\${1:-}"
        if [ -z "\$my_package" ]; then
            echo >&2 "Usage: webi <package>@<version> ..."
            echo >&2 "Example: webi node@lts rg"
            exit 1
        fi

        WEBI_BOOT="\$(
            mktemp -d -t "\$my_package-bootstrap.\$WEBI_TIMESTAMP.XXXXXXXX"
        )"
        export WEBI_BOOT

        my_installer_url="\$WEBI_HOST/api/installers/\$my_package.sh?formats=\$my_ext"
        if [ -n "\$WEBI_CURL" ]; then
            if !  curl -fsSL "\$my_installer_url" -H "User-Agent: curl \$WEBI_UA" \\
                -o "\$WEBI_BOOT/\$my_package-bootstrap.sh"; then
                echo >&2 "error fetching '\$my_installer_url'"
                exit 1
            fi
        else
            if !  wget -q "\$my_installer_url" --user-agent="wget \$WEBI_UA" \\
                -O "\$WEBI_BOOT/\$my_package-bootstrap.sh"; then
                echo >&2 "error fetching '\$my_installer_url'"
                exit 1
            fi
        fi

        (
            cd "\$WEBI_BOOT"
            sh "\$my_package-bootstrap.sh"
        )

        rm -rf "\$WEBI_BOOT"

    }

    show_path_updates() {

        if test -z "\${_WEBI_CHILD}"; then
            if test -f "\$_webi_tmp/.PATH.env"; then
                my_paths=\$(sort -u < "\$_webi_tmp/.PATH.env")
                if test -n "\$my_paths"; then
                    printf 'PATH.env updated with:\\n'
                    printf "%s\\n" "\$my_paths"
                    printf '\\n'
                    printf "\\e[1m\\e[35mTO FINISH\\e[0m: copy, paste & run the following command:\\n"
                    printf "\\n"
                    printf "        \\e[1m\\e[32msource ~/.config/envman/PATH.env\\e[0m\\n"
                    printf "        (newly opened terminal windows will update automatically)\\n"
                fi
                rm -f "\$_webi_tmp/.PATH.env"
            fi
        fi

    }

    fn_checksum() {
        cmd_shasum='sha1sum'
        if command -v shasum > /dev/null; then
            cmd_shasum='shasum'
        fi
        \$cmd_shasum "\${0}" | cut -d' ' -f1 | cut -c 1-8
    }

    version() {
        my_checksum="\$(
            fn_checksum
        )"
        my_version=v1.2.0
        printf "\\e[35mwebi\\e[32m %s\\e[0m Copyright 2020+ AJ ONeal\\n" "\${my_version} (\${my_checksum})"
        printf "    \\e[36mhttps://webinstall.dev/webi\\e[0m\\n"
    }

    # show help if no params given or help flags are used
    usage() {
        echo ""
        version
        echo ""

        printf "\\e[1mSUMMARY\\e[0m\\n"
        echo "    Webi is the best way to install the modern developer tools you love."
        echo "    It's fast, easy-to-remember, and conflict free."
        echo ""
        printf "\\e[1mUSAGE\\e[0m\\n"
        echo "    webi <thing1>[@version] [thing2] ..."
        echo ""
        printf "\\e[1mUNINSTALL\\e[0m\\n"
        echo "    Almost everything that is installed with webi is scoped to"
        echo "    ~/.local/opt/<thing1>, so you can remove it like so:"
        echo ""
        echo "    rm -rf ~/.local/opt/<thing1>"
        echo "    rm -f ~/.local/bin/<thing1>"
        echo ""
        echo "    Some packages have special uninstall instructions, check"
        echo "    https://webinstall.dev/<thing1> to be sure."
        echo ""
        printf "\\e[1mOPTIONS\\e[0m\\n"
        echo "    Generic Program Information"
        echo "        --help Output a usage message and exit."
        echo ""
        echo "        -V, --version"
        echo "               Output the version number of webi and exit."
        echo ""
        echo "    Helper Utilities"
        echo "        --list Show everything webi has to offer."
        echo ""
        echo "        --info <package>"
        echo "               Show various links and example release."
        echo ""
        printf "\\e[1mFAQ\\e[0m\\n"
        printf "    See \\e[34mhttps://webinstall.dev/faq\\e[0m\\n"
        echo ""
        printf "\\e[1mALWAYS REMEMBER\\e[0m\\n"
        echo "    Friends don't let friends use brew for simple, modern tools that don't need it."
        echo "    (and certainly not apt either **shudder**)"
        echo ""
    }

    if [ \$# -eq 0 ] || echo "\$1" | grep -q -E '^(-V|--version|version)$'; then
        version
        exit 0
    fi

    if echo "\$1" | grep -q -E '^(-h|--help|help)$'; then
        usage "\$@"
        exit 0
    fi

    if echo "\$1" | grep -q -E '^(-l|--list|list)$'; then
        echo >&2 "[warn] the format of --list output may change"

        # because we don't have sitemap.xml for dev sites yet
        my_host="https://webinstall.dev"
        my_len="\${#my_host}"

        # 6 because the field will looks like "loc>WEBI_HOST/PKG_NAME"
        # and the count is 1-indexed
        my_count="\$((my_len + 6))"

        curl -fsS "\${my_host}/sitemap.xml" |
            grep -F "\${my_host}" |
            cut -d'<' -f2 |
            cut -c "\${my_count}"-

        exit 0
    fi

    if echo "\${1}" | grep -q -E '^(--info|info)$'; then
        if test -z "\${2}"; then
            echo >&2 "Usage: webi --info <package>"
            exit 1
        fi

        echo >&2 "[warn] the output of --info is completely half-baked and will change"
        my_pkg="\${2}"
        # TODO need a way to check that it exists at all (readme, win, lin)
        echo ""
        echo "    Cheat Sheet: \${WEBI_HOST}/\${my_pkg}"
        echo "          POSIX: curl -sS \${WEBI_HOST}/\${my_pkg} | sh"
        echo "        Windows: curl.exe -A MS \${WEBI_HOST}/\${my_pkg} | powershell"
        echo "Releases (JSON): \${WEBI_HOST}/api/releases/\${my_pkg}.json"
        echo " Releases (tsv): \${WEBI_HOST}/api/releases/\${my_pkg}.tab"
        echo " (query params):     ?channel=stable&limit=10"
        echo "                     &os=\${my_os}&arch=\${my_arch}"
        echo " Install Script: \${WEBI_HOST}/api/installers/\${my_pkg}.sh?formats=tar,zip,xz,git,dmg,pkg"
        echo "  Static Assets: \${WEBI_HOST}/packages/\${my_pkg}/README.md"
        echo ""

        # TODO os=linux,macos,windows (limit to tagged releases)
        my_releases="\$(
            curl -fsS "\${WEBI_HOST}/api/releases/\${my_pkg}.json?channel=stable&limit=1&pretty=true"
        )"

        if printf '%s\\n' "\${my_releases}" | grep -q "error"; then
            my_releases_beta="\$(
                curl -fsS "\${WEBI_HOST}/api/releases/\${my_pkg}.json?&limit=1&pretty=true"
            )"
            if printf '%s\\n' "\${my_releases_beta}" | grep -q "error"; then
                echo >&2 "'\${my_pkg}' is a special case that does not have releases"
            else
                echo >&2 "ERROR no stable releases for '\${my_pkg}'!"
            fi
            exit 0
        fi

        echo >&2 "Stable '\${my_pkg}' releases:"
        if command -v jq > /dev/null; then
            printf '%s\\n' "\${my_releases}" |
                jq
        else
            printf '%s\\n' "\${my_releases}"
        fi

        exit 0
    fi

    for pkgname in "\$@"; do
        webinstall "\$pkgname"
    done

    show_path_updates

}

__webi_main "\$@"

EOF

    chmod a+x "$HOME/.local/bin/webi"

    if [ -n "${WEBI_PKG-}" ]; then
        "$HOME/.local/bin/webi" "${WEBI_PKG}"
    else
        echo ""
        echo "Hmm... no WEBI_PKG was specified. This is probably an error in the script."
        echo ""
        echo "Please open an issue with this information: Package '${WEBI_PKG-}' on '$(uname -s)/$(uname -r) $(uname -m)'"
        echo "    https://github.com/webinstall/packages/issues"
        echo ""
    fi

}

__install_webi
