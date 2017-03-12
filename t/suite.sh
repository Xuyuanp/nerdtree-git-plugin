#!/bin/bash

VIM=vim

function colorecho() {
  echo -e "\x1b[$1m$2\x1b[m"
}

function getdependencies() {
  rm -rf nerdtree
  git clone --depth 1 https://github.com/scrooloose/nerdtree.git
}

function test() {
  local OK
  basenametest=$1
  title="$(grep '^"""[^"]' $basenametest.vim | sed 's/^"""\s*//')"
  expect=$(grep '^\s*""""' $basenametest.vim | sed 's/^""""\s*//')
  for skp in $SKIP_TESTS
  do
    if [ "$basenametest" == "$skp" ]
    then
      expect="skip"
      break
    fi
  done

  if [ "$expect" == "skip" ]
  then
    echo $(colorecho 34 ${basenametest}) "${title}" $(colorecho 33 skip)
    continue
  fi

  tempdir=$(mktemp -d "${basenametest}.XXX")

  cd $tempdir
  bash ../${basenametest}.sh &> /dev/null
  if [ "$SILENT" == 0 ]
  then
    $VIM -N -e -s -u NONE -S ../helper.vim -S ../$basenametest.vim -c 'quitall!' 2> /dev/null
  else
    $VIM -N -u NONE -S ../helper.vim -S ../$basenametest.vim -c 'quitall!'
  fi

  cd ..
  DIFFOUTPUT="$(diff -u ${basenametest}.ok ${basenametest}.out)"
  OK=$?
  if [ "$OK" == 0 ]
  then
    if [ "$expect" == "failed" ]
    then
      echo $(colorecho 34 ${basenametest}) "${title}" $(colorecho 31 "not failed")
      echo "$DIFFOUTPUT"
      OK=1
    else
      echo $(colorecho 34 ${basenametest}) "${title}" $(colorecho 32 ok)
      if [ "$CLEAN" == 0 ]
      then
        rm ${basenametest}.out
        rm -rf $tempdir
      fi
    fi
  else
    if [ "$expect" == "failed" ]
    then
      echo $(colorecho 34 ${basenametest}) "${title}" $(colorecho 32 "failed correctly")
      if [ "$CLEAN" == 0 ]
      then
        rm ${basenametest}.out
        rm -rf $tempdir
      fi
      OK=0
    else
      echo $(colorecho 34 ${basenametest}) "${title}" $(colorecho 31 ko)
      echo "$DIFFOUTPUT"
    fi
  fi
  if [ "$SHOWDIFF" == 0 ]
  then
      echo "$DIFFOUTPUT"
  fi

  return $OK
}

function testsuite() {
  OK=0

  getdependencies

  SILENT=0
  CLEAN=0
  SHOWDIFF=0

  for testcase in test*.vim
  do
    basenametest=$(basename $testcase .vim)
    test $basenametest
    if [ $? == 1 ]
    then
      OK=1
    fi
  done

  echo

  if [ $OK != 0 ]
  then
    echo some test failed
  else
    echo test suite passed correctly
  fi

  exit $OK
}

if [ "$#" == 0 ]
then
  testsuite
else
  SILENT=1
  CLEAN=1
  SHOWDIFF=1
  test $@
  exit $?
fi
