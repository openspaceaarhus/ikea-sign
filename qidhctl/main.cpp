/*
 * Ikea DIODER hack serial control
 * Copyright (C) 2011  B. Stultiens
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
#include <QApplication>
#include <QIcon>
#include <QPixmap>

#include "dialog.h"

#include "osaa_skilt_20.xpm"

int main(int argc, char *argv[])
{
	QApplication app(argc, argv);

	app.setWindowIcon(QIcon(QPixmap(osaa_skilt_20_xpm)));

	Dialog dialog;
	return dialog.exec();
}

