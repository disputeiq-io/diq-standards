#!/usr/bin/env sh
set -eu

if [ -d "${HOME}/.jdks/temurin-21/bin" ]; then
  export JAVA_HOME="${HOME}/.jdks/temurin-21"
  export PATH="${JAVA_HOME}/bin:${PATH}"
fi

CACHED_MVN="${HOME}/.m2/wrapper/dists/apache-maven-3.9.5-bin/2adeog8mj13csp1uusqnc1f2mo/apache-maven-3.9.5/bin/mvn"
if [ -x "${CACHED_MVN}" ]; then
  exec "${CACHED_MVN}" "$@"
fi

if command -v mvn >/dev/null 2>&1; then
  exec mvn "$@"
fi

echo "ERROR: Neither cached Maven 3.9.5 nor 'mvn' on PATH was found." >&2
exit 1
