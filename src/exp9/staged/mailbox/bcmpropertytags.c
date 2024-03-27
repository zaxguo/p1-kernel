//
// bcmpropertytags.c
//
// USPi - An USB driver for Raspberry Pi written in C
// Copyright (C) 2014-2017  R. Stange <rsta2@o2online.de>
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
#include "bcmpropertytags.h"
#include <uspienv/util.h>
#include <uspienv/synchronize.h>
#include <uspienv/bcm2835.h>
#include <uspienv/sysconfig.h>
#include <uspienv/assert.h>

typedef struct TPropertyBuffer {
	u32	nBufferSize;			// bytes
	u32	nCode;
	#define CODE_REQUEST		0x00000000
	#define CODE_RESPONSE_SUCCESS	0x80000000
	#define CODE_RESPONSE_FAILURE	0x80000001
	u8	Tags[0];
	// end tag follows
} TPropertyBuffer;

void BcmPropertyTags (TBcmPropertyTags *pThis) {
	assert (pThis != 0);
	BcmMailBox (&pThis->m_MailBox, BCM_MAILBOX_PROP_OUT);
}

void _BcmPropertyTags (TBcmPropertyTags *pThis) { // dtor, nop
	assert (pThis != 0);
	_BcmMailBox (&pThis->m_MailBox);
}

// write a command & read a response		(one tag)
//     nRequestParmSize: req val size (needed?)
boolean BcmPropertyTagsGetTag (TBcmPropertyTags *pThis, u32 nTagId,
			       void *pTag, unsigned nTagSize, unsigned  nRequestParmSize) {
	assert (pThis != 0 && pTag != 0 && nTagSize >= sizeof (TPropertyTagSimple));

	// need buffer size: metadata (TPropertyBuffer, for bookkeeping) + tags + 4 byte (last tag)
	unsigned nBufferSize = sizeof (TPropertyBuffer) + nTagSize + sizeof (u32);
	assert ((nBufferSize & 3) == 0);

	// xzl: 0x400000? TODO do we need 1 whole section?  just kmalloc and kfree afterward
	//		TOOD: checksize 
	TPropertyBuffer *pBuffer = (TPropertyBuffer *) MEM_COHERENT_REGION;	
	
	// first, bufsize & req/resp code
	pBuffer->nBufferSize = nBufferSize;
	pBuffer->nCode = CODE_REQUEST;
	
	// copy all tags
	memcpy (pBuffer->Tags, pTag, nTagSize);	
	
	// populating a tag's "header" (excluding the actual payload....)
	TPropertyTag *pHeader = (TPropertyTag *) pBuffer->Tags;
	pHeader->nTagId = nTagId;
	pHeader->nValueBufSize = nTagSize - sizeof (TPropertyTag); // total buf for req/resp exchange
	pHeader->nValueLength = nRequestParmSize & ~VALUE_LENGTH_RESPONSE;		// xzl: need to pass req val lengh to gpu? no?

	// populating the end tag
	u32 *pEndTag = (u32 *) (pBuffer->Tags + nTagSize);
	*pEndTag = PROPTAG_END;

	u32 nBufferAddress = BUS_ADDRESS ((u32) pBuffer);	// xzl: gpu addr
	if (BcmMailBoxWriteRead (&pThis->m_MailBox, nBufferAddress) != nBufferAddress)
	{
		return FALSE;
	}
	
	DataMemBarrier ();

	if (pBuffer->nCode != CODE_RESPONSE_SUCCESS)
		return FALSE;
	
	// resp bit not set
	if (!(pHeader->nValueLength & VALUE_LENGTH_RESPONSE)) 
		return FALSE;

	// resp val	is 0
	pHeader->nValueLength &= ~VALUE_LENGTH_RESPONSE;
	if (pHeader->nValueLength == 0)
		return FALSE;

	memcpy (pTag, pBuffer->Tags, nTagSize); // copy out 
	return TRUE;
}


/////////////////// 


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


