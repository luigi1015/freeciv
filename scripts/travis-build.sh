#!/bin/bash
#
# Freeciv Travis CI Bootstrap Script 
#
# https://travis-ci.org/freeciv/freeciv
echo "Building Freeciv on Travis CI."
basedir=$(pwd)
logfile="${basedir}/freeciv-travis.log"


# Redirect copy of output to a log file.
exec > >(tee ${logfile})
exec 2>&1
set -e

uname -a

case $1 in
"dist")
mkdir build
cd build
../autogen.sh \
 --disable-client \
 --disable-fcmp \
 --disable-ruledit \
 --disable-server \
 || (let config_exit_status=$? \
     && echo "Config exit status: $config_exit_status" \
     && cat config.log \
     && exit $config_exit_status)
make -s -j$(nproc) dist
echo "Freeciv distribution build successful!"
;;

"meson")
mkdir build
cd build
meson .. -Dprefix=${HOME}/freeciv/ -Dack_experimental=true -Dfcmp='gtk3','cli'
ninja
ninja install
;;

"os_x")
# gcc is an alias for clang on OS X

export PATH="/usr/local/opt/gettext/bin:/usr/local/opt/icu4c/bin:$(brew --prefix qt)/bin:$PATH"
export CPPFLAGS="-I/usr/local/opt/gettext/include -I/usr/local/opt/icu4c/include $CPPFLAGS"
export LDFLAGS="-L/usr/local/opt/gettext/lib -L/usr/local/opt/icu4c/lib"
export PKG_CONFIG_PATH="/usr/local/opt/icu4c/lib/pkgconfig:$PKG_CONFIG_PATH"

mkdir build
cd build
../autogen.sh \
 --enable-client=gtk3.22,sdl2,qt \
 --enable-freeciv-manual \
 || (let config_exit_status=$? \
     && echo "Config exit status: $config_exit_status" \
     && cat config.log \
     && exit $config_exit_status)
make -j$(nproc)
make install
;;

"clang_debug")
# Configure and build Freeciv
mkdir build
cd build
../autogen.sh \
 CC="clang" \
 CXX="clang++" \
 --enable-debug \
 --enable-sys-lua \
 --enable-sys-tolua-cmd \
 --disable-fcdb \
 --enable-client=gtk3.22,gtk3,qt,sdl2,stub \
 --enable-fcmp=cli,gtk3,qt \
 --enable-freeciv-manual \
 --enable-ai-static=classic,threaded,tex,stub \
 --prefix=${HOME}/freeciv/ \
 || (let config_exit_status=$? \
     && echo "Config exit status: $config_exit_status" \
     && cat config.log \
     && exit $config_exit_status)
make -s -j$(nproc)
sudo -u travis make install
;;

*)
# Fetch S3_0 in the background for the ruleset upgrade test
git fetch --no-tags --quiet https://github.com/freeciv/freeciv.git S3_0:S3_0 &

# Configure and build Freeciv
mkdir build
cd build
../autogen.sh \
 CFLAGS="-O3" \
 CXXFLAGS="-O3" \
 --enable-client=gtk3.22,gtk3,qt,sdl2,stub \
 --enable-fcmp=cli,gtk3,qt \
 --enable-freeciv-manual \
 --enable-ruledit=experimental \
 --enable-ai-static=classic,threaded,tex,stub \
 --enable-fcdb=sqlite3,mysql \
 --prefix=${HOME}/freeciv/ \
 || (let config_exit_status=$? \
     && echo "Config exit status: $config_exit_status" \
     && cat config.log \
     && exit $config_exit_status)
make -s -j$(nproc)
sudo -u travis make install
echo "Freeciv build successful!"

# Check that each ruleset loads
echo "Checking rulesets"
sudo -u travis ./tests/rulesets_not_broken.sh

# Check ruleset saving
echo "Checking ruleset saving"
sudo -u travis ./tests/rulesets_save.sh

# Check ruleset upgrade
echo "Ruleset upgrade"
echo "Preparing test data"
sudo -u travis ../tests/rs_test_res/upgrade_ruleset_sync.bash
echo "Checking ruleset upgrade"
FREECIV_DATA_PATH="../tests/rs_test_res/upgrade_rulesets:$FREECIV_DATA_PATH" \
 sudo --preserve-env=FREECIV_DATA_PATH -u travis \
 ./tests/rulesets_save.sh `cat ../tests/rs_test_res/upgrade_ruleset_list.txt`

echo "Running Freeciv server autogame"
cd ${HOME}/freeciv/bin/
sudo -u travis ./freeciv-server --Announce none -e --read ${basedir}/scripts/test-autogame.serv

echo "Freeciv server autogame successful!"
;;
esac
