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
#include <QSocketNotifier>
#include <QMessageBox>
#include <QSlider>
#include <QComboBox>
#include <QPushButton>
#include <QCheckBox>
#include <QColor>

#include <stdint.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <termios.h>

#include "dialog.h"
#include "clrbox.h"
#include "sliderbox.h"

#define HUE_MIN		0
#define HUE_MAX		1541
#define SAT_MIN		0
#define SAT_MAX		255
#define VAL_MIN		0
#define VAL_MAX		255
#define CLR_R_MIN	0
#define CLR_R_MAX	255
#define CLR_G_MIN	0
#define CLR_G_MAX	255
#define CLR_B_MIN	0
#define CLR_B_MAX	255
#define SPD_MIN		0
#define SPD_MAX		255

enum {
	MODE_OFF = 0,
	MODE_RAMPAGE,
	MODE_STEP,
	MODE_RANDOM,
	MODE_WHEEL,
	MODE_FIXED,
	MODE_SERIAL
};

#define CMD_SETMODE_ENABLE	0x20
#define CMD_SETDIR_ENABLE	0x40
#define	CMD_ACTIVATE		0x40
#define CMD_SWAP		0xc0	/*   2  11000000 0-hsvrgb	Swap active and shadow values */
#define	CMD_SETMODE		0xc1	/*   3  11000001 0DMd-mmm	Set running mode/direction */
#define CMD_SETSPEED		0xc2	/*   4  1100001d 0ddddddd	Set running delay/speed */
#define	CMD_SETCLRR		0x88	/*   6  1a001--r 0rrrrrrr	Set Red */
#define	CMD_SETCLRG		0x90	/*   7  1a010--g 0ggggggg	Set Green */
#define	CMD_SETCLRB		0x98	/*   8  1a011--b 0bbbbbbb	Set Blue */
#define	CMD_SETHUE		0xa0	/*   9  1a10hhhh 0hhhhhhh	Set Hue */
#define	CMD_SETSAT		0xb0	/*  10  1a110--s 0sssssss	Set Saturation */
#define	CMD_SETVAL		0xb8	/*  11  1a111--v 0vvvvvvv	Set Value */

Dialog::Dialog()
{
	setMinimumWidth(400);

	QDialogButtonBox *buttonBox = new QDialogButtonBox(QDialogButtonBox::Close);
	connect(buttonBox, SIGNAL(rejected()), this, SLOT(reject()));

	QGridLayout *lo = new QGridLayout();

	QHBoxLayout *hbox = new QHBoxLayout();
	hbox->addWidget(new QLabel("Serial Port"));
	QPushButton *b;
	hbox->addWidget(b = new QPushButton("Refresh"));
	connect(b, SIGNAL(clicked(bool)), this, SLOT(enumports(bool)));
	port = new QComboBox();
	port->setEditable(false);
	connect(port, SIGNAL(currentIndexChanged(int)), this, SLOT(setport(int)));
	hbox->addWidget(port);

	list = new QComboBox();
	list->setEditable(false);
	list->addItem("Off", MODE_OFF);
	list->addItem("Rampage", MODE_RAMPAGE);
	list->addItem("Step", MODE_STEP);
	list->addItem("Random", MODE_RANDOM);
	list->addItem("Wheel", MODE_WHEEL);
	list->addItem("Fixed", MODE_FIXED);
	list->addItem("Serial", MODE_SERIAL);
	list->setCurrentIndex(MODE_SERIAL);
	connect(list, SIGNAL(currentIndexChanged(int)), this, SLOT(setmode(int)));
	lo->addWidget(new QLabel("Running mode"), 0, 0);
	lo->addWidget(list, 0, 1);

	hue = new sliderbox(HUE_MIN, HUE_MAX, 32, 0);
	lo->addWidget(new QLabel("Hue"), 1, 0);
	lo->addLayout(hue, 1, 1);
	connect(hue, SIGNAL(valueChanged(int)), this, SLOT(sethue(int)));

	sat = new sliderbox(SAT_MIN, SAT_MAX, 16, SAT_MAX);
	lo->addWidget(new QLabel("Saturation"), 2, 0);
	lo->addLayout(sat, 2, 1);
	connect(sat, SIGNAL(valueChanged(int)), this, SLOT(setsat(int)));

	val = new sliderbox(VAL_MIN, VAL_MAX, 16, VAL_MAX);
	lo->addWidget(new QLabel("Value"), 3, 0);
	lo->addLayout(val, 3, 1);
	connect(val, SIGNAL(valueChanged(int)), this, SLOT(setval(int)));

	clr_r = new sliderbox(CLR_R_MIN, CLR_R_MAX, 16, 0x33);
	lo->addWidget(new QLabel("Red"), 4, 0);
	lo->addLayout(clr_r, 4, 1);
	connect(clr_r, SIGNAL(valueChanged(int)), this, SLOT(setclr_r(int)));

	clr_g = new sliderbox(CLR_G_MIN, CLR_G_MAX, 16, CLR_G_MAX);
	lo->addWidget(new QLabel("Green"), 5, 0);
	lo->addLayout(clr_g, 5, 1);
	connect(clr_g, SIGNAL(valueChanged(int)), this, SLOT(setclr_g(int)));

	clr_b = new sliderbox(CLR_B_MIN, CLR_B_MAX, 16, CLR_B_MIN);
	lo->addWidget(new QLabel("Blue"), 6, 0);
	lo->addLayout(clr_b, 6, 1);
	connect(clr_b, SIGNAL(valueChanged(int)), this, SLOT(setclr_b(int)));

	spd = new sliderbox(SPD_MIN, SPD_MAX, 16, SPD_MAX/2);
	lo->addWidget(new QLabel("Speed"), 7, 0);
	lo->addLayout(spd, 7, 1);
	connect(spd, SIGNAL(valueChanged(int)), this, SLOT(setspd(int)));

	dir = new QCheckBox();
	lo->addWidget(new QLabel("Direction"), 8, 0);
	lo->addWidget(dir, 8, 1);
	connect(dir, SIGNAL(stateChanged(int)), this, SLOT(setdir(int)));

	QHBoxLayout *cbox = new QHBoxLayout();
	clrv = new clrbox();
	cbox->addWidget(clrv);
	clre = new QLineEdit();
	clre->setReadOnly(true);
	clre->setFocusPolicy(Qt::ClickFocus);
	cbox->addWidget(clre);
	cbox->setStretch(0, 2);
	cbox->setStretch(1, 1);
	lo->addWidget(new QLabel("Color"), 9, 0);
	lo->addLayout(cbox, 9, 1);

	QVBoxLayout *mainLayout = new QVBoxLayout();
	mainLayout->addLayout(hbox);
	mainLayout->addLayout(lo);
	mainLayout->addWidget(buttonBox);
	setLayout(mainLayout);

	setWindowTitle("OSAA Ikea-sign - Color Control");

	enumports(true);
	setactive();

	list->setFocus();

	lastcmd = -1;
	lastdata = -1;

	serfd = -1;
}

void Dialog::setactive(void)
{
	int mode = list->currentIndex();
	switch(mode) {
	default:
	case MODE_OFF:
		hue->hide();
		sat->hide();
		val->hide();
		clr_r->hide();
		clr_g->hide();
		clr_b->hide();
		spd->hide();
		dir->setEnabled(false);
		break;
	case MODE_RAMPAGE:
	case MODE_STEP:
		hue->hide();
		sat->hide();
		val->hide();
		clr_r->hide();
		clr_g->hide();
		clr_b->hide();
		spd->show();		setspd(spd->value());
		dir->setEnabled(true);	setdir(dir->checkState());
		break;
	case MODE_RANDOM:
		hue->hide();
		sat->hide();
		val->hide();
		clr_r->hide();
		clr_g->hide();
		clr_b->hide();
		spd->show();		setspd(spd->value());
		dir->setEnabled(false);
		break;
	case MODE_WHEEL:
		hue->hide();
		sat->show();		setsat(sat->value());
		val->show();		setval(val->value());
		clr_r->hide();
		clr_g->hide();
		clr_b->hide();
		spd->show();		setspd(spd->value());
		dir->setEnabled(true);	setdir(dir->checkState());
		break;
	case MODE_FIXED:
		hue->show();		sethue(hue->value());
		sat->show();		setsat(sat->value());
		val->show();		setval(val->value());
		clr_r->hide();
		clr_g->hide();
		clr_b->hide();
		spd->hide();
		dir->setEnabled(false);
		break;
	case MODE_SERIAL:
		hue->show();		sethue(hue->value());
		sat->show();		setsat(sat->value());
		val->show();		setval(val->value());
		clr_r->show();		setclr_r(clr_r->value());
		clr_g->show();		setclr_g(clr_g->value());
		clr_b->show();		setclr_b(clr_b->value());
		spd->hide();
		dir->setEnabled(false);
		break;
	}
}

void Dialog::sendcmd(int cmd, int data)
{
	if(lastcmd == cmd) {
		if(data == lastdata)
			return;
		//printf("Sendcmd 0 0x%02x\n", data);
		if(-1 != serfd) {
			char ch = data;
			ssize_t err = ::write(serfd, &ch, 1);
			if(err != 1)
				printf("write error data (errno=%d)\n", errno);
		}
	} else
		//printf("Sendcmd 1 0x%02x, 0x%02x\n", cmd, data);
		if(-1 != serfd) {
			char chs[2];
			chs[0] = cmd;
			chs[1] = data;
			ssize_t err = ::write(serfd, chs, 2);
			if(err != 2)
				printf("write error cmd+data (errno=%d)\n", errno);
		}
	lastcmd = cmd;
	lastdata = data;
}

void Dialog::updatecolor(const QColor &c)
{
	clrv->setcolor(c);
	clre->setText(QString("#%1%2%3").arg((int)c.red(), 2, 16, QChar('0')).arg((int)c.green(), 2, 16, QChar('0')).arg((int)c.blue(), 2, 16, QChar('0')));
}

void Dialog::updatergb(void)
{
	updatecolor(QColor(clr_r->value(), clr_g->value(), clr_b->value()));
}

void Dialog::updatehsv(void)
{
	QColor c;
	c.setHsvF((float)hue->value()/(float)HUE_MAX, (float)sat->value()/(float)SAT_MAX, (float)val->value()/(float)VAL_MAX);
	updatecolor(c);
}

void Dialog::setmode(int v)
{
	sendcmd(CMD_SETMODE, CMD_SETMODE_ENABLE | (v & 0x07));
	setactive();
}

void Dialog::sethue(int v)
{
	updatehsv();
	sendcmd(CMD_SETHUE | CMD_ACTIVATE | ((v >> 7) & 0x0f), v & 0x7f);
}

void Dialog::setsat(int v)
{
	updatehsv();
	sendcmd(CMD_SETSAT | CMD_ACTIVATE | ((v >> 7) & 0x01), v & 0x7f);
}

void Dialog::setval(int v)
{
	updatehsv();
	sendcmd(CMD_SETVAL | CMD_ACTIVATE | ((v >> 7) & 0x01), v & 0x7f);
}

void Dialog::setclr_r(int v)
{
	updatergb();
	sendcmd(CMD_SETCLRR | CMD_ACTIVATE | ((v >> 7) & 0x01), v & 0x7f);
}

void Dialog::setclr_g(int v)
{
	updatergb();
	sendcmd(CMD_SETCLRG | CMD_ACTIVATE | ((v >> 7) & 0x01), v & 0x7f);
}

void Dialog::setclr_b(int v)
{
	updatergb();
	sendcmd(CMD_SETCLRB | CMD_ACTIVATE | ((v >> 7) & 0x01), v & 0x7f);
}

void Dialog::setspd(int v)
{
	sendcmd(CMD_SETSPEED | CMD_ACTIVATE | ((v >> 7) & 0x01), v & 0x7f);
}

void Dialog::setdir(int v)
{
	sendcmd(CMD_SETMODE, CMD_SETDIR_ENABLE | (v == Qt::Checked ? 0x10 : 0x00));
}

void Dialog::setport(int v)
{
	struct termios tio;

	if(-1 != serfd) {
		::close(serfd);
		serfd = -1;
	}

	if(!port->itemData(v).isNull()) {
		QString portname = port->itemData(v).toString();
		if(-1 == (serfd = ::open(portname.toLocal8Bit(), O_RDWR|O_NOCTTY))) {
			/* Oops, device no longer available? */
			QMessageBox::warning(this, "Serial port open", QString("Serial port ")+portname+" cannot be opened. Maybe it was unplugged?\nYou may need to refresh the serial port list and try again.");
			return;
		}
		if(-1 == tcgetattr(serfd, &tio)) {
			QMessageBox::warning(this, "Serial port open", QString("Serial port ")+portname+QString(" cannot be read (errno=%1)"".\nYou may need to refresh the serial port list and try again.").arg(errno));
			::close(serfd);
			serfd = -1;
			return;
		}
		cfmakeraw(&tio);
		cfsetspeed(&tio, B1200);
		tio.c_cflag &= ~CRTSCTS;
		tio.c_cflag |= CLOCAL;
		if(-1 == tcsetattr(serfd, TCSANOW, &tio)) {
			QMessageBox::warning(this, "Serial port open", QString("Serial port ")+portname+QString(" cannot be configured (errno=%1)"".\nYou may need to refresh the serial port list and try again.").arg(errno));
			::close(serfd);
			serfd = -1;
			return;
		}
		setmode(list->currentIndex());
	}
}

void Dialog::enumports(bool)
{
	QString path("/dev/serial/by-id/");
	QDir d(path);
	port->clear();
	port->addItem("", QString());
	if(d.exists()) {
		QStringList sl = d.entryList(QDir::NoDotAndDotDot | QDir::Files);
		for(int i = 0; i < sl.size(); i++) {
			char devpath[PATH_MAX];
			char *cptr;
			ssize_t len;
			if(-1 == (len = ::readlink((path + sl.at(i)).toLocal8Bit(), devpath, sizeof(devpath))))
				continue;
			devpath[sizeof(devpath)-1] = 0;
			if(len < (ssize_t)sizeof(devpath))
				devpath[len] = 0;
			if(!(cptr = strrchr(devpath, '/')))
				cptr = devpath;
			else
				cptr++;
			port->addItem(cptr, path + devpath);
		}
	}
}

