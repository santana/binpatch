# $Id: bsd.binpatch.mk,v 1.1 2005/12/05 23:54:52 convexo Exp $
# Copyright (c) 2002-2005, Gerardo Santana Gómez Garrido <gerardo.santana@gmail.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author may not be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR `AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

# ================================================================ VARIABLES
# Architecture we are building on/for
ARCH=${MACHINE_ARCH}

# You'll need to copy your kernel configuration file into
# ${WRKDIR}/sys/arch/${ARCH}/conf/ if you want to compile it.
# Defaults to GENERIC kernel
KERNEL?=GENERIC

DISTNAME?=binpatch-${OSREV}
PKGNAME?=${DISTNAME}
FLAVOR_EXT:=-${ARCH}-${PATCH}
FULLPKGNAME?=${DISTNAME}${FLAVOR_EXT}

# The directory where the OpenBSD installation files
# and source are stored
DISTDIR?=${.CURDIR}/distfiles

# Where patches are stored
PATCHDIR?=${.CURDIR}/patches

# The OpenBSD installation files should be in a subdirectory.
# Defaults to $ARCH
DISTSUBDIR?=${ARCH}

# FETCH program
FETCH=ftp

# The OpenBSD Master Site
MASTER_SITE_OPENBSD?=ftp://ftp.openbsd.org/pub
MASTER_SITE_SUBDIR?=OpenBSD/patches/${OSREV}

# The working directories. All of them will be created, and removed.
WRKDIR?=${.CURDIR}/work-${DISTNAME}
WRKSRC?=${WRKDIR}/src
WRKOBJ?=${WRKDIR}/obj
WRKINST?=${WRKDIR}/fake
PACKAGEDIR?=${.CURDIR}/packages
PKGDIR?=${.CURDIR}/pkg

# Variables needed for making the sources (after patching)
DESTDIR:=${WRKINST}
BSDOBJDIR=${WRKOBJ}
BSDSRCDIR:=${WRKSRC}
MAKE_ENV:= env DESTDIR=${DESTDIR} BSDOBJDIR=${BSDOBJDIR} BSDSRCDIR=${BSDSRCDIR} INSTALL_COPY=-C

# ============================================== SPECIAL TARGETS & SHORTCUTS
# Subroutine to include for building a kernel patch
_kernel: .USE
	cd ${WRKSRC}/sys/arch/${ARCH}/conf && \
	config ./${KERNEL} && \
	cd ../compile/${KERNEL} && \
	${MAKE_ENV} make depend && \
	${MAKE_ENV} make && \
	cp -p bsd ${WRKINST}

# Shortcuts
_obj=${MAKE_ENV} make obj
_cleandir=${MAKE_ENV} make cleandir
_depend=${MAKE_ENV} make depend
_build=${MAKE_ENV} make && ${_install} 
_install=${MAKE_ENV} make install

_obj_wrp=${MAKE_ENV} make -f Makefile.bsd-wrapper obj
_cleandir_wrp=${MAKE_ENV} make -f Makefile.bsd-wrapper cleandir
_depend_wrp=${MAKE_ENV} make -f Makefile.bsd-wrapper depend
_build_wrp=${MAKE_ENV} make -f Makefile.bsd-wrapper && ${_install_wrp}
_install_wrp=${MAKE_ENV} make -f Makefile.bsd-wrapper install

# ================================================================== COOKIES
COOKIE:=${WRKDIR}/.cookie
INIT_COOKIE:=${WRKINST}/.init-done
EXTRACT_COOKIE:=${WRKDIR}/.extract-done

PATCH_FILES= 
PATCH_COOKIES=
BUILD_COOKIES=

# ============================================== PATCHING & BUILDING TARGETS
# Create targets and define variables only for our ${ARCH}
PATCH_LIST:=${PATCH_${ARCH:U}} ${PATCH_COMMON}

.for _patch in ${PATCH_LIST}

# _number holds the patch number, that's enough
# to identify a patch file
_number:=${_patch:C/_.*//}

dummy:=${PATCH_${ARCH:U}:M${_patch}*}
.if !empty(dummy)
_file  :=${ARCH}/${_patch}.patch
.else
_file :=common/${_patch}.patch
.endif

# List of patch files
PATCH_FILE_${_number}:= ${PATCHDIR}/${_file}
PATCH_FILES:= ${PATCH_FILES} ${PATCH_FILE_${_number}}

# Fetches the patch file
${PATCH_FILE_${_number}}:
	@echo ">> ${.TARGET:T} doesn't seem to exist on this system."
	@mkdir -p ${.TARGET:H}
	@cd  ${.TARGET:H} && \
	for site in ${MASTER_SITE_OPENBSD}; do \
	echo ">> Attempting to fetch ${.TARGET} from $${site}/${MASTER_SITE_SUBDIR}/"; \
	if ${FETCH} $${site}/${MASTER_SITE_SUBDIR}/${.TARGET:S@${PATCHDIR}/@@}; then \
		exit 0; \
	fi; \
	done; exit 1

PATCH_COOKIE_${_number}:=${WRKDIR}/.${_patch}-applied

# Patches the source tree
${PATCH_COOKIE_${_number}}: ${PATCH_FILE_${_number}}
	@cd  ${WRKSRC} && \
	patch -p0 < ${PATCH_FILE_${.TARGET:E:C/_.*//}}
	@touch -f ${.TARGET}

COOKIE_${_number}:=${WRKDIR}/.${_patch}-build-start

BUILD_COOKIE_${_number}:=${WRKDIR}/.${_patch}-built

# Builds the patch applied
${BUILD_COOKIE_${_number}}:
	@touch -f ${COOKIE_${.TARGET:E:C/_.*//}}
	@env PATCH="${PATCH}" ${MAKE_ENV} make ${.TARGET:E:C/-built//}
	@touch -f ${.TARGET}
.endfor

.for _p in ${PATCH}
PATCH_COOKIES	+= ${PATCH_COOKIE_${_p}}
BUILD_COOKIES	+= ${BUILD_COOKIE_${_p}}
.endfor

# ============================================================= MAIN TARGETS
# Extracts sources
extract: ${EXTRACT_COOKIE}

${EXTRACT_COOKIE}:
	@if [ ! -f ${DISTDIR}/src.tar.gz -o ! -f ${DISTDIR}/sys.tar.gz ]; then \
	echo "+------------------------";\
	echo "|"; \
	echo "| Error: download src.tar.gz and sys.tar.gz from an FTP server and"; \
	echo "| put them in ${DISTDIR}"; \
	echo "|"; \
	echo "+------------------------";\
	exit 1; \
	fi
	@echo "===>   Extracting sources"
	rm -rf ${WRKOBJ} ${WRKSRC}
	mkdir -p ${WRKOBJ}
	mkdir -p ${WRKSRC} && \
	tar xzpf ${DISTDIR}/src.tar.gz -C ${WRKSRC} && \
	tar xzpf ${DISTDIR}/sys.tar.gz -C ${WRKSRC} && \
	touch -f ${.TARGET}

# Extracts the OpenBSD installation files
init: ${INIT_COOKIE}

${INIT_COOKIE}:
	@echo "===>   Creating fake install tree"
	rm -rf ${WRKINST}
	mkdir -p ${WRKINST}
.for _pkg in base comp etc game man misc
	tar xzpf ${DISTDIR}/${ARCH}/${_pkg}${OSrev}.tgz -C ${WRKINST}
.endfor
	cp -p ${DISTDIR}/${ARCH}/bsd ${WRKINST} && \
	touch -f ${.TARGET}

# Applies patches
patch: extract ${PATCH_COOKIES}

# The cookie for detecting a change in the timestamp
${COOKIE}!
	@touch -f ${.TARGET}

# Builds the patch applied
build: init patch ${COOKIE} ${BUILD_COOKIES}

# Packages the modified files
plist: build
	@echo "===>   Finding changed binaries"
	@mkdir -p ${PKGDIR}
	@cd ${WRKINST} && \
	find . -newer ${COOKIE_${PATCH}} -a ! -newer ${BUILD_COOKIE_${PATCH}} -type f > ${PKGDIR}/PLIST${FLAVOR_EXT}

package: build
	@mkdir -p ${PACKAGEDIR}
	@echo "===>  Building package for ${FULLPKGNAME} in ${PACKAGEDIR}";
	@cat ${PKGDIR}/PLIST-${ARCH}-$${PATCH} | \
	(cd ${WRKINST} && xargs tar czpf ${PACKAGEDIR}/${FULLPKGNAME}.tgz) 
	@echo "+-------------------------"
	@echo "|"
	@echo "| The binary patch has been created in"
	@echo "| ${PACKAGEDIR}"
	@echo "|"
	@echo "| To install it run make install or:"
	@echo "|"
	@echo "| # cd ${PACKAGEDIR}"
	@echo "| # tar xzpf ${FULLPKGNAME}.tgz -C /"
	@echo "|"
	@echo "+-------------------------"

# Installs the binary patch
install:
	tar xzpf ${PACKAGEDIR}/${FULLPKGNAME}.tgz -C /

# Cleans the working directory
clean:
	@echo "===>  Cleaning working directory"
	rm -rf ${WRKDIR}

# Removes the directories and cookie created by extract
clean-extract:
	rm -rf ${WRKSRC} ${WRKOBJ} ${EXTRACT_COOKIE}

# Removes fake directory
clean-init:
	rm -rf ${WRKINST}

.if defined(show)
.MAIN: show
show:
.	for _s in ${show}
		@echo ${${_s}:Q}
.	endfor
.else
.MAIN: build
.endif

.include <bsd.own.mk>
