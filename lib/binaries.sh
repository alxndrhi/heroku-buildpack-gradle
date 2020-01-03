install_node_npm() {
  if [ -f "frontend/package.json" ]; then
    local node_engine=$(read_json "frontend/package.json" ".engines.node")
    local npm_engine=$(read_json "frontend/package.json" ".engines.npm")

    echo "engines.node (package.json):  ${node_engine:-unspecified}"
    echo "engines.npm (package.json):   ${npm_engine:-unspecified (use default)}"

    node_dir=$CACHE_DIR/node
    if [ ! -d $node_dir ]; then
      mkdir -p $node_dir
    fi
    install_nodejs "$node_engine" "$node_dir"
    PATH=$PATH:$node_dir/bin
    install_npm "$npm_engine"
    export npm_run=$node_dir/bin/npm
  fi
}

install_nodejs() {
  local version="$1"
  local dir="$2"

  if needs_resolution "$version"; then
    echo "Resolving node version ${version:-(latest stable)} via semver.io..."
    local version=$(curl --silent --get --retry 5 --retry-max-time 15 --data-urlencode "range=${version}" https://semver.herokuapp.com/node/resolve)
  fi

  echo "Downloading and installing node $version..."
  local download_url="https://s3pository.heroku.com/node/v$version/node-v$version-$os-$cpu.tar.gz"
  local code=$(curl "$download_url" --silent --fail --retry 5 --retry-max-time 15 -o /tmp/node.tar.gz --write-out "%{http_code}")
  if [ "$code" != "200" ]; then
    echo "Unable to download node $version; does it exist?" && false
  fi
  tar xzf /tmp/node.tar.gz -C /tmp
  rm -rf $dir/*
  mv /tmp/node-v$version-$os-$cpu/* $dir
  chmod +x $dir/bin/*
}

install_npm() {
  local version="$1"

  if [ "$version" == "" ]; then
    echo "Using default npm version: `npm --version`"
  else
    if needs_resolution "$version"; then
      echo "Resolving npm version ${version} via semver.io..."
      version=$(curl --silent --get --retry 5 --retry-max-time 15 --data-urlencode "range=${version}" https://semver.herokuapp.com/npm/resolve)
    fi
    if [[ `npm --version` == "$version" ]]; then
      echo "npm `npm --version` already installed with node"
    else
      echo "Downloading and installing npm $version (replacing version `npm --version`)..."
      npm install --unsafe-perm --quiet -g npm@$version 2>&1 >/dev/null
    fi
  fi
}
