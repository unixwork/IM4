IM4
===

IM4 is a native XMPP client for macOS that supports end-to-end encryption via OTR. The development
is at an early stage, but some basic functionality works.

Already implemented:
 - Simple contact list with online status
 - Chat window
 - Encryption (OTR)
 - Basic configuration GUI

Not implemented yet:
 - Subscription management
 - Custom status
 - File transfer

Some features that will probably never be implemented:
 - Group chat
 - Audio/Video call


BUILDING
--------

IM4 depends on *libstrophe* and *libotr*, which, in turn, depend on *OpenSSL* and *libgcrypt*. To build all dependencies,
run the `build_dependencies.sh` script from the project root directory. If *homebrew* is installed, it es recommended to
temporarily rename `/opt/homebrew`.

After the dependencies are built successfully, IM4 can be built with Xcode.

There are two configurations available:
- *IM4:* This is the debug build that stores its settings in `~/Library/Application Support/IM4TEST`.
- *IM4 Release:* This configuration stores its settings in `~/Library/Application Support/IM4`.



LICENSE
-------

Copyright 2024 Olaf Wintermann All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

  1. Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.

  2. Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
