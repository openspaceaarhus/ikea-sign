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
#include <QSlider>
#include <QLineEdit>

#include "sliderbox.h"

sliderbox::sliderbox(int mini, int maxi, int step, int pos)
{
	slider = new QSlider(Qt::Horizontal);
	slider->setRange(mini, maxi);
	slider->setSingleStep(1);
	slider->setPageStep(step);
	slider->setSliderPosition(pos);
	addWidget(slider);
	connect(slider, SIGNAL(valueChanged(int)), this, SLOT(valuechanged(int)));

	editp = new QLineEdit();
	editp->setReadOnly(true);
	editp->setFocusPolicy(Qt::ClickFocus);
	editp->setAlignment(Qt::AlignRight);
	addWidget(editp);

	editv = new QLineEdit();
	editv->setReadOnly(true);
	editv->setFocusPolicy(Qt::ClickFocus);
	editv->setAlignment(Qt::AlignRight);
	addWidget(editv);
	setStretch(0, 10);
	setStretch(1, 3);
	setStretch(2, 2);
	valuechanged(pos);
}

int sliderbox::value(void)
{
	return slider->value();
}

void sliderbox::valuechanged(int v)
{
	editp->setText(QString("%1%").arg((double)v/(double)slider->maximum()*100.0, 3, 'f', 1));
	editv->setText(QString("%1").arg(v));
	emit valueChanged(v);
}

void sliderbox::hide(void)
{
	slider->hide();
	editp->hide();
	editv->hide();
}

void sliderbox::show(void)
{
	slider->show();
	editp->show();
	editv->show();
}
