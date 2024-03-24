//
// uspibind.cpp
//
// USPi - An USB driver for Raspberry Pi written in C
// Copyright (C) 2014  R. Stange <rsta2@o2online.de>
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
// xzl: the glue layer... which we should implement one ourselves...
#include <uspios.h>

void MsDelay (unsigned nMilliSeconds) {
	ms_delay(nMilliSeconds);
}

void usDelay (unsigned nMicroSeconds) {
	us_delay(nMicroSeconds);
}

// xzl: delay is in ticks (100Hz), as expected by usb driver 
unsigned StartKernelTimer (unsigned nDelay, TKernelTimerHandler *pHandler, 
	void *pParam, void *pContext) {
	int t = ktimer_start(nDelay * 10 /*ms*/, pHandler, pParam, pContext); 
	if (t < 0)
		return 0; 
	else 
		return (unsigned)(t+1); // usb driver expects >0 timer handle
}

void CancelKernelTimer (unsigned hTimer) {
	BUG_ON(hTimer == 0); 
	int ret = ktimer_cancel(hTimer-1); 
	WARN_ON(ret < 0);
}

// irq.c
extern TInterruptHandler *usb_irq; 
extern void *usb_irq_param; 

void ConnectInterrupt (unsigned nIRQ, TInterruptHandler *pHandler, void *pParam)
{
	BUG_ON(nIRQ != 9); // only for USB
	usb_irq = pHandler; 
	usb_irq_param = pParam; 
}

int SetPowerStateOn (unsigned nDeviceId)
{
	TBcmPropertyTags Tags;
	BcmPropertyTags (&Tags);
	TPropertyTagPowerState PowerState;
	PowerState.nDeviceId = nDeviceId;
	PowerState.nState = POWER_STATE_ON | POWER_STATE_WAIT;
	if (   !BcmPropertyTagsGetTag (&Tags, PROPTAG_SET_POWER_STATE, &PowerState, sizeof PowerState, 8)
	    ||  (PowerState.nState & POWER_STATE_NO_DEVICE)
	    || !(PowerState.nState & POWER_STATE_ON))
	{
		_BcmPropertyTags (&Tags);

		return 0;
	}
	
	_BcmPropertyTags (&Tags);

	return 1;
}

int GetMACAddress (unsigned char Buffer[6])
{
	TBcmPropertyTags Tags;
	BcmPropertyTags (&Tags);
	TPropertyTagMACAddress MACAddress;
	if (!BcmPropertyTagsGetTag (&Tags, PROPTAG_GET_MAC_ADDRESS, &MACAddress, sizeof MACAddress, 0))
	{
		_BcmPropertyTags (&Tags);

		return 0;
	}

	memcpy (Buffer, MACAddress.Address, 6);
	
	_BcmPropertyTags (&Tags);

	return 1;
}

void LogWrite (const char *pSource, unsigned Severity, const char *pMessage, ...)
{
	va_list var;
	va_start (var, pMessage);

	LoggerWriteV (LoggerGet (), pSource, (TLogSeverity) Severity, pMessage, var);

	va_end (var);
}

#ifndef NDEBUG
void uspi_assertion_failed (const char *pExpr, const char *pFile, unsigned nLine)
{
	assertion_failed (pExpr, pFile, nLine);
}

void DebugHexdump (const void *pBuffer, unsigned nBufLen, const char *pSource)
{
	debug_hexdump (pBuffer, nBufLen, pSource);
}
#endif
