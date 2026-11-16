#!/bin/sh
# 执行一次：sh setup-codex-env.sh
# 只安装环境变量加载配置；仅依赖系统自带的 shell 和文本工具。
set -eu
umask 077

if [ "${1:-}" = "--help" ]; then
    printf '%s\n' \
        '用法：sh setup-codex-env.sh' \
        '运行一次后，新终端和 Zsh 命令会话即可自动读取 Codex 配置。' \
        '支持 zsh、bash；其他 shell 配置到 ~/.profile。' \
        '配置缺少地址或密钥时跳过加载；CODEX_ENV_STRICT=1 可启用诊断。' \
        '可选：CODEX_ENV_INSTALL_DIR、CODEX_ENV_STARTUP_DIR、CODEX_ENV_CONFIG。'
    exit 0
fi
if [ "$#" -ne 0 ]; then
    printf '%s\n' '参数不正确；使用 --help 查看用法。' >&2
    exit 2
fi

_ce_install="${CODEX_ENV_INSTALL_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/codex-env}"
mkdir -p "$_ce_install"
_ce_install=$(CDPATH= cd "$_ce_install" && pwd -P)
_ce_loader="$_ce_install/env.sh"
_ce_loader_tmp=$(mktemp "$_ce_install/.env.XXXXXX")
_ce_rc_tmp=
trap 'rm -f "$_ce_loader_tmp"; if [ -n "$_ce_rc_tmp" ]; then rm -f "$_ce_rc_tmp"; fi' 0
trap 'exit 1' 1 2 3 15

cat > "$_ce_loader_tmp" <<'CODEX_ENV_LOADER'
#!/bin/sh
# 用 . /路径/codex-env.sh 加载；Zsh 会从 ~/.zshenv 自动加载。
# 仅依赖 sh 和 awk；读取 config.toml 当前 provider 的地址与密钥。
# 支持常见的单行 TOML 字符串，以及 env_key 引用的已导出环境变量。
# 不解析 auth.json、复杂 TOML 或 ChatGPT 登录令牌。
# 启动时按需加载；缺少配置时保留已有环境变量，不阻断 Shell。
# 手动诊断：CODEX_ENV_STRICT=1 sh ~/.config/codex-env/env.sh

_codex_env_file="${CODEX_ENV_CONFIG:-${CODEX_HOME:-$HOME/.codex}/config.toml}"

if [ ! -r "$_codex_env_file" ]; then
    unset _codex_env_file
    if [ "${CODEX_ENV_STRICT:-0}" = "1" ]; then
        printf '%s\n' 'codex-env: 配置文件不存在或不可读。' >&2
        return 1 2>/dev/null || exit 1
    fi
    return 0 2>/dev/null || exit 0
fi

if _codex_env_data=$(awk -v strict="${CODEX_ENV_STRICT:-0}" '
function trim(s) {
    sub(/^[[:space:]]+/, "", s)
    sub(/[[:space:]]+$/, "", s)
    return s
}
function die(message) {
    failed = 1
    if (strict == "1") print "codex-env: " message > "/dev/stderr"
    exit 1
}
function string_value(s, quote, result, i, c, rest) {
    s = trim(s)
    quote = substr(s, 1, 1)
    if (quote != "\"" && quote != sprintf("%c", 39))
        die("所需配置项必须是单行引号字符串。")
    result = ""
    for (i = 2; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == quote) {
            rest = trim(substr(s, i + 1))
            if (rest != "" && substr(rest, 1, 1) != "#")
                die("所需配置项不是支持的单行字符串。")
            return result
        }
        if (c == "\\" && quote == "\"") {
            c = substr(s, ++i, 1)
            if (c != "\\" && c != "\"")
                die("所需配置项包含不支持的 TOML 转义。")
        }
        result = result c
    }
    die("所需配置项的引号不完整。")
}
BEGIN { section = "@root"; active = "openai" }
{
    line = trim($0)
    if (line == "" || substr(line, 1, 1) == "#") next
    if (substr(line, 1, 1) == "[") {
        section = "@other"
        if (line ~ /^\[[[:space:]]*model_providers\./) {
            name = line
            sub(/^\[[[:space:]]*model_providers\.[[:space:]]*/, "", name)
            sub(/\][[:space:]]*(#.*)?$/, "", name)
            name = trim(name)
            if (name ~ /^[A-Za-z0-9_-]+$/) section = name
            else if (name ~ /^"[^".]+"$/ || name ~ /^\047[^\047.]+\047$/)
                section = string_value(name)
        }
        next
    }
    if (line !~ /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/) next
    field = line
    sub(/[[:space:]]*=.*/, "", field)
    value = line
    sub(/^[^=]*=[[:space:]]*/, "", value)
    if (section == "@root" && field == "model_provider") active = string_value(value)
    if (section == "@root" && field == "openai_base_url") openai_url = value
    if (section == "@root" || section == "@other") next
    if (field == "base_url") urls[section] = value
    if (field == "experimental_bearer_token") tokens[section] = value
    if (field == "env_key") env_keys[section] = value
}
END {
    if (failed) exit 1
    if (active in urls) base = string_value(urls[active])
    else if (active == "openai") {
        if (openai_url != "") base = string_value(openai_url)
        else if (ENVIRON["OPENAI_BASE_URL"] != "") base = ENVIRON["OPENAI_BASE_URL"]
        else base = "https://api.openai.com/v1"
    }
    else die("当前 provider 没有配置 base_url。")

    if (active in env_keys) {
        variable = string_value(env_keys[active])
        if (variable !~ /^[A-Za-z_][A-Za-z0-9_]*$/)
            die("env_key 不是有效的环境变量名称。")
        key = ENVIRON[variable]
    } else if (active in tokens) key = string_value(tokens[active])
    else if (active == "openai") key = ENVIRON["OPENAI_API_KEY"]
    else die("当前 provider 没有配置 experimental_bearer_token 或 env_key。")

    if (base == "" || key == "") die("地址或密钥为空，请检查配置及环境变量。")
    if (base ~ /[[:cntrl:]]/ || key ~ /[[:cntrl:]]/)
        die("地址或密钥不能包含换行等控制字符。")
    print base
    print key
}
' "$_codex_env_file"); then
    # 按行读取数据，不执行配置内容。
    {
        IFS= read -r _codex_env_base_url
        IFS= read -r _codex_env_api_key
    } <<EOF
$_codex_env_data
EOF
    export OPENAI_BASE_URL="$_codex_env_base_url"
    export OPENAI_API_KEY="$_codex_env_api_key"
    unset _codex_env_file _codex_env_data _codex_env_base_url _codex_env_api_key
else
    unset _codex_env_file _codex_env_data _codex_env_base_url _codex_env_api_key
    if [ "${CODEX_ENV_STRICT:-0}" = "1" ]; then
        return 1 2>/dev/null || exit 1
    fi
    return 0 2>/dev/null || exit 0
fi
CODEX_ENV_LOADER

# 验证成功后再写入启动文件；不显示密钥，也不调用网络。
( . "$_ce_loader_tmp" )
chmod 600 "$_ce_loader_tmp"
mv -f "$_ce_loader_tmp" "$_ce_loader"

# 将安装路径转换成安全的 shell 单引号字符串。
_ce_quoted=$(printf '%s\n' "$_ce_loader" | awk '
BEGIN { q = sprintf("%c", 39) }
{
    if (NR > 1) exit 1
    out = q
    for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (c == q) out = out q "\\" q q
        else out = out c
    }
    print out q
}')

case "${SHELL:-/bin/zsh}" in
    */zsh)
        _ce_startup="${CODEX_ENV_STARTUP_DIR:-${ZDOTDIR:-$HOME}}"
        # 非交互命令会话（包括 Codex）也需要加载环境变量。
        set -- "$_ce_startup/.zshenv" "$_ce_startup/.zshrc" "$_ce_startup/.zprofile"
        ;;
    */bash)
        _ce_startup="${CODEX_ENV_STARTUP_DIR:-$HOME}"
        # bash 登录时读取第一个存在的启动文件。
        _ce_login="$_ce_startup/.bash_profile"
        if [ ! -f "$_ce_login" ] && [ ! -L "$_ce_login" ]; then
            if [ -f "$_ce_startup/.bash_login" ]; then
                _ce_login="$_ce_startup/.bash_login"
            elif [ -f "$_ce_startup/.profile" ]; then
                _ce_login="$_ce_startup/.profile"
            fi
        fi
        set -- "$_ce_startup/.bashrc" "$_ce_login"
        ;;
    *)
        _ce_startup="${CODEX_ENV_STARTUP_DIR:-$HOME}"
        set -- "$_ce_startup/.profile"
        ;;
esac
mkdir -p "$_ce_startup"

for _ce_rc do
    _ce_rc_tmp=$(mktemp "$_ce_startup/.codex-env-rc.XXXXXX")
    if [ -e "$_ce_rc" ] || [ -L "$_ce_rc" ]; then
        awk '
        $0 == "# >>> codex-env >>>" {
            if (inside) { bad = 1; exit 1 }
            inside = 1
            next
        }
        $0 == "# <<< codex-env <<<" {
            if (!inside) { bad = 1; exit 1 }
            inside = 0
            next
        }
        !inside { print }
        END {
            if (inside || bad) {
                print "codex-env: 启动文件中存在不完整的配置区块。" > "/dev/stderr"
                exit 1
            }
        }' "$_ce_rc" > "$_ce_rc_tmp"
    fi
    cat >> "$_ce_rc_tmp" <<EOF
# >>> codex-env >>>
if [ -r $_ce_quoted ]; then
    . $_ce_quoted
fi
# <<< codex-env <<<
EOF
    if [ -f "$_ce_rc" ] && cmp -s "$_ce_rc" "$_ce_rc_tmp"; then
        rm -f "$_ce_rc_tmp"
        _ce_rc_tmp=
        continue
    fi
    if [ -e "$_ce_rc" ] || [ -L "$_ce_rc" ]; then
        _ce_backup=$(mktemp "${_ce_rc}.codex-env-backup.XXXXXX")
        cp -p "$_ce_rc" "$_ce_backup"
    fi
    # 原位写入，保留已有文件权限和符号链接。
    cat "$_ce_rc_tmp" > "$_ce_rc"
    rm -f "$_ce_rc_tmp"
    _ce_rc_tmp=
    printf '已配置：%s\n' "$_ce_rc"
done

printf '\n%s\n' \
    '安装完成。新会话会在配置完整时设置 OPENAI_BASE_URL 和 OPENAI_API_KEY。' \
    '缺少配置时会跳过加载并保留已有环境变量；CODEX_ENV_STRICT=1 可启用诊断。'
