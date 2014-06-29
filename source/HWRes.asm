; *** Resident part: Hardware dependent ***

include	NDISdef.inc
include	b44.inc
include	MIIdef.inc
include	misc.inc
include	DrvRes.inc
include	Pci0Res.inc

public	DrvMajVer, DrvMinVer
DrvMajVer	equ	1
DrvMinVer	equ	5

.386

_REGSTR	segment	use16 dword AT 'RGST'
	org	0
sbpcireg	label	sbpciregs_t
enetreg		bcmenetregs <>
_REGSTR	ends

_DATA	segment	public word use16 'DATA'

; --- DMA Descriptor management ---
public	VTxFreeCount, TxFreeCount
public	VTxHead, VTxFreeHead, TxFreeHead
public	TxEnd, TxBase, TxBasePhys, TxModify
VTxFreeCount	dw	0
TxFreeCount	dw	0
VTxHead		dw	0
VTxFreeHead	dw	0
TxFreeHead	dw	0
TxEnd		dw	0
TxModify	dw	0	; = total txd size
TxBase		dw	0
TxBasePhys	dd	0


public	VRxHead, VRxInProg, VRxBusyHead, VRxBusyTail
public	VRxEnd, VRxBase, VRxModify, RxBase, RxBasePhys
VRxHead		dw	0
VRxInProg	dw	0
VRxBusyHead	dw	0
VRxBusyTail	dw	0
VRxEnd		dw	0
VRxBase		dw	0
VRxModify	dw	0	; = total vrxd size
RxBase		dw	0
RxBasePhys	dd	0


; --- System(PCI) Resource ---
public	MEMSel, MEMaddr, IRQlevel, BusDevFunc
BusDevFunc	dw	?
MEMaddr		dd	?
MEMSel		dw	?
IRQlevel	db	?


align	2
; --- Physical information ---
PhyInfo		_PhyInfo <>

public	MediaSpeed, MediaDuplex, MediaPause, MediaLink	; << for debug >>
MediaSpeed	db	0
MediaDuplex	db	0
MediaPause	db	0
MediaLink	db	0


; --- Register Contents ---
public	regIntStatus, regIntMask	; << for debug info >>
regIntStatus	dd	0
regIntMask	dd	0 ; I_RI or I_XI or I_ERRORS or I_TO or I_EM


; --- ReceiveChain Frame Descriptor ---
public	RxFrameLen, RxDesc	; << for debug info >>
RxFrameLen	dw	0
RxDesc		RxFrameDesc	<>


; --- Configuration Memory Image Parameters ---
public	cfgSLOT, cfgTXQUEUE, cfgRXQUEUE, cfgMAXFRAMESIZE
public	cfgTxWaterMark, cfgIntRecvLazy, cfgTxPauseWM
public	cfgTxMXBurst, cfgRxMXBurst
cfgSLOT		db	0
cfgTXQUEUE	db	8
cfgRXQUEUE	db	16

cfgTxWaterMark	db	56		; *32=1792?
cfgTxMXBurst	dw	16		; *32=512?
cfgRxMXBurst	dw	16		; *32=512?
cfgMAXFRAMESIZE	dw	1514
cfgIntRecvLazy	dd	(4 shl 24) or 32768	; about 500us
cfgTxPauseWM	db	192		; *8=1536?


; --- Receive Buffer address ---
public	RxBufferLin, RxBufferPhys, RxBufferSize, RxBufferSelCnt, RxBufferSel
RxBufferLin	dd	?
RxBufferPhys	dd	?
RxBufferSize	dd	?
RxBufferSelCnt	dw	?
RxBufferSel	dw	2 dup (?)	; max is 2.

; ---Vendor Adapter Description ---
public	AdapterDesc
AdapterDesc	db	'Broadcom BCM4401 Fast Ethernet Adapter',0


_DATA	ends

_TEXT	segment	public word use16 'CODE'
	assume	ds:_DATA, gs:_REGSTR
	
; USHORT hwTxChain(TxFrameDesc *txd, USHORT rqh, USHORT pid)
_hwTxChain	proc	near
	push	bp
	mov	bp,sp
	push	fs
	lfs	bx,[bp+4]
	xor	ax,ax
	push	offset semTx
	mov	cx,fs:[bx].TxFrameDesc.TxImmedLen
	mov	dx,fs:[bx].TxFrameDesc.TxDataCount
	cmp	ax,cx
	adc	ax,dx		; ax=number of txd required.

	call	_EnterCrit
	mov	si,[VTxFreeCount]
	mov	di,[TxFreeCount]
	dec	si
;	jl	short loc_or		; no vtxd, out of resource
	jl	near ptr loc_or
	sub	di,ax
;	jc	short loc_or		; lack of txd, out of resource
	jc	near ptr loc_or
	mov	[VTxFreeCount],si
	mov	[TxFreeCount],di
	mov	bx,[VTxFreeHead]
	mov	si,[TxFreeHead]
	mov	[bx].vtxd.cnt,ax	; fragment count
	mov	[bx].vtxd.head,si	; first fragment

	shl	ax,3
	mov	di,[bx].vtxd.vlink
	add	ax,si
	cmp	ax,[TxEnd]
	jna	short loc_1
	sub	ax,[TxModify]
loc_1:
	mov	[VTxFreeHead],di	; next vtxd
	mov	[TxFreeHead],ax		; next txd
	mov	di,[bp+8]
	mov	si,[bp+10]
	sub	ax,sizeof(dmadd_t)
	mov	bp,[bp+4]
	cmp	ax,[TxBase]
	jnb	short loc_2
	add	ax,[TxModify]
loc_2:
	mov	[bx].vtxd.reqhandle,di
	mov	[bx].vtxd.protid,si
	mov	[bx].vtxd.tail,ax

	test	cx,cx			; immediate length
	mov	di,[bx].vtxd.head
	jz	short loc_3		; no immediate data

	push	di
	mov	ax,cx
	mov	word ptr [di].dmadd_t.ctrl,cx
	and	ax,3
	shr	cx,2
	lea	di,[bx].vtxd.ImmedBuf
	push	ds
	push	ds
	pop	es
	lds	si,fs:[bp].TxFrameDesc.TxImmedPtr
	rep	movsd
	mov	cx,ax
	rep	movsb
	pop	ds
	pop	di
	mov	eax,[bx].vtxd.ImmedPhys
	add	eax,BCM4710_PCI_DMA
	mov	[di].dmadd_t.paddr,eax
	jmp	short loc_5

loc_or:
	mov	ax,OUT_OF_RESOURCE
	jmp	short loc_10

loc_3:
	add	bp,offset TxFrameDesc.TxBufDesc1 ; sizeof(TxBufDesc)
	cmp	fs:[bp].TxBufDesc.TxPtrType,0
	mov	eax,fs:[bp].TxBufDesc.TxDataPtr
	jz	short loc_4
	push	eax
	call	_VirtToPhys
	add	sp,4
loc_4:
	mov	cx,fs:[bp].TxBufDesc.TxDataLen
	add	eax,BCM4710_PCI_DMA
	mov	[di].dmadd_t.paddr,eax
	mov	word ptr [di].dmadd_t.ctrl,cx

loc_5:
	xor	ax,ax
	cmp	di,[bx].vtxd.head
	jnz	short loc_6
	or	ax,highword CTRL_SOF
loc_6:
	cmp	di,[bx].vtxd.tail
	jnz	short loc_7
;	or	ax,highword CTRL_EOF
	or	ax,highword (CTRL_EOF or CTRL_IOC)
loc_7:
	cmp	di,[TxEnd]
	jnz	short loc_8
	or	ax,highword CTRL_EOT
loc_8:
	mov	word ptr [di].dmadd_t.ctrl[2],ax

	add	di,sizeof(dmadd_t)
	cmp	di,[TxEnd]
	jna	short loc_9
	mov	di,[TxBase]
loc_9:
	test	ax,highword CTRL_EOF
	jz	short loc_3

	sub	di,[TxBase]
	mov	ax,REQUEST_QUEUED
	movzx	ecx,di
	mov	gs:[enetreg.dmaregs.xmtptr],ecx	; update xmtptr
loc_10:
	call	_LeaveCrit
	pop	cx	; stack adjust
	pop	fs
	pop	bp
	retn
_hwTxChain	endp


_hwRxRelease	proc	near
	push	bp
	mov	bp,sp
	push	si
	push	offset semRx
	call	_EnterCrit

	mov	ax,[bp+4]		; ReqHandle = vrxd
	mov	bx,[VRxInProg]
	mov	si,[VRxBusyHead]
	test	bx,bx
	jz	short loc_2		; no frame in progress
	cmp	ax,bx
	jnz	short loc_2
	mov	[VRxInProg],0
	or	si,si			; busy frames exist?
	jz	short loc_4
	jnz	short loc_ex

loc_1:
	mov	bx,si
	mov	si,[bx].vrxd.vlink	; next link
loc_2:
	or	si,si
	jz	short loc_ex		; not found
	cmp	ax,si
	jnz	short loc_1		; matched handle?
loc_3:
	cmp	si,[VRxBusyHead]
	jz	short loc_h		; matched frame is busy top
	cmp	si,[VRxBusyTail]
	mov	ax,[si].vrxd.vlink
	jnz	short loc_m
loc_t:
	mov	[VRxBusyTail],bx
loc_m:
	mov	[bx].vrxd.vlink,ax	; ax=0(tail) or next ptr
	jmp	short loc_ex

loc_h:
	mov	bx,[si].vrxd.vlink
	mov	[si].vrxd.vlink,0
	mov	[VRxBusyHead],bx
	or	bx,bx			; next busy frames exist?
	jnz	short loc_5
	mov	bx,[VRxInProg]
	or	bx,bx			; in progress frame exists?
	jnz	short loc_5
loc_4:
	mov	bx,[VRxHead]
loc_5:
	xor	eax,eax
	sub	bx,sizeof(vrxd)
	cmp	bx,[VRxBase]
	jnc	short loc_6
	mov	bx,[VRxBase]
loc_6:
	mov	ax,[bx].vrxd.rxd
	sub	ax,[RxBase]
	mov	gs:[enetreg.dmaregs.rcvptr],eax	; update rcvptr

loc_ex:
	call	_LeaveCrit
	pop	cx	; stack adjust
	mov	ax,SUCCESS
	pop	si
	pop	bp
	retn
_hwRxRelease	endp


_ServiceIntTx	proc	near
	cld
	push	offset semTx
loc_0:
	call	_EnterCrit
	mov	bx,[VTxHead]
	cmp	bx,[VTxFreeHead]
	jz	short loc_exit		; vtxd queue is empty
	mov	eax,gs:[enetreg.dmaregs.xmtstatus]
	and	ax,XS_CD_MASK		; current descriptor pointer
	mov	cx,[bx].vtxd.head
	mov	dx,[bx].vtxd.tail
	add	ax,[TxBase]
	cmp	cx,dx			; head <= tail?
	ja	short loc_1
			; head <= tail
			; pointer < head  or  tail < pointer
	cmp	ax,dx
	ja	short loc_2
	cmp	ax,cx
	jc	short loc_2
	jmp	short loc_exit		; in progress

loc_1:
			; head > tail  descriptor wraparound
			; tail < pointer < head
	cmp	ax,cx
	jnc	short loc_exit
	cmp	ax,dx
	jna	short loc_exit
loc_2:
	mov	ax,[bx].vtxd.cnt
	mov	cx,[bx].vtxd.vlink
	inc	[VTxFreeCount]		; release vtxd
	add	[TxFreeCount],ax	; release txd
	mov	[VTxHead],cx		; update vtxd head
	mov	dx,[bx].vtxd.reqhandle
	mov	cx,[bx].vtxd.protid
	call	_LeaveCrit

	test	dx,dx
	jz	short loc_0		; null request handle - no confirm
	mov	ax,[CommonChar.moduleID]
	mov	bx,[ProtDS]

	push	cx	; ProtID
	push	ax	; MACID
	push	dx	; ReqHandle
	push	0	; Status
	push	bx	; ProtDS
	call	dword ptr [LowDisp.txconfirm]
IF 1
	mov	gs,[MEMSel]	; fix gs selector for switch.os2
ENDIF

	jmp	short loc_0

loc_exit:
	call	_LeaveCrit
	pop	ax	; stack adjust
	retn
_ServiceIntTx	endp


_ServiceIntRx	proc	near
	push	bp
	push	offset semRx
loc_0:
	call	_EnterCrit
loc_1:
	mov	bx,[VRxInProg]
	mov	si,[VRxHead]
	test	bx,bx
;	jnz	short loc_rty		; retry suspending frame
	jnz	near ptr loc_rty

	mov	eax,gs:[enetreg.dmaregs.rcvstatus]
	and	ax,RS_CD_MASK
	add	ax,[RxBase]
	cmp	ax,[si].vrxd.rxd
	jz	short loc_ex		; rx idle
	les	bp,[si].vrxd.vaddr
	mov	bx,es:[bp].bcmenetrxh_t.flags
	test	bx,RXF_L		; rx complete?
	jnz	short loc_fst
loc_ex:
	call	_LeaveCrit
	pop	cx	; stack adjust
	pop	bp
	retn

loc_fst:
				; calculate next rx pointer
	mov	ax,es:[bp].bcmenetrxh_t.len
	mov	di,ax		; backup
	xor	dx,dx
	add	ax,sizeof(bcmenetrxh_t)	; append rx header size
	mov	cx,1536+16
	div	cx
	neg	dx
	adc	ax,0
	mov	cx,sizeof(vrxd)
	xchg	ax,cx
	mul	cl
	add	ax,si
	cmp	ax,[VRxEnd]
	jbe	short loc_2
	sub	ax,[VRxModify]
loc_2:
	mov	[VRxHead],ax
	mov	[VRxInProg],si
	add	dx,4		; -last size +4  [-4..-1]->CF
	sbb	cx,0		; effective fragment count

	mov	ax,di			; buffer length
	cmp	cx,8
	ja	short loc_rmv		; too many fragment
	test	bx,RXF_OV or RXF_CRC or RXF_RXER or RXF_NO or RXF_LG
	jnz	short loc_rmv		; errored frame
	sub	ax,4
	jbe	short loc_rmv		; frame length <=0 !?
	cmp	ax,[cfgMAXFRAMESIZE]	; too long frame?
	jbe	short loc_vld	

loc_rmv:
	xor	eax,eax
	cmp	ax,[VRxBusyHead]	; queued frame?
	mov	[VRxInProg],ax		; clear
	jnz	short loc_rmv2
	mov	si,[VRxHead]
	sub	si,sizeof(vrxd)
	cmp	si,[VRxBase]
	jnc	short loc_rmv1
	mov	si,[VRxEnd]
loc_rmv1:
	mov	ax,[si].vrxd.rxd
	sub	ax,[RxBase]
	mov	gs:[enetreg.dmaregs.rcvptr],eax
loc_rmv2:
;	jmp	short loc_1
	jmp	near ptr loc_1

loc_vld:
	mov	[RxFrameLen],ax
	mov	[RxDesc.RxDataCount],cx
	mov	di,offset RxDesc.RxBufDesc1
	add	bp,sizeof(bcmenetrxh_t)	; first fragment data ptr
	mov	bx,1536+16-sizeof(bcmenetrxh_t)	; first max size
	mov	word ptr [di].RxBufDesc.RxDataPtr,bp
	mov	word ptr [di].RxBufDesc.RxDataPtr[2],es
	dec	cx
	jz	short loc_lst		; last fragment
loc_3:
	mov	[di].RxBufDesc.RxDataLen,bx
	add	si,sizeof(vrxd)
	add	di,sizeof(RxBufDesc)
	cmp	si,[VRxEnd]
	jbe	short loc_4
	mov	si,[VRxBase]
loc_4:	
	sub	ax,bx
	mov	bp,word ptr [si].vrxd.vaddr
	mov	dx,word ptr [si].vrxd.vaddr[2]
	mov	bx,1536+16
	mov	word ptr [di].RxBufDesc.RxDataPtr,bp
	mov	word ptr [di].RxBufDesc.RxDataPtr[2],dx
	dec	cx
	jnz	short loc_3

loc_lst:
	mov	[di].RxBufDesc.RxDataLen,ax
	mov	bx,[VRxInProg]
loc_rty:
	call	_LeaveCrit

	call	_IndicationChkOFF
	or	ax,ax
	jz	short loc_spd		; indicate off - suspend...

	push	-1
	mov	cx,[RxFrameLen]
	mov	ax,[ProtDS]
	mov	dx,[CommonChar.moduleID]
	mov	di,sp
	push	bx			; current vrxd = handle

	push	dx		; MACID
	push	cx		; FrameSize
	push	bx		; ReqHandle
	push	ds
	push	offset RxDesc	; RxFrameDesc
	push	ss
	push	di		; Indicate
	push	ax		; Protocol DS
	call	dword ptr [LowDisp.rxchain]
IF 1
	mov	gs,[MEMSel]	; fix gs selector for switch.os2
ENDIF
lock	or	[drvflags],mask df_idcp
	cmp	ax,WAIT_FOR_RELEASE
	jz	short loc_11
	call	_hwRxRelease
loc_12:
	pop	cx	; stack adjust
	pop	ax	; indicate
	cmp	al,-1
	jnz	short loc_spd		; indication remains OFF - suspend
	call	_IndicationON
	jmp	near ptr loc_0
loc_11:
	call	_RxPutBusyQueue
	jmp	short loc_12

loc_spd:
lock	or	[drvflags],mask df_rxsp
	pop	cx	; stack adjust
	pop	bp
	retn


_RxPutBusyQueue	proc	near
	push	offset semRx
	call	_EnterCrit
	mov	bx,[VRxInProg]
	xor	ax,ax
	test	bx,bx
	jz	short loc_ex		; no in progess frame
	cmp	ax,[VRxBusyHead]
	jnz	short loc_1
	mov	[VRxBusyHead],bx
	jmp	short loc_2
loc_1:
	mov	si,[VRxBusyTail]
	mov	[si].vrxd.vlink,bx
loc_2:
	mov	[VRxInProg],ax		; clear
	mov	[VRxBusyTail],bx
	mov	[bx].vrxd.vlink,ax	; null pointer
loc_ex:
	call	_LeaveCrit
	pop	bx	; stack adjust
	retn
_RxPutBusyQueue	endp

_ServiceIntRx	endp


_hwServiceInt	proc	near
	enter	4,0
loc_0:
	mov	eax,gs:[enetreg.intstatus]
lock	or	[regIntStatus],eax
	mov	eax,[regIntStatus]
	and	eax,[regIntMask]
;	jz	short loc_6
	jz	near ptr loc_6
	mov	gs:[enetreg.intstatus],eax

loc_1:
	mov	[bp-4],eax

	mov	eax,I_TXS or I_TO
	test	[bp-4],eax
	jz	short loc_2
	not	eax
lock	and	[regIntStatus],eax
	call	_ServiceIntTx

loc_2:
	mov	eax,I_RXS or I_TO
	cmp	[Indication],0		; rx enable
	jnz	short loc_3
	test	[bp-4],eax
	jz	short loc_3
	not	eax
lock	and	[regIntStatus],eax
	call	_ServiceIntRx

loc_3:
	mov	eax,I_EM
	test	[bp-4],eax
	jz	short loc_4
	not	eax
lock	and	[regIntStatus],eax
	mov	eax,gs:[enetreg.emacintstatus]
	and	eax,EI_MIB
	jz	short loc_4
	mov	gs:[enetreg.emacintstatus],eax
	call	_hwUpdateStat

loc_4:
	test	dword ptr [bp-4],I_ERRORS
	jz	short loc_5
	mov	[regIntMask],0
lock	or	[drvflags],mask df_errrst
	mov	ebx,[CtxHandle]
	or	ecx,-1
;	mov	dl,DevHlp_ArmCtxHook
	mov	dl,65h
	call	dword ptr [DevHelp]
	jmp	short loc_6

loc_5:
lock	btr	[drvflags],df_rxsp
;	jnc	short loc_0
	jnc	near ptr loc_0
loc_6:
	leave
	retn
_hwServiceInt	endp

_hwCheckInt	proc	near
	mov	eax,gs:[enetreg.intstatus]
lock	or	[regIntStatus],eax
	mov	eax,[regIntStatus]
	test	eax,[regIntMask]
	setnz	al	
	mov	ah,0
	retn
_hwCheckInt	endp

_hwEnableInt	proc	near
	mov	eax,[regIntMask]
	mov	gs:[enetreg.intmask],eax; set IMR
	retn
_hwEnableInt	endp

_hwDisableInt	proc	near
	mov	gs:[enetreg.intmask],0	; clear IMR
	mov	eax,gs:[enetreg.intmask] ; dummy read
	retn
_hwDisableInt	endp

_hwIntReq	proc	near
	mov	gs:[enetreg.gptimer],32	; one-shot timer? 512ns?
	retn
_hwIntReq	endp

_hwEnableRxInd	proc	near
	push	eax
lock	or	[regIntMask],I_RXS
	cmp	[semInt],0
	jnz	short loc_1
	mov	eax,[regIntMask]
	mov	gs:[enetreg.intmask],eax
loc_1:
	pop	eax
	retn
_hwEnableRxInd	endp

_hwDisableRxInd	proc	near
	push	eax
lock	and	[regIntMask],not I_RXS
	cmp	[semInt],0
	jnz	short loc_1
	mov	eax,[regIntMask]
	mov	gs:[enetreg.intmask],eax
loc_1:
	pop	eax
	retn
_hwDisableRxInd	endp


_hwPollLink	proc	near
	test	[drvflags],mask df_errrst
	jnz	short loc_errrst
	call	_ChkLink
	test	al,MediaLink
	jz	short loc_0	; Link status change/down
	retn
loc_0:
	or	al,al
	mov	MediaLink,al
	jnz	short loc_1	; change into Link Active
	call	_ChkLink	; link down. check again.
	or	al,al
	mov	MediaLink,al
	jnz	short loc_1	; short time link down
	retn

loc_1:
	call	_GetPhyMode

	cmp	al,MediaSpeed
	jnz	short loc_2
	cmp	ah,MediaDuplex
	jnz	short loc_2
	cmp	dl,MediaPause
	jz	short loc_3
loc_2:
	mov	MediaSpeed,al
	mov	MediaDuplex,ah
	mov	MediaPause,dl
	call	_SetMacEnv
loc_3:
	retn

loc_errrst:
	call	_hwReset
	call	_hwOpen
lock	and	[drvflags],not (mask df_errrst)
	retn
_hwPollLink	endp

_hwOpen		proc	near	; call in protocol bind process?
	call	_AutoNegotiate
	mov	MediaSpeed,al
	mov	MediaDuplex,ah
	mov	MediaPause,dl

	call	_SetMacEnv
	call	_SetDMAQueue

lock	or	[drvflags],mask df_initdn

	xor	eax,eax
	mov	edx,I_RI or I_XI or I_ERRORS or I_TO or I_EM

	mov	[regIntStatus],eax
	mov	[regIntMask],edx
	dec	eax
	mov	gs:[enetreg.emacintstatus],eax	; emac int clear
	mov	gs:[enetreg.intstatus],eax	; int clear
	mov	gs:[enetreg.emacintmask],EI_MIB	; emac int mask
	mov	gs:[enetreg.intmask],edx	; int mask
	or	gs:[enetreg.enetcontrol],EC_EE	; emac core enable

	mov	ax,SUCCESS
	retn
_hwOpen		endp

_SetMacEnv	proc	near
	mov	eax,gs:[enetreg.rxconfig]
	xor	ecx,ecx		; txcontrol
	xor	edx,edx		; emacflowcontrol
	and	al,ERC_DB or ERC_PE
	or	al,ERC_RDT		; disable rx while tx

	cmp	[MediaDuplex],0		; half duplex?
	jz	short loc_2
	or	cl,EXC_FD		; full duplex transmit
	and	al,not ERC_RDT		; enable rx while tx

	test	[MediaPause],1		; tx pause?
	jz	short loc_1
	mov	dl,[cfgTxPauseWM]
	mov	dh,high(EMF_PG)		; pause enable
	or	cl,EXC_FM		; flowmode
loc_1:
	test	[MediaPause],2		; rx pause?
	jz	short loc_2
	or	al,ERC_EF		; rx pause frame
loc_2:
	mov	gs:[enetreg.rxconfig],eax
	mov	gs:[enetreg.txcontrol],ecx
	mov	gs:[enetreg.emacflowcontrol],edx

	call	_SetSpeedStat
	retn
_SetMacEnv	endp

_SetDMAQueue	proc	near
	push	bp

	push	offset semTx
	call	_EnterCrit
	mov	si,[VTxHead]
	mov	ax,[VTxFreeHead]
	mov	cx,[TxBase]
	mov	[VTxHead],ax
	mov	[TxFreeHead],cx
	mov	eax,[TxBasePhys]
	add	eax,BCM4710_PCI_DMA
	mov	gs:[enetreg.dmaregs.xmtcontrol],XC_XE
	mov	gs:[enetreg.dmaregs.xmtaddr],eax
	call	_LeaveCrit

	cmp	si,[VTxFreeHead]
	jz	short loc_rx

	xor	di,di		; fragment count
	sub	bp,bp		; vtxd count
loc_t0:
	mov	cx,[si].vtxd.reqhandle
	mov	dx,[si].vtxd.protid
	mov	ax,[CommonChar.moduleID]
	mov	bx,[ProtDS]
	add	di,[si].vtxd.cnt
	inc	bp
	mov	si,[si].vtxd.vlink

	push	dx		; ProtID
	push	ax		; MACID
	push	cx		; ReqHandle
	push	word ptr 0ffh	; Status
	push	bx		; ProtDS
	call	dword ptr [LowDisp.txconfirm]
IF 1
	mov	gs,[MEMSel]	; fix gs selector for switch.os2
ENDIF

	cmp	si,[VTxFreeHead]
	jnz	short loc_t0

	call	_EnterCrit
	add	[VTxFreeHead],bp
	add	[TxFreeCount],di
	call	_LeaveCrit

loc_rx:
	push	offset semRx
	call	_EnterCrit
	xor	ax,ax
	mov	cx,[VRxBase]
	mov	bx,[VRxBusyHead]
	mov	[VRxHead],cx
	mov	[VRxInProg],ax
	mov	[VRxBusyHead],ax
	or	bx,bx
	jz	short loc_r2
loc_r1:
	mov	di,[bx].vrxd.vlink
	mov	[bx].vrxd.vlink,ax
	or	di,di
	mov	bx,di
	jnz	short loc_r1
loc_r2:
	mov	bx,[VRxEnd]
	mov	eax,[RxBasePhys]
	movzx	ecx,[bx].vrxd.rxd
	add	eax,BCM4710_PCI_DMA
	sub	cx,[RxBase]
	mov	gs:[enetreg.dmaregs.rcvcontrol],\
		  (sizeof(bcmenetrxh_t) shl 1) or RC_RE
	mov	gs:[enetreg.dmaregs.rcvaddr],eax
	mov	gs:[enetreg.dmaregs.rcvptr],ecx
	call	_LeaveCrit

	add	sp,2*2
	pop	bp
	retn
_SetDMAQueue	endp


_SetSpeedStat	proc	near
	mov	al,[MediaSpeed]
	mov	ah,0
	dec	ax
	jz	short loc_10M
	dec	ax
	jz	short loc_100M
;	dec	ax
;	jz	short loc_1G
	xor	ax,ax
	sub	cx,cx
	jmp	short loc_1
loc_10M:
	mov	cx,highword 10000000
	mov	ax,lowword  10000000
	jmp	short loc_1
loc_100M:
	mov	cx,highword 100000000
	mov	ax,lowword  100000000
;	jmp	short loc_1
loc_1G:
;	mov	cx,highword 1000000000
;	mov	ax,lowword  1000000000
loc_1:
	mov	word ptr [MacChar.linkspeed],ax
	mov	word ptr [MacChar.linkspeed][2],cx
	retn
_SetSpeedStat	endp


_ChkLink	proc	near
	push	miiBMSR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	and	ax,miiBMSR_LinkStat
	add	sp,2*2
	shr	ax,2
	retn
_ChkLink	endp


_AutoNegotiate	proc	near
	enter	2,0
	push	0
	push	miiBMCR
	push	[PhyInfo.Phyaddr]
	call	_miiWrite		; clear ANEnable bit
	add	sp,3*2

	push	33
	call	_Delay1ms
;	push	miiBMCR_ANEnable or miiBMCR_RestartAN
	push	miiBMCR_ANEnable	; remove restart bit??
	push	miiBMCR
	push	[PhyInfo.Phyaddr]
	call	_miiWrite		; restart Auto-Negotiation
	add	sp,(1+3)*2

	mov	word ptr [bp-2],3*30	; about 3sec.
loc_1:
	push	33
	call	_Delay1ms
	push	miiBMCR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,(1+2)*2
	test	ax,miiBMCR_RestartAN	; AN in progress?
	jz	short loc_2
	dec	word ptr [bp-2]
	jnz	short loc_1
	jmp	short loc_f
loc_2:
	push	33
	call	_Delay1ms
	push	miiBMSR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,(1+2)*2
	test	ax,miiBMSR_ANComp	; AN Base Page exchange complete?
	jnz	short loc_3
	dec	word ptr [bp-2]
	jnz	short loc_2
	jmp	short loc_f
loc_3:
	push	33
	call	_Delay1ms
	push	miiBMSR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,(1+2)*2
	test	ax,miiBMSR_LinkStat	; link establish?
	jnz	short loc_4
	dec	word ptr [bp-2]
	jnz	short loc_3
loc_f:
	xor	ax,ax			; AN failure.
	xor	dx,dx
	leave
	retn
loc_4:
	call	_GetPhyMode
	leave
	retn
_AutoNegotiate	endp

_GetPhyMode	proc	near
	push	miiANLPAR
	push	[PhyInfo.Phyaddr]
	call	_miiRead		; read base page
	add	sp,2*2
	mov	[PhyInfo.ANLPAR],ax

	test	[PhyInfo.BMSR],miiBMSR_ExtStat
	jz	short loc_2

	push	mii1KSTSR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,2*2
	mov	[PhyInfo.GSTSR],ax
;	shl	ax,2
;	and	ax,[PhyInfo.GSCR]
	shr	ax,2
	and	ax,[PhyInfo.GTCR]
;	test	ax,mii1KSCR_1KTFD
	test	ax,mii1KTCR_1KTFD
	jz	short loc_1
	mov	al,3			; media speed - 1000Mb
	mov	ah,1			; media duplex - full
	jmp	short loc_p
loc_1:
;	test	ax,mii1KSCR_1KTHD
	test	ax,mii1KTCR_1KTHD
	jz	short loc_2
	mov	al,3			; 1000Mb
	mov	ah,0			; half duplex
	jmp	short loc_p
loc_2:
	mov	ax,[PhyInfo.ANAR]
	and	ax,[PhyInfo.ANLPAR]
	test	ax,miiAN_100FD
	jz	short loc_3
	mov	al,2			; 100Mb
	mov	ah,1			; full duplex
	jmp	short loc_p
loc_3:
	test	ax,miiAN_100HD
	jz	short loc_4
	mov	al,2			; 100Mb
	mov	ah,0			; half duplex
	jmp	short loc_p
loc_4:
	test	ax,miiAN_10FD
	jz	short loc_5
	mov	al,1			; 10Mb
	mov	ah,1			; full duplex
	jmp	short loc_p
loc_5:
	test	ax,miiAN_10HD
	jz	short loc_e
	mov	al,1			; 10Mb
	mov	ah,0			; half duplex
	jmp	short loc_p
loc_e:
	xor	ax,ax
	sub	dx,dx
	retn
loc_p:
	cmp	ah,1			; full duplex?
	mov	dh,0
	jnz	short loc_np
	mov	cx,[PhyInfo.ANLPAR]
	test	cx,miiAN_PAUSE		; symmetry
	mov	dl,3			; tx/rx pause
	jnz	short loc_ex
	test	cx,miiAN_ASYPAUSE	; asymmetry
	mov	dl,2			; rx pause
	jnz	short loc_ex
loc_np:
	mov	dl,0			; no pause
loc_ex:
	retn
_GetPhyMode	endp


_ResetPhy	proc	near
	enter	2,0
	call	_miiReset	; Reset Interface
	push	miiPHYID2
;	push	1		; phyaddr 1
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,2*2
	or	ax,ax		; ID2 = 0
	jz	short loc_1
	inc	ax		; ID2 = -1
	jnz	short loc_2
loc_1:
	mov	ax,HARDWARE_FAILURE
	leave
	retn
loc_2:
;	mov	[PhyInfo.Phyaddr],1
	push	miiBMCR_Reset
	push	miiBMCR
	push	[PhyInfo.Phyaddr]
	call	_miiWrite	; Reset PHY
	add	sp,3*2

	push	1536		; wait for about 1.5sec.
	call	_Delay1ms
	pop	ax

	call	_miiReset	; interface reset again
	mov	word ptr [bp-2],64  ; about 2sec.
loc_3:
	push	miiBMCR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,2*2
	test	ax,miiBMCR_Reset
	jz	short loc_4
	push	33
	call	_Delay1ms	; wait reset complete.
	pop	ax
	dec	word ptr [bp-2]
	jnz	short loc_3
	jmp	short loc_1	; PHY Reset Failure
loc_4:
	push	miiBMSR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,2*2
	mov	[PhyInfo.BMSR],ax
	push	miiANAR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,2*2
	mov	[PhyInfo.ANAR],ax
	test	[PhyInfo.BMSR],miiBMSR_ExtStat
	jz	short loc_5	; extended status exist?
	push	mii1KTCR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,2*2
	mov	[PhyInfo.GTCR],ax
	push	mii1KSCR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,2*2
	mov	[PhyInfo.GSCR],ax
	xor	cx,cx
	test	ax,mii1KSCR_1KTFD or mii1KSCR_1KXFD
	jz	short loc_41
	or	cx,mii1KTCR_1KTFD
loc_41:
	test	ax,mii1KSCR_1KTHD or mii1KSCR_1KXHD
	jz	short loc_42
	or	cx,mii1KTCR_1KTHD
loc_42:
	mov	ax,[PhyInfo.GTCR]
	and	ax,not (mii1KTCR_MSE or mii1KTCR_Port or \
		  mii1KTCR_1KTFD or mii1KTCR_1KTHD)
	or	ax,cx
	mov	[PhyInfo.GTCR],ax
	push	ax
	push	mii1KTCR
	push	[PhyInfo.Phyaddr]
	call	_miiWrite
	add	sp,2*2
loc_5:
	mov	ax,[PhyInfo.BMSR]
	mov	cx,miiAN_PAUSE
	test	ax,miiBMSR_100FD
	jz	short loc_61
	or	cx,miiAN_100FD
loc_61:
	test	ax,miiBMSR_100HD
	jz	short loc_62
	or	cx,miiAN_100HD
loc_62:
	test	ax,miiBMSR_10FD
	jz	short loc_63
	or	cx,miiAN_10FD
loc_63:
	test	ax,miiBMSR_10HD
	jz	short loc_64
	or	cx,miiAN_10HD
loc_64:
	mov	ax,[PhyInfo.ANAR]
	and	ax,not (miiAN_ASYPAUSE + miiAN_T4 + \
	  miiAN_100FD + miiAN_100HD + miiAN_10FD + miiAN_10HD)
	or	ax,cx
	mov	[PhyInfo.ANAR],ax
	push	ax
	push	miiANAR
	push	[PhyInfo.Phyaddr]
	call	_miiWrite
	add	sp,3*2
	mov	ax,SUCCESS
	leave
	retn
_ResetPhy	endp


_hwUpdateMulticast	proc	near
	enter	2,0
	push	offset semFlt
	call	_EnterCrit

	xor	ax,ax
loc_1:
	cmp	ax,63			; cam index[1..63] -1
	jnc	short loc_3
	cmp	ax,[MCSTList.curnum]	; multicast count
	jnc	short loc_2
	mov	cx,ax
	shl	ax,4
	inc	cx			; cam index - start at 1
	add	ax,offset MCSTList.multicastaddr1
	mov	[bp-2],cx
	push	cx
	push	ax
	call	_CamWrite
	add	sp,2*2
	mov	ax,[bp-2]
	jmp	short loc_1

loc_2:
	inc	ax
	mov	[bp-2],ax
	push	ax
	call	_CamErase
	mov	ax,[bp-2]
	pop	cx	; stack adjust
	cmp	ax,63
	jc	short loc_2
loc_3:
	xor	eax,eax
	test	[MacStatus.sstRxFilter],mask fltdirect
	setnz	al			; Cam Enable
	mov	gs:[enetreg.camcontrol],eax

	call	_LeaveCrit
	pop	cx
	mov	ax,SUCCESS
	leave
	retn
_hwUpdateMulticast	endp

IF 0
_CRC32		proc	near
POLYNOMIAL_be   equ  04C11DB7h
POLYNOMIAL_le   equ 0EDB88320h

	push	bp
	mov	bp,sp

	push	si
	push	di
	or	ax,-1
	mov	bx,[bp+4]
	mov	ch,3
	cwd

loc_1:
	mov	bp,[bx]
	mov	cl,10h
	inc	bx
loc_2:
IF 0
		; big endian

	ror	bp,1
	mov	si,dx
	xor	si,bp
	shl	ax,1
	rcl	dx,1
	sar	si,15
	mov	di,si
	and	si,highword POLYNOMIAL_be
	and	di,lowword POLYNOMIAL_be
ELSE
		; litte endian
	mov	si,ax
	ror	bp,1
	ror	si,1
	shr	dx,1
	rcr	ax,1
	xor	si,bp
	sar	si,15
	mov	di,si
	and	si,highword POLYNOMIAL_le
	and	di,lowword POLYNOMIAL_le
ENDIF
	xor	dx,si
	xor	ax,di
	dec	cl
	jnz	short loc_2
	inc	bx
	dec	ch
	jnz	short loc_1
	push	dx
	push	ax
	pop	eax
	pop	di
	pop	si
	pop	bp
	retn
_CRC32		endp
ENDIF

_hwUpdatePktFlt	proc	near
	push	offset semFlt
	call	_EnterCrit

	xor	edx,edx
	mov	eax,gs:[enetreg.rxconfig]
	mov	cx,[MacStatus.sstRxFilter]
	and	al,not (ERC_DB or ERC_AM or ERC_PE)

	test	cl,mask fltdirect
	setnz	dl			; pmatch and multi. Cam Enable
	test	cl,mask fltbroad
	jnz	short loc_1
	or	al,ERC_DB		; broadcast disable
loc_1:
	test	cl,mask fltprms
	jz	short loc_2
	or	al,ERC_AM or ERC_PE	; set promiscous
loc_2:
	mov	gs:[enetreg.rxconfig],eax
	mov	gs:[enetreg.camcontrol],edx

	call	_LeaveCrit
	pop	cx
	mov	ax,SUCCESS
	retn
_hwUpdatePktFlt	endp

_hwSetMACaddr	proc	near
	push	offset semFlt
	call	_EnterCrit

	mov	bx,offset MacChar.mctcsa
	mov	ax,[bx]
	or	ax,[bx+2]
	or	ax,[bx+4]
	jnz	short loc_1	; current address may be valid
	mov	ax,word ptr [MacChar.mctpsa]
	mov	cx,word ptr [MacChar.mctpsa][2]
	mov	dx,word ptr [MacChar.mctpsa][4]
				; copy parmanent address
	mov	[bx],ax
	mov	[bx+2],cx
	mov	[bx+4],dx
loc_1:
	push	0		; pmatch index is zero.
	push	bx
	call	_CamWrite
	xor	eax,eax
	add	sp,2*2
	test	[MacStatus.sstRxFilter],mask fltdirect
	setnz	al		; cam enable bit
	mov	gs:[enetreg.camcontrol],eax

	call	_LeaveCrit
	pop	cx
	mov	ax,SUCCESS
	retn
_hwSetMACaddr	endp

; VOID CamWrite(UCHAR *MACADDR, UCHAR index);
_CamWrite	proc	near
	push	bp
	mov	bp,sp
	mov	bx,[bp+4]
	mov	cx,[bp+6]
IF 0
	mov	edx,[bx-2]	; high 0,1
	mov	eax,[bx+2]	; lo 2,3,4,5
	shl	ecx,16
	mov	dx,0100h	; bswap CD_V
	mov	cx,CC_WR
	bswap	eax
	bswap	edx
ELSE
	mov	ax,[bx+2]	; 3 2
	mov	dx,highword CD_V
	xchg	al,ah		; 2 3
	shl	ecx,16
	shl	edx,16
	shl	eax,16
	mov	dx,[bx]		; 1 0
	mov	ax,[bx+4]	; 5 4
	mov	cx,CC_WR
	xchg	al,ah		; 4 5
	xchg	dl,dh		; 0 1
ENDIF
	mov	gs:[enetreg.camdatalo],eax	; 2 3 4 5
	mov	gs:[enetreg.camdatahi],edx	; CD_V 0 1
	mov	gs:[enetreg.camcontrol],ecx	; Index CC_WR
	push	1
	mov	cx,200
loc_1:
	call	__IODelayCnt
	mov	eax,gs:[enetreg.camcontrol]
	shl	eax,1		; cam busy
	jnc	short loc_2
	dec	cx
	jnz	short loc_1
loc_2:
	pop	cx	; stack adjust
	pop	bp
	retn
_CamWrite	endp

; VOID CamErase(UCHAR index);
_CamErase	proc	near
	push	bp
	mov	bp,sp
	mov	ax,[bp+4]
	xor	edx,edx
	shl	eax,16
	mov	ax,CC_WR
	mov	gs:[enetreg.camdatalo],edx
	mov	gs:[enetreg.camdatahi],CD_V
	mov	gs:[enetreg.camcontrol],eax
	push	1
	mov	cx,200
loc_1:
	call	__IODelayCnt
	mov	eax,gs:[enetreg.camcontrol]
	shl	eax,1		; cam busy
	jnc	short loc_2
	dec	cx
	jnz	short loc_1
loc_2:
	pop	cx	; stack adjust
	pop	bp
	retn
_CamErase	endp


_hwUpdateStat	proc	near
	push	si
	push	offset semStat
	call	_EnterCrit

	mov	gs:[enetreg.mibcontrol],EMC_RZ
	mov	si,offset enetreg.mib.tx_good_octets
	mov	bx,offset MacStatus

	lodsd	gs:[si]			; tx_good_octets
	add	[bx].mst.txbyte,eax
	lodsd	gs:[si]			; tx_good_pkts
	add	[bx].mst.txframe,eax
	mov	cx,3
	rep	lodsd	gs:[si]		; tx_broadcast_pkts
	add	[bx].mst.txframebroad,eax
	lodsd	gs:[si]			; tx_multicast_pkts
	add	[bx].mst.txframemulti,eax
	mov	cx,10
	rep	lodsd	gs:[si]		; tx_underrun
	add	[bx].mst.txframehw,eax
	mov	cx,6
	rep	lodsd	gs:[si]		; tx_defferd
	add	[bx].mst.txframeto,eax
	mov	cx,2
	rep	lodsd	gs:[si]

	add	si,8*4

	lodsd	gs:[si]			; rx_good_octets
	add	[bx].mst.rxbyte,eax
	lodsd	gs:[si]			; rx_good_pkts
	add	[bx].mst.rxframe,eax
	mov	cx,3
	rep	lodsd	gs:[si]		; rx_broadcast_pkts
	add	[bx].mst.rxframebroad,eax
	lodsd	gs:[si]			; rx_multicast_pkts
	add	[bx].mst.rxframemulti,eax
	mov	cx,7
	rep	lodsd	gs:[si]		; rx_jabber_pkts
	add	[bx].mst.rxframehw,eax
	lodsd	gs:[si]			; rx_oversize_pkts
	add	[bx].mst.rxframehw,eax
	mov	cx,2
	rep	lodsd	gs:[si]		; rx_missed_pkts
	add	[bx].mst.rxframebuf,eax
	lodsd	gs:[si]			; rx_crc_align_errs
	add	[bx].mst.rxframecrc,eax
	lodsd	gs:[si]			; rx_undersize
	add	[bx].mst.rxframehw,eax
	lodsd	gs:[si]			; rx_crc_errs
	add	[bx].mst.rxframecrc,eax
	lodsd	gs:[si]			; rx_align_errs
	add	[bx].mst.rxframecrc,eax
	lodsd	gs:[si]			; rx_symbol_errs
	add	[bx].mst.rxframecrc,eax
	mov	cx,2
	rep	lodsd	gs:[si]

	call	_LeaveCrit
	pop	ax	; stack adjust
	pop	si
	retn
_hwUpdateStat	endp

_hwClearStat	proc	near
	mov	gs:[enetreg.mibcontrol],EMC_RZ
	push	ds
	mov	ds,[MEMSel]
	push	si
	mov	si,offset enetreg.mib.tx_good_octets
	mov	cx,1 + (offset enetreg.mib.tx_pause_pkts \
		 - offset enetreg.mib.tx_good_octets)/4
	rep	lodsd
	add	si,8*4
	mov	cx,1 + (offset enetreg.mib.rx_nonpause_pkts \
		 - offset enetreg.mib.rx_good_octets)/4
	rep	lodsd

	pop	si
	pop	ds
	retn
_hwClearStat	endp

_hwClose	proc	near
	call	_hwDisableInt
	or	eax,-1
	mov	gs:[enetreg.intstatus],eax
	mov	gs:[enetreg.emacintstatus],eax
	call	_chipReset

	mov	ax,SUCCESS
	retn
_hwClose	endp

_hwReset	proc	near	; call in bind process
	enter	6,0

	mov	ax,[BusDevFunc]
	push	word ptr highword SBID_REG_EMAC
	push	word ptr lowword SBID_REG_EMAC
	push	word ptr PCI_BAR0_WIN
	push	ax
	call	_pci0WriteD		; select emac core
	add	sp,4*2

	push	word ptr SB_ENET
	call	_sbcoreCheck

	pop	cx
	cmp	ax,SUCCESS
;	jnz	short loc_ex
	jnz	near ptr loc_ex

;	call	_hwDisableInt
	xor	eax,eax
	mov	[regIntMask],eax
	test	[drvflags],mask df_initdn
	jz	short loc_1
	mov	gs:[enetreg.emacintmask],eax	; clear emac imr
	mov	gs:[enetreg.intmask],eax	; clear imr
	dec	eax
	mov	gs:[enetreg.emacintstatus],eax	; clear emac isr
	mov	gs:[enetreg.intstatus],eax	; clear isr
loc_1:
	call	_sbpciSetup
	cmp	ax,SUCCESS
;	jnz	short loc_ex
	jnz	near ptr loc_ex

	call	_chipReset
	cmp	ax,SUCCESS
;	jnz	short loc_ex
	jnz	near ptr loc_ex

	xor	eax,eax				; clear int status again
	mov	gs:[enetreg.emacintmask],eax	; clear emac imr
	mov	gs:[enetreg.intmask],eax	; clear imr
	dec	eax
	mov	gs:[enetreg.emacintstatus],eax	; clear emac isr
	mov	gs:[enetreg.intstatus],eax	; clear isr

	mov	ecx,gs:[enetreg.eeprom][4ch]
	mov	edx,gs:[enetreg.eeprom][50h]
	mov	eax,gs:[enetreg.eeprom][58h]

	xchg	dl,dh		; 3 2
	mov	[bp-4],dx
	shr	ecx,16		; 0 1
	shr	edx,16		; 4 5
	shr	eax,16
	xchg	cl,ch		; 1 0
	xchg	dl,dh		; 5 4
	and	ax,1fh			; phy address
	mov	[bp-6],cx
	mov	[bp-2],dx
	mov	[PhyInfo.Phyaddr],ax

	push	offset semFlt
	call	_EnterCrit
	mov	ax,[bp-6]		; 0 1
	mov	cx,[bp-4]		; 2 3
	mov	dx,[bp-2]		; 4 5
	mov	word ptr MacChar.mctpsa,ax	; parmanent
	mov	word ptr MacChar.mctpsa[2],cx
	mov	word ptr MacChar.mctpsa[4],dx
;	mov	word ptr MacChar.mctcsa,ax	; current
;	mov	word ptr MacChar.mctcsa[2],cx
;	mov	word ptr MacChar.mctcsa[4],dx
	mov	word ptr MacChar.mctVendorCode,ax ; vendor
	mov	byte ptr MacChar.mctVendorCode[2],cl
	call	_LeaveCrit
;	pop	ax	; stack adjust

	call	_hwClearStat		; clear statistics
	call	_hwSetMACaddr		; update Cam Index 0
	call	_hwUpdateMulticast	; update Cam Index 1..63
	call	_hwUpdatePktFlt		; update packet filter mode

	call	_ResetPhy
loc_ex:
	leave
	retn
_hwReset	endp

_chipReset	proc	near
	push	3
	test	[drvflags],mask df_initdn
	jz	short loc_5			; skip emac disable

	mov	gs:[enetreg.enetcontrol],EC_ED	; disable emac
	mov	cx,200
loc_1:
	call	__IODelayCnt
	mov	eax,gs:[enetreg.enetcontrol]
	test	al,EC_ED			; wait for EC_ED clear
	jz	short loc_2
	dec	cx
	jnz	short loc_1

loc_2:
	mov	gs:[enetreg.dmaregs.xmtcontrol],0	; reset tx
	mov	cx,100
loc_3:
	mov	eax,gs:[enetreg.dmaregs.rcvstatus]
	and	eax,RS_RE_MASK
	jz	short loc_4		; rx stopped
	cmp	eax,RS_RS_IDLE
	jz	short loc_4		; rx idle
	call	__IODelayCnt
	dec	cx
	jnz	short loc_3
loc_4:
	mov	gs:[enetreg.dmaregs.rcvcontrol],0	; reset rx
	mov	gs:[enetreg.enetcontrol],EC_ES		; soft reset
loc_5:
	call	_coreReset

		; set mdio clock. 4402 has 62.5MHz SB clock
	mov	gs:[enetreg.mdiocontrol],MC_PE or 0dh	; 208ns? 400ns/2??

	mov	eax,gs:[enetreg.devcontrol]
	test	eax,DC_IP
	jz	short loc_7			; external PHY
	test	eax,DC_ER
	jz	short loc_8
	and	eax,not DC_ER
	mov	gs:[enetreg.devcontrol],eax	; clear ephy reset

	mov	cx,100
loc_6:
	call	__IODelayCnt
	dec	cx
	jnz	short loc_6

	jmp	short loc_8
loc_7:
	mov	gs:[enetreg.enetcontrol],EC_EP	; select external PHY
loc_8:
	pop	cx	; stack adjust

	xor	eax,eax
	mov	al,EMC_CG or EMC_LC_MASK	; enable crc32 generation, set LED modes.
	mov	gs:[enetreg.emaccontrol],eax
	mov	al,[cfgTxWaterMark]
	mov	gs:[enetreg.txwatermark],eax	; tx watermark
	mov	ax,[cfgTxMXBurst]
	mov	gs:[enetreg.emactxmaxburstlen],eax ; tx max burst len
	mov	ax,[cfgRxMXBurst]
	mov	gs:[enetreg.emacrxmaxburstlen],eax ; rx max burst len
	mov	ax,[cfgMAXFRAMESIZE]
	add	ax,4				; append fcs
	mov	gs:[enetreg.rxmaxlength],eax	; max rx frame length
	mov	gs:[enetreg.txmaxlength],eax	; max tx frame length
	mov	eax,[cfgIntRecvLazy]
	mov	gs:[enetreg.intrecvlazy],eax

	mov	ax,SUCCESS
	retn
_chipReset	endp

_coreReset	proc	near
	call	_coreDisable

	mov	gs:[enetreg.sbconfig.sbtmstatelow],\
		  SBTML_FGC or SBTML_CLK or SBTML_RESET
	mov	eax,gs:[enetreg.sbconfig.sbtmstatelow] ; dummy

			; PR3158 workaroud
	mov	eax,gs:[enetreg.sbconfig.sbtmstatehigh]
	test	al,SBTMH_SERR
	jz	short loc_1
	xor	eax,eax
	mov	gs:[enetreg.sbconfig.sbtmstatehigh],eax
loc_1:
	mov	eax,gs:[enetreg.sbconfig.sbimstate]
	test	eax,SBIM_IBE or SBIM_TO
	jz	short loc_2
	and	eax,not (SBIM_IBE or SBIM_TO)
	mov	gs:[enetreg.sbconfig.sbimstate],eax

loc_2:
	mov	gs:[enetreg.sbconfig.sbtmstatelow],\
		  SBTML_FGC or SBTML_CLK ; clear reset and force clock
	mov	eax,gs:[enetreg.sbconfig.sbtmstatelow] ; dummy
	mov	gs:[enetreg.sbconfig.sbtmstatelow],\
		  SBTML_CLK		; leave clock enable
	mov	eax,gs:[enetreg.sbconfig.sbtmstatelow] ; dummy

	mov	ax,SUCCESS
	retn
_coreReset	endp

_coreDisable	proc	near
	mov	eax,gs:[enetreg.sbconfig.sbtmstatelow]
	test	al,SBTML_RESET		; core is already in reset
	jnz	short loc_6
	mov	gs:[enetreg.sbconfig.sbtmstatelow],\
		  SBTML_CLK or SBTML_REJ	; set the reject bit
	push	3
	mov	cx,1536
loc_1:
	call	__IODelayCnt
	mov	eax,gs:[enetreg.sbconfig.sbtmstatelow]
	test	al,SBTML_REJ		; spin until reject is set
	jnz	short loc_2
	dec	cx
	jnz	short loc_1
loc_2:
	mov	cx,1536
loc_3:
	call	__IODelayCnt
	mov	eax,gs:[enetreg.sbconfig.sbtmstatehigh]
	test	al,SBTMH_BUSY		; spin until busy is clear
	jz	short loc_4
	dec	cx
	jnz	short loc_3
loc_4:
	mov	gs:[enetreg.sbconfig.sbtmstatelow],\
		  SBTML_FGC or SBTML_CLK or SBTML_REJ or SBTML_RESET
	mov	eax,gs:[enetreg.sbconfig.sbtmstatelow]	; dummy

	mov	cx,10
loc_5:
	call	__IODelayCnt
	dec	cx
	jnz	short loc_5

	mov	gs:[enetreg.sbconfig.sbtmstatelow],\
		  SBTML_REJ or SBTML_RESET
	call	__IODelayCnt
	pop	cx	; stack adjust
loc_6:
	mov	ax,SUCCESS
	retn
_coreDisable	endp


_sbpciSetup	proc	near
	enter	6,0
			; read current core id before BAR0_WIN access
	mov	eax,gs:[enetreg.sbconfig.sbidhigh]
	shr	ax,4
	mov	[bp-6],ax		; backup core code
IF 0			; backup core code, 1st
	push	1
	push	440
	call	_Beep
	add	sp,2*2
ENDIF

	push	word ptr PCI_BAR0_WIN
	push	[BusDevFunc]
	call	_pci0ReadD
;	add	sp,2*2
	mov	[bp-4],ax		; backup chip core selector
	mov	[bp-2],dx		; backup
IF 0			; backup current core selector, 2nd
	push	1
	push	494
	call	_Beep
	add	sp,2*2
ENDIF

	push	word ptr highword SBID_REG_PCI
	push	word ptr lowword SBID_REG_PCI
	push	word ptr PCI_BAR0_WIN
	push	[BusDevFunc]
	call	_pci0WriteD		; select PCI core
;	add	sp,4*2
IF 0			; select pci core, 3rd
	push	1
	push	554
	call	_Beep
	add	sp,2*2
ENDIF

			; wait for PCI core selection
	push	word ptr SB_PCI
	call	_sbcoreCheck
;	add	sp,2
	cmp	ax,SUCCESS
	jnz	short loc_ex

IF 0			; pci core selection complete, 4th
	push	1
	push	587
	call	_Beep
	add	sp,2*2
ENDIF
			; eneble sb->pci interrupts
	or	gs:[sbpcireg.sbconfig.sbintvec],SBIV_ENET0
			; enable prefetch and burst for sb->pci translation 2
	or	gs:[sbpcireg.sbtopci2],SBTOPCI_PREF or SBTOPCI_BURST

IF 0			; pci core setup complete, 5th
	push	1
	push	659
	call	_Beep
	add	sp,2*2
ENDIF
	mov	ax,[bp-4]
	mov	cx,[bp-2]
	mov	dx,[BusDevFunc]
	push	cx
	push	ax
	push	word ptr PCI_BAR0_WIN
	push	dx
	call	_pci0WriteD		; restore
;	add	sp,4*2
IF 0			; restore core selector, 6th
	push	1
	push	740
	call	_Beep
	add	sp,2*2
ENDIF

	push	word ptr [bp-6]
	call	_sbcoreCheck
;	add	sp,2
IF 0			; restore core selector complete, 7th
	push	1
	push	831
	call	_Beep
	add	sp,2*2
ENDIF

;	mov	ax,SUCCESS
loc_ex:
	leave
	retn
_sbpciSetup	endp


_sbcoreCheck	proc	near
	push	bp
	mov	bp,sp

	mov	cx,10h
	push	2
loc_1:
	mov	eax,gs:[enetreg.sbconfig.sbidhigh]
	shr	ax,4
	cmp	ax,[bp+4]
	jz	short loc_2
	call	__IODelayCnt
	dec	cx
	jnz	short loc_1
	mov	ax,HARDWARE_FAILURE
	leave
	retn
loc_2:
	mov	ax,SUCCESS
	leave
	retn
_sbcoreCheck	endp

; USHORT miiRead( UCHAR phyaddr, UCHAR phyreg)
_miiRead	proc	near
	push	bp
	mov	bp,sp
	push	offset semMii
	call	_EnterCrit

	mov	gs:[enetreg.emacintstatus],EI_MII	; clear mii_int

	mov	ax,[bp+4]	; phyaddr
	mov	cx,[bp+6]	; phyreg
	and	ax,1fh
	shl	cx,2
	shl	ax,2+5
	and	cx,1fh shl 2
	or	ax,(0110b shl (2+5+5)) or 10b	; start/read/ta
	or	ax,cx
	shl	eax,16
	mov	gs:[enetreg.mdiodata],eax

	mov	cx,100h
	push	2
loc_1:
	call	__IODelayCnt
	mov	eax,gs:[enetreg.emacintstatus]
	test	al,EI_MII
	jnz	short loc_2
	dec	cx
	jnz	short loc_1
loc_2:
	pop	cx	; stack adjust
	mov	eax,gs:[enetreg.mdiodata]

	call	_LeaveCrit
	pop	cx	; stack adjust
	pop	bp
	retn
_miiRead	endp

; VOID miiWrite( UCHAR phyaddr, UCHAR phyreg, USHORT value)
_miiWrite	proc	near
	push	bp
	mov	bp,sp
	push	offset semMii
	call	_EnterCrit

	mov	gs:[enetreg.emacintstatus],EI_MII	; clear mii_int

	mov	ax,[bp+4]	; phyaddr
	mov	dx,[bp+6]	; phyreg
	and	ax,1fh
	shl	dx,2
	shl	ax,2+5
	and	dx,1fh shl 2
	or	ax,(0101b shl (2+5+5)) or 10b	; start/write/ta
	or	ax,dx
	shl	eax,16
	mov	ax,[bp+8]
	mov	gs:[enetreg.mdiodata],eax

	mov	cx,100h
	push	2
loc_1:
	call	__IODelayCnt
	mov	eax,gs:[enetreg.emacintstatus]
	test	al,EI_MII
	jnz	short loc_2
	dec	cx
	jnz	short loc_1
loc_2:
	pop	cx	; stack adjust
	call	_LeaveCrit
	leave
	retn
_miiWrite	endp

; VOID miiReset( VOID )
_miiReset	proc	near
	push	offset semMii
	call	_EnterCrit

	mov	gs:[enetreg.emacintstatus],EI_MII	; clear mii_int
	mov	gs:[enetreg.mdiodata],-1	; 32bits 1

	mov	cx,100h
	push	2
loc_1:
	call	__IODelayCnt
	mov	eax,gs:[enetreg.emacintstatus]
	test	al,EI_MII
	jnz	short loc_2	; done
	dec	cx
	jnz	short loc_1	; timeout
loc_2:
	pop	cx	; stack adjust

	call	_LeaveCrit
	pop	cx	; stack adjust
	retn
_miiReset	endp


_TEXT	ends
end
