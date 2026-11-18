#!/usr/bin/env sh
set -eu

if [ -d "${HOME}/.jdks/temurin-21/bin" ]; then
  export JAVA_HOME="${HOME}/.jdks/temurin-21"
  export PATH="${JAVA_HOME}/bin:${PATH}"
fi

LOCAL_GRADLE="${HOME}/.gradle/gradle-8.10.2/bin/gradle"
if [ -x "${LOCAL_GRADLE}" ]; then
  exec "${LOCAL_GRADLE}" "$@"
fi

if command -v gradle >/dev/null 2>&1; then
  exec gradle "$@"
fi

echo "ERROR: Neither local Gradle 8.10.2 nor 'gradle' on PATH was found." >&2
exit 1
