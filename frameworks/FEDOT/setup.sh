#!/usr/bin/env bash
HERE=$(dirname "$0")
VERSION=${1:-"stable"}
REPO=${2:-"https://github.com/aimclub/FEDOT.git"}
PKG=${3:-"fedot"}
CONDA_ENV="amlb"  # Название conda окружения

if [[ "$VERSION" == "latest" ]]; then
    VERSION="master"
fi

# Активация conda окружения
source /opt/conda/etc/profile.d/conda.sh
conda activate ${CONDA_ENV}

# Настройка SSL для git и pip
export GIT_SSL_NO_VERIFY=0
export PIP_CERT=/etc/ssl/certs/ca-certificates.crt
git config --global http.sslVerify true

# Создание целевой директории
TARGET_DIR="${HERE}/lib/${PKG}"
mkdir -p ${TARGET_DIR}

# Функция для безопасной установки через pip
safe_pip_install() {
    pip install \
        --trusted-host pypi.org \
        --trusted-host files.pythonhosted.org \
        --cert ${PIP_CERT} \
        --no-cache-dir \
        "$@"
}

if [[ "$VERSION" == "stable" ]]; then
    safe_pip_install -U ${PKG}
    echo GET_VERSION_STABLE
    VERSION=$(python -c "${GET_VERSION_STABLE}")
elif [[ "$VERSION" =~ ^[0-9] ]]; then
    safe_pip_install -U ${PKG}==${VERSION}
else
    rm -Rf ${TARGET_DIR}

    if [[ "$VERSION" =~ ^# ]]; then
        COMMIT="${VERSION:1}"
    else
        # Поиск последнего коммита в ветке
        COMMIT=$(git ls-remote "${REPO}" | grep "refs/heads/${VERSION}" | cut -f 1)
        DEPTH="--depth 1 --branch ${VERSION}"
    fi

    # Клонирование с проверкой SSL
    GIT_SSL_NO_VERIFY=0 git clone \
        --recurse-submodules \
        --shallow-submodules \
        ${DEPTH} \
        ${REPO} \
        ${TARGET_DIR}
    
    cd ${TARGET_DIR}
    git checkout "${COMMIT}"
    GIT_SSL_NO_VERIFY=0 git submodule update --init --recursive
    cd ${HERE}
    
    safe_pip_install -U -e ${TARGET_DIR}
fi

# Запись информации об установке
installed="${HERE}/.setup/installed"
python -c "from fedot import __version__; print(__version__)" >> "$installed"
if [[ -n $COMMIT ]]; then
    truncate -s-1 "$installed"
    echo "#${COMMIT}" >> "$installed"
fi
