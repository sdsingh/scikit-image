#!/usr/bin/env bash
set -ex

PY=$TRAVIS_PYTHON_VERSION

section "Test.with.min.requirements"
nosetests $TEST_ARGS skimage
section_end "Test.with.min.requirements"

section "Build.docs"
if [[ ($PY != 2.6) && ($PY != 3.2) ]]; then
    export SPHINXCACHE=$HOME/.cache/sphinx; make html
fi
section_end "Build.docs"

section "Flake8.test"
flake8 --exit-zero --exclude=test_*,six.py skimage doc/examples viewer_examples
section_end "Flake8.test"


section "Install.optional.dependencies"

# Install most of the optional packages
if [[ $PY != 3.2* ]]; then
    pip install --retries 3 -q -r ./optional_requirements.txt $WHEELHOUSE
fi

# Install Qt and then update the Matplotlib settings
if [[ $PY == 2.7* ]]; then
    # http://stackoverflow.com/a/9716100
    LIBS=( PyQt4 sip.so )

    VAR=( $(which -a python$PY) )

    GET_PYTHON_LIB_CMD="from distutils.sysconfig import get_python_lib; print (get_python_lib())"
    LIB_VIRTUALENV_PATH=$(python -c "$GET_PYTHON_LIB_CMD")
    LIB_SYSTEM_PATH=$(${VAR[-1]} -c "$GET_PYTHON_LIB_CMD")

    for LIB in ${LIBS[@]}
    do
        ln -sf $LIB_SYSTEM_PATH/$LIB $LIB_VIRTUALENV_PATH/$LIB
    done

elif [[ $PY != 3.2* ]]; then
    python ~/venv/bin/pyside_postinstall.py -install
fi

if [[ $PY == 2.* ]]; then
    pip install --retries 3 -q pyamg
fi

# Show what's installed
pip list

section_end "Install.optional.dependencies"


section "Run.doc.examples"

# Matplotlib settings - do not show figures during doc examples
if [[ $PY == 2.7* ]]; then
    MPL_DIR=$HOME/.matplotlib
else
    MPL_DIR=$HOME/.config/matplotlib
fi

mkdir -p $MPL_DIR
touch $MPL_DIR/matplotlibrc
echo 'backend : Template' > $MPL_DIR/matplotlibrc


for f in doc/examples/*/*.py; do
    python "$f"
    if [ $? -ne 0 ]; then
        exit 1
    fi
done

section_end "Run.doc.examples"


section "Run.doc.applications"

for f in doc/examples/xx_applications/*.py; do
    python "$f"
    if [ $? -ne 0 ]; then
        exit 1
    fi
done

# Now configure Matplotlib to use Qt4
if [[ $PY == 2.7* ]]; then
    MPL_QT_API=PyQt4
    export QT_API=pyqt
else
    MPL_QT_API=PySide
    export QT_API=pyside
fi
echo 'backend: Qt4Agg' > $MPL_DIR/matplotlibrc
echo 'backend.qt4 : '$MPL_QT_API >> $MPL_DIR/matplotlibrc

section_end "Run.doc.applications"


section "Test.with.optional.dependencies"

# run tests again with optional dependencies to get more coverage
if [[ $PY == 3.3 ]]; then
    TEST_ARGS="$TEST_ARGS --with-cov --cover-package skimage"
fi
nosetests $TEST_ARGS

section_end "Test.with.optional.dependencies"

section "Prepare.release"
doc/release/contribs.py HEAD~10
section_end "Prepare.release"
