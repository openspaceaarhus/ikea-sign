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
#ifndef __QIDHCTL_SLIDERBOX_H
#define __QIDHCTL_SLIDERBOX_H

#include <QHBoxLayout>

class QSlider;
class QLineEdit;

class sliderbox : public QHBoxLayout
{
	Q_OBJECT

public:
	sliderbox(int mini, int maxi, int step, int pos);

	int value(void);
	void hide(void);
	void show(void);

protected:
	
private:
	QSlider		*slider;
	QLineEdit	*editp;
	QLineEdit	*editv;

signals:
	void valueChanged(int v);

public slots:
	void valuechanged(int v);
};

#endif
