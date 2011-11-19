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
#include <QtGui>

#include "clrbox.h"

clrbox::clrbox()
{
	setMinimumWidth(200);
	color.setRgb(128, 128, 128);
}


void clrbox::paintEvent(QPaintEvent *e)
{
	QPainter p(this);
	p.setBrush(QBrush(color));
	p.drawRect(e->rect());
}

void clrbox::setcolor(const QColor &clr)
{
	color = clr;
	update();
}

