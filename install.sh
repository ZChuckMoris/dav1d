#!/bin/bash

function usage()
{
   cat << HEREDOC

   Usage: $0 [--version VERSION]

   optional arguments:

     -h, --help         Show this help message and exit

     -v, --version      Specify dav1d version to be downloaded and compiled. 
                        Supported versions: 0.5.2, 0.8.2, 0.9.2 and 0.9.3-git-6aaeeea6. 
                        By default is using version 0.9.3-git-6aaeeea6.


HEREDOC
}

## Print help if no args passed
# if [ "$#" -eq 0 ]; then
#     usage >&2
#     exit 1
# fi

dav1dversion="0.9.3-git-6aaeeea6"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) usage; exit ;;
        -v|--version) dav1dversion="$2"; shift ;;
        *) echo "Unknown parameter passed: $1" ;;
    esac
    shift
done

mkdir av1
cd av1

if [[ $(arch) == "i386" || $(arch) =~ x86.* || $(arch) == "amd64" || $(arch) =~ arm.* || $(arch) == "aarch64" ]]; then
    declare -a compileversions=("" "-O3" "-O4" "-asm" "-asm-O3")
else
    declare -a compileversions=("" "-O3" "-O4")
fi

for compileversion in "${compileversions[@]}"; do
    git clone --recursive https://code.videolan.org/videolan/dav1d dav1d-$dav1dversion$compileversion
    cd dav1d-$dav1dversion$compileversion
    if [[ $dav1dversion = "0.5.2" ]]; then
        git reset --hard 39667c751d427e447cbe8be783cfecd296659e24
    elif [[ $dav1dversion = "0.8.2" ]]; then
        git reset --hard f06148e7c755098666b9c0ed97a672a51785413a
    elif [[ $dav1dversion = "0.9.2" ]]; then
        git reset --hard 7b433e077298d0f4faf8da6d6eb5774e29bffa54
    elif [[ $dav1dversion = "0.9.3-git-6aaeeea6" ]]; then
        git reset --hard 6aaeeea6896ce30d387e7660553844eaa79f35c5
    fi

    cd ../

    if [[ $compileversion =~ .*-asm.* ]]; then
        sed -E -e ':a' -e 'N' -e '$!ba' -e "s/([[:space:]]*option\('enable_asm',\n[[:space:]]*type: 'boolean',\n[[:space:]]*value:) false/\1 true/g" -i.backup ./dav1d-$dav1dversion$compileversion/meson_options.txt
    else
        sed -E -e ':a' -e 'N' -e '$!ba' -e "s/([[:space:]]*option\('enable_asm',\n[[:space:]]*type: 'boolean',\n[[:space:]]*value:) true/\1 false/g" -i.backup ./dav1d-$dav1dversion$compileversion/meson_options.txt
    fi

    if [[ $compileversion =~ .*-O4.* ]] && [[ $(arch) != "e2k" ]]; then
        sed -E "s/'-ffast-math'/'-ffast-math'\n    optional_arguments += '-O4'/" -i.backup ./dav1d-$dav1dversion$compileversion/meson.build
    fi

    if [[ $(arch) == "e2k" ]]; then 
        if [[ $compileversion =~ .*-O3.* ]]; then
            sed -E "s/'-ffast-math'/'-ffast-math'\n    optional_arguments += '-O3'\n    optional_arguments += '-fwhole'\n    optional_arguments += '-ffast'/" -i.backup ./dav1d-$dav1dversion$compileversion/meson.build
        elif [[ $compileversion =~ .*-O4.* ]]; then
            sed -E "s/'-ffast-math'/'-ffast-math'\n    optional_arguments += '-O4'\n    optional_arguments += '-fwhole'\n    optional_arguments += '-ffast'/" -i.backup ./dav1d-$dav1dversion$compileversion/meson.build
        fi
    fi


    buildfolder="dav1d-$dav1dversion$compileversion/build"
    mkdir $buildfolder

    # if [[ $(ps -p $$ | awk '{print $4}' | tail -n 1) =~ .*zsh ]]; then
    if [[ $(sh -c 'ps -p $$ -o ppid=' | xargs ps -o comm= -p) =~ .*zsh ]]; then
        setopt rmstarsilent
    fi

    rm -rf $buildfolder/*
    rm -rf $buildfolder/.*

    # if [[ $(ps -p $$ | awk '{print $4}' | tail -n 1) =~ .*zsh ]]; then
    if [[ $(sh -c 'ps -p $$ -o ppid=' | xargs ps -o comm= -p) =~ .*zsh ]]; then
        unsetopt rmstarsilent
    fi

    cd $buildfolder

    if [[ $compileversion =~ ".*-O3.*" || $compileversion =~ ".*-O4.*" ]]; then
        meson .. --optimization=3
    else
        meson ..
    fi

    ninja
    cd ../../

    if [[ $(arch) =~ x86.* || $(arch) == "i386" ]]; then
        echo "arch = $(arch)"
    else
        mkdir x86_64
        cd x86_64
        if [[ $OSTYPE =~ ^darwin.* ]]; then
            OS="mac"
        elif [[ $OSTYPE =~ ^linux.* ]]; then
            OS="linux"
        fi
        wget https://github.com/ZChuckMoris/dav1d/releases/download/$dav1dversion/dav1d-$OS-x86_64-$dav1dversion$compileversion.tar.gz
        tar -xzf dav1d-$OS-x86_64-$dav1dversion$compileversion.tar.gz
        cd ../
    fi
done

for av1video in "Chimera/Chimera-2397fps-AV1-10bit-1920x1080-3365kbps.obu" "Chimera/Old/Chimera-AV1-8bit-1920x1080-6736kbps.ivf" "Chimera/Old/Chimera-AV1-10bit-1920x1080-6191kbps.ivf"; do
    if [[ ! -f $(basename $av1video) ]]; then
        wget http://download.opencontent.netflix.com.s3.amazonaws.com/AV1/$av1video
    fi
done
