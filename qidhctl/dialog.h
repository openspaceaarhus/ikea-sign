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
#ifndef __QIDHCTL_DIALOG_H
#define __QIDHCTL_DIALOG_H

#include <QDialog>

class clrbox;
class sliderbox;
class QSocketNotifier;
class QComboBox;
class QCheckBox;
class QLineEdit;

class Dialog : public QDialog
{
	Q_OBJECT

public:
	Dialog();

private:
	sliderbox	*hue;
	sliderbox	*sat;
	sliderbox	*val;
	sliderbox	*clr_r;
	sliderbox	*clr_g;
	sliderbox	*clr_b;
	sliderbox	*spd;

	QCheckBox	*dir;

	QComboBox	*list;
	QComboBox	*port;

	clrbox		*clrv;
	QLineEdit	*clre;

	int	lastcmd;
	int	lastdata;

	int	serfd;

	void setactive(void);
	void sendcmd(int cmd, int data);
	void updatergb(void);
	void updatehsv(void);
	void updatecolor(const QColor &c);

public slots:
	void setport(int v);
	void enumports(bool chkd);

	void setmode(int v);
	void sethue(int v);
	void setsat(int v);
	void setval(int v);
	void setclr_r(int v);
	void setclr_g(int v);
	void setclr_b(int v);
	void setspd(int v);
	void setdir(int v);
};

#endif
