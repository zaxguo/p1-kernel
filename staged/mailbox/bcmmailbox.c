//
// bcmmailbox.c
//
// USPi - An USB driver for Raspberry Pi written in C
// Copyright (C) 2014-2016  R. Stange <rsta2@o2online.de>
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
// 
#include "utils.h"
#include "bcmmailbox.h"

#define DataSyncBarrier()	__asm volatile ("dsb" ::: "memory")
#define DataMemBarrier() 	__asm volatile ("dmb" ::: "memory")

#define ARM_IO_BASE			0x3F000000		// xzl
#define MAILBOX_BASE		(ARM_IO_BASE + 0xB880)
#define MAILBOX0_READ  		(MAILBOX_BASE + 0x00)
#define MAILBOX0_STATUS 	(MAILBOX_BASE + 0x18)
	#define MAILBOX_STATUS_EMPTY	0x40000000
#define MAILBOX1_WRITE		(MAILBOX_BASE + 0x20)
#define MAILBOX1_STATUS 	(MAILBOX_BASE + 0x38)
	#define MAILBOX_STATUS_FULL	0x80000000
// chan ids	
#define MAILBOX_CHANNEL_PM	0			// power management
#define MAILBOX_CHANNEL_FB 	1			// frame buffer
#define BCM_MAILBOX_PROP_OUT	8			// property tags (ARM to VC)  


void BcmMailBoxFlush (TBcmMailBox *pThis);
unsigned BcmMailBoxRead (TBcmMailBox *pThis);
void BcmMailBoxWrite (TBcmMailBox *pThis, unsigned nData);

void BcmMailBox (TBcmMailBox *pThis, unsigned nChannel) {
	assert (pThis != 0);
	pThis->m_nChannel = nChannel;
}

void _BcmMailBox (TBcmMailBox *pThis) { // xzl: dctor?
	assert (pThis != 0);
}

// xzl: write and then read back  nData: pa 
unsigned BcmMailBoxWriteRead (TBcmMailBox *pThis, unsigned nData) {
	assert (pThis != 0);
	DataMemBarrier ();
	BcmMailBoxFlush (pThis);
	BcmMailBoxWrite (pThis, nData);
	unsigned nResult = BcmMailBoxRead (pThis);
	DataMemBarrier ();
	return nResult;
}

// busywait until mailbox idle 
void BcmMailBoxFlush (TBcmMailBox *pThis) {
	assert (pThis != 0);
	while (!(get32va (MAILBOX0_STATUS) & MAILBOX_STATUS_EMPTY)) {
		get32va (MAILBOX0_READ);
		ms_delay (20);
	}
}

// keep reading until get response for cur channel
unsigned BcmMailBoxRead (TBcmMailBox *pThis) {
	assert (pThis != 0);
	unsigned nResult;
	do {
		while (get32va (MAILBOX0_STATUS) & MAILBOX_STATUS_EMPTY)
			; 		
		nResult = get32va (MAILBOX0_READ);
	} while ((nResult & 0xF) != pThis->m_nChannel);		// channel number is in the lower 4 bits
	return nResult & ~0xF;
}

void BcmMailBoxWrite (TBcmMailBox *pThis, unsigned nData) {
	assert (pThis != 0);
	while (get32va (MAILBOX1_STATUS) & MAILBOX_STATUS_FULL)
		; 
	assert ((nData & 0xF) == 0);
	put32va (MAILBOX1_WRITE, pThis->m_nChannel | nData);	// channel number is in the lower 4 bits
}