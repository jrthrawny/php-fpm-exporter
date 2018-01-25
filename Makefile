# Makefile for a standard repo with associated container

##### These variables need to be adjusted in most repositories #####

# This repo's root import path (under GOPATH).
PKG := github.com/bakins/php-fpm-exporter

# Upstream repo used in the Dockerfile
# UPSTREAM_REPO ?= full/upstream-docker-repo

# Top-level directories to build
SRC_DIRS := cmd pkg

# Version variables to replace in build, The variable VERSION is automatically pulled from git committish so it doesn't have to be added
# These are replaced in the $(PKG).version package.
# VERSION_VARIABLES = ThisCmdVersion ThatContainerVersion

# These variables will be used as the defaults unless overridden by the make command line
#ThisCmdVersion ?= $(VERSION)
#ThatContainerVersion ?= drud/nginx-php-fpm7-local

# Optional to docker build
# DOCKER_ARGS =

# VERSION can be set by
  # Default: git tag
  # make command line: make VERSION=0.9.0
# It can also be explicitly set in the Makefile as commented out below.

# This version-strategy uses git tags to set the version string
# VERSION can be overridden on make commandline: make VERSION=0.9.1 push
VERSION := $(shell git describe --tags --always --dirty)
#
# This version-strategy uses a manual value to set the version string
#VERSION := 1.2.3

TESTRUN_DOCKERIMAGE_PREFIX :=

# Docker repo for a push
DOCKER_REPO ?= jrthrawny/$(TESTRUN_DOCKERIMAGE_PREFIX)php-fpm-exporter

# Each section of the Makefile is included from standard components below.
# If you need to override one, import its contents below and comment out the
# include. That way the base components can easily be updated as our general needs
# change.
include build-tools/makefile_components/base_build_go.mak
#include build-tools/makefile_components/base_build_python-docker.mak
include build-tools/makefile_components/base_container.mak
include build-tools/makefile_components/base_push.mak
include build-tools/makefile_components/base_test_go.mak
#include build-tools/makefile_components/base_test_python.mak


# Additional targets can be added here
# Also, existing targets can be overridden by copying and customizing them.

HAS_GLIDE := $(shell command -v glide;)

# This is an adaptation of the make target in kubernetes/helm for dealing with dependencies.
# Source: https://github.com/kubernetes/helm/blob/master/Makefile#L126-L144https://github.com/kubernetes/helm/blob/46598952ea8b2c624ea102c5cb467033eb63c39f/Makefile#L126-L142
deps:
ifndef HAS_GLIDE
	echo "You must have glide installed to make deps: https://github.com/masterminds/glide#install"
	exit 1
endif
	glide install --strip-vendor
	go build -o bin/protoc-gen-go ./vendor/github.com/golang/protobuf/protoc-gen-go
	rm -rf ./vendor/k8s.io/{kube-aggregator,apiserver,apimachinery,client-go,metrics}
	cp -r ./vendor/k8s.io/kubernetes/staging/src/k8s.io/{kube-aggregator,apiserver,apimachinery,client-go,metrics} ./vendor/k8s.io


TESTOS = $(BUILD_OS)

test:
	@mkdir -p bin/linux
	@mkdir -p $(GOTMP)/{src/$(PKG),pkg,bin,std/linux}
	@echo "Testing $(SRC_AND_UNDER) with TESTARGS=$(TESTARGS)"
	docker run -t --rm  -u $(shell id -u):$(shell id -g)                 \
	    -v $(PWD)/$(GOTMP):/go$(DOCKERMOUNTFLAG)                                                 \
	    -v $(PWD)/:/go/src/$(PKG)$(DOCKERMOUNTFLAG) 				\
		-v $(PWD)/../charts:/go/src/$(PKG)/../charts$(DOCKERMOUNTFLAG)                                     \
	    -v $(PWD)/bin/linux:/go/bin$(DOCKERMOUNTFLAG)                                     \
	    -v $(PWD)/$(GOTMP)/std/linux:/usr/local/go/pkg/linux_amd64_static$(DOCKERMOUNTFLAG)  \
	    -e CGO_ENABLED=0	\
	    -w /go/src/$(PKG)                                                  \
	    $(BUILD_IMAGE)                                                     \
        go test -v -installsuffix static -ldflags '$(LDFLAGS)' $(SRC_AND_UNDER) $(TESTARGS)
