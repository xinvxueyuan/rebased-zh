#!/usr/bin/env bash
# 从 Rebased 官方发行包生成匹配当前版本的简体中文语言包 (localization-zh.jar)
#
# 原理：Rebased 基于 IntelliJ 平台，官方中文语言包插件 (id: com.intellij.zh)
#       只是为某个 build 号打包的 UI 翻译资源。本脚本把通用语言包源
#       (localization-zh-source.jar) 的 META-INF/plugin.xml 里的
#       <version>/<idea-version> 改写成目标 Rebased 的 build 号，
#       从而绕过兼容性校验，使其能在对应 Rebased 版本中加载。
#
# 用法:
#   bash make-zh-pack.sh --version <ver> --tar <rebased.tar.gz>
#   bash make-zh-pack.sh --version <ver> --url <rebased.tar.gz 下载地址>
#
# 输出: assets/<ver>/localization-zh.jar
set -euo pipefail

SOURCE_JAR_URL="${SOURCE_JAR_URL:-https://raw.githubusercontent.com/duanluan/aur-packages/main/packages/rebased-zh-bin/assets/localization-zh-source.jar}"

VERSION=""; URL=""; TAR=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --version) VERSION="${2:-}"; shift 2 ;;
    --url)     URL="${2:-}"; shift 2 ;;
    --tar)     TAR="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 1 ;;
  esac
done
[ -n "$VERSION" ] || { echo "缺少 --version" >&2; exit 1; }
[ -n "$URL" ] || [ -n "$TAR" ] || { echo "需要 --url 或 --tar" >&2; exit 1; }
for c in curl tar find head perl zip unzip jq; do
  command -v "$c" >/dev/null 2>&1 || { echo "缺少依赖: $c" >&2; exit 1; }
done

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# 1. 取回 Rebased 发行包 (仅解出 build.txt / product-info.json)
if [ -n "$TAR" ]; then
  cp "$TAR" "$work/rebased.tar.gz"
else
  curl -fL --retry 5 --retry-delay 2 --retry-all-errors -o "$work/rebased.tar.gz" "$URL"
fi
tar -xzf "$work/rebased.tar.gz" -C "$work" --wildcards --no-wildcards-match-slash '*/build.txt' '*/product-info.json'
build_txt="$(find "$work" -maxdepth 2 -name build.txt -not -path '*/plugins/*' | head -n1)"
[ -n "$build_txt" ] || { echo "未在发行包中找到 build.txt" >&2; exit 1; }

# 2. 解析 build 号（优先用 product-info.json）
product_info="$(dirname "$build_txt")/product-info.json"
raw_build="$(tr -d '[:space:]' < "$build_txt")"
raw_build="${raw_build%\%*}"
product_code=""; build_number=""
if [ -f "$product_info" ]; then
  product_code="$(jq -r '.productCode // empty' "$product_info" 2>/dev/null || true)"
  build_number="$(jq -r '.buildNumber // empty' "$product_info" 2>/dev/null || true)"
fi
if [ -z "$build_number" ]; then
  case "$raw_build" in
    *-*) product_code="${raw_build%%-*}"; build_number="${raw_build#*-}" ;;
    *)   build_number="$raw_build" ;;
  esac
fi
[ -n "$build_number" ] || { echo "无法解析 build 号" >&2; exit 1; }

compat="$(printf '%s\n' "$build_number" | awk -F. 'NF>=3{print $1"."$2"."$3; next}{print}')"
branch="${compat%%.*}"
if [ "$product_code" = "AI" ]; then since="${product_code}-${compat}"; else since="$compat"; fi
if [ -n "$product_code" ]; then plugin_version="${product_code}-${compat}"; else plugin_version="$compat"; fi
until_build="${branch}.*"

echo "Rebased 版本  : $VERSION"
echo "build         : $build_number  (productCode=${product_code:-<none>})"
echo "plugin version: $plugin_version  since=$since  until=$until_build"

# 3. 取回通用语言包源并解压
curl -fL --retry 5 --retry-delay 2 --retry-all-errors -o "$work/src.jar" "$SOURCE_JAR_URL"
mkdir -p "$work/plugin"
( cd "$work/plugin" && unzip -oq "$work/src.jar" )
xml="$work/plugin/META-INF/plugin.xml"
[ -f "$xml" ] || { echo "源语言包缺少 META-INF/plugin.xml" >&2; exit 1; }

# 4. 改写 plugin.xml 的版本兼容信息
TARGET_VERSION="$plugin_version" TARGET_SINCE="$since" TARGET_UNTIL="$until_build" \
perl -0pi -e '
  s{<version>.*?</version>}{<version>$ENV{TARGET_VERSION}</version>}s;
  s{<idea-version\b[^>]*/>}{<idea-version since-build="$ENV{TARGET_SINCE}" until-build="$ENV{TARGET_UNTIL}" />}s;
  s{<description\b[^>]*>.*?</description>}{<description></description>}s;
' "$xml"

# 5. 以确定性方式重新打包（固定时间戳与顺序）
out="assets/${VERSION}"
mkdir -p "$out"
find "$work/plugin" -type d -exec chmod 755 {} +
find "$work/plugin" -type f -exec chmod 644 {} +
TZ=UTC find "$work/plugin" -exec touch -h -t 200001010000.00 {} +
( cd "$work/plugin"
  find . -type f -print | sed 's#^\./##' | LC_ALL=C sort > "$work/list"
  TZ=UTC zip -q -X "$work/out.zip" -@ < "$work/list" )
mv "$work/out.zip" "$out/localization-zh.jar"

echo "生成: $out/localization-zh.jar"
sha256sum "$out/localization-zh.jar"