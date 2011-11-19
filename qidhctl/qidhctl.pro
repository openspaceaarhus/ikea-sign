#
# Ikea DIODER hack serial control
# Copyright (C) 2011  B. Stultiens
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
HEADERS = dialog.h \
	sliderbox.h \
	clrbox.h \
	osaa_skilt_20.xpm

SOURCES = dialog.cpp \
	sliderbox.cpp \
	clrbox.cpp \
	main.cpp

# install
target.path = .
sources.files = $$SOURCES $$HEADERS *.pro
sources.path = .
INSTALLS += target sources

