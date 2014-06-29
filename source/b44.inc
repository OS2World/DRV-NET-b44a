
;/******************************************************************************/
;/*                                                                            */
;/* Broadcom BCM4400 Linux Network Driver, Copyright (c) 2002 Broadcom         */
;/* Corporation.                                                               */
;/* All rights reserved.                                                       */
;/*                                                                            */
;/* This program is free software; you can redistribute it and/or modify       */
;/* it under the terms of the GNU General Public License as published by       */
;/* the Free Software Foundation, located in the file LICENSE.                 */
;/*                                                                            */
;/* History:                                                                   */
;/*                                                                            */
;/******************************************************************************/

; --- Each DMA processor consists of a transmit channel and a receive channel.
dmaregs_t	struc
				; --- transmit channel ---
xmtcontrol	dd	?	; enable, et al.
xmtaddr		dd	?	; descriptor ring base address(4k aligned)
xmtptr		dd	?	; last descriptor posted to chip
xmtstatus	dd	?	; current active descriptor, et al.
				; --- receive channel ---
rcvcontrol	dd	?	; enable, et al.
rcvaddr		dd	?	; descriptor ring base address(4K aligned)
rcvptr		dd	?	; last descriptor posted to chip
rcvstatus	dd	?	; chrrent active descriptor, et al
				; --- diag access ---
fifoaddr	dd	?	; diag address
fifodatalow	dd	?	; low 32bits of data
fifodatahigh	dd	?	; high 32bits of data
		dd	?	; reserved
dmaregs_t	ends

; --- transmit channel control ---
XC_XE		equ	 1	; transmit enable
XC_SE		equ	 2	; transmit suspend request
XC_LE		equ	 4	; loopback enable
XC_FPRI		equ	 8	; fair priority
XC_FL		equ	10h	; flush request

; --- transmit descriptor table pointer ---
XP_LD_MASK	equ	0fffh	; last valid descriptor(8*[0..1ff])

; --- transmit channel status ---
XS_CD_MASK	equ	  0fffh	; current descriptor pointer(mask)
XS_XS_MASK	equ	 0f000h	; transmit state(mask)
XS_XE_MASK	equ	0f0000h	; transmit errors(mask)
XS_FL		equ	100000h	; flushed

XS_XS_DISABLED	equ	 0000h	; disabled
XS_XS_ACTIVE	equ	 1000h	; active
XS_XS_IDLE	equ	 2000h	; idle wait
XS_XS_STOPPED	equ	 3000h	; stopped
XS_XS_SUSP	equ	 4000h	; suspend pending

XS_XE_NOERR	equ	00000h	; no error
XS_XE_DPE	equ	10000h	; descriptor protocol error
XS_XE_DFU	equ	20000h	; data fifo underrun
XS_XE_BEBR	equ	30000h	; bus error on buffer read
XS_XE_BEDA	equ	40000h	; bus error on descriptor access

; --- receive channel control ---
RC_RE		equ	  1	; receive enable
RC_RO_MASK	equ	0feh	; receive frame offset (mask)

; --- receive descriptor table pointer ---
RP_LD_MASK	equ	0fffh	; last valid descriptor (mask)

; --- receive channel status ---
RS_CD_MASK	equ	  0fffh	; current descriptor pointer(mask)
RS_RS_MASK	equ	 0f000h	; receive status (mask)
RS_RE_MASK	equ	0f0000h	; receive erroris (mask)

RS_RS_DISABLED	equ	  0000h	; disabled
RS_RS_ACTIVE	equ	  1000h	; active
RS_RS_IDLE	equ	  2000h	; idle wati
RS_RS_STOPPED	equ	  3000h	; reserved?

RS_RE_NOERR	equ	 00000h	; no error
RS_RE_DPE	equ	 10000h	; descriptor protocol error
RS_RE_DFO	equ	 20000h	; data fifo overflow
RS_RE_BEBW	equ	 30000h	; bus error on buffer write
RS_RE_BEDA	equ	 40000h	; bus error on descriptor access

; --- fifoaddr ---
FA_OFF_MASK	equ	 0ffffh	; offset (mask)
FA_SEL_MASK	equ	0f0000h	; select (mask)

FA_SEL_XDD	equ	 00000h	; transmit dma data
FA_SEL_XDP	equ	 10000h	; transmit dma pointers
FA_SEL_RDD	equ	 40000h	; receive dma data
FA_SEL_RDP	equ	 50000h	; receive dma pointers
FA_SEL_XFD	equ	 80000h	; transmit fifo data
FA_SEL_XFP	equ	 90000h	; transmit fifo pointers
FA_SEL_RFD	equ	0c0000h	; receive fifo data
FA_SEL_RFP	equ	0d0000h	; receive fifo pointers


; --- PCI config space ---
PCI_BAR0_WIN		equ	80h	; chip core selector?
PCI_BAR1_WIN		equ	84h	; ?
PCI_SPROM_CONTROL	equ	88h	; ?
PCI_BAR1_CONTROL	equ	8ch	; ?

SBID_REG_EMAC	equ	18000000h	; emac core
SBID_REG_CODEC	equ	18001000h	; v90 codec core
SBID_REG_PCI	equ	18002000h	; PCI core
SBID_PCI_DMD	equ	40000000h	; Client Mode PCI DMA? (within 1G)
BCM4710_PCI_DMA	equ	40000000h

; --- PCI config space "back door" access register ---
BCMNET_BACK_DOOR_ADDR	equ	0a0h
BCMNET_BACK_DOOR_DATA	equ	0a4h


; --- EMAC MIB registers ---
bcmenetmib_t	struc
tx_good_octets		dd	?
tx_good_pkts		dd	?
tx_octets		dd	?
tx_pkts			dd	?
tx_broadcast_pkts	dd	?
tx_multicast_pkts	dd	?
tx_len_64		dd	?
tx_len_65_to_127	dd	?
tx_len_128_to_255	dd	?
tx_len_256_to_511	dd	?
tx_len_512_to_1023	dd	?
tx_len_1024_to_max	dd	?
tx_jabber_pkts		dd	?
tx_oversize_pkts	dd	?
tx_fragment_pkts	dd	?
tx_underruns		dd	?
tx_total_cols		dd	?
tx_single_cols		dd	?
tx_multiple_cols	dd	?
tx_excessive_cols	dd	?
tx_late_cols		dd	?
tx_defered		dd	?
tx_carrier_lost		dd	?
tx_pause_pkts		dd	?
			dd	8 dup(?)

rx_good_octets		dd	?
rx_good_pkts		dd	?
rx_octets		dd	?
rx_pkts			dd	?
rx_broadcast_pkts	dd	?
rx_multicast_pkts	dd	?
rx_len_64		dd	?
rx_len_65_to_127	dd	?
rx_len_128_to_255	dd	?
rx_len_256_to_511	dd	?
rx_len_512_to_1023	dd	?
rx_len_1024_to_max	dd	?
rx_jabber_pkts		dd	?
rx_oversize_pkts	dd	?
rx_fragment_pkts	dd	?
rx_missed_pkts		dd	?
rx_crc_align_errs	dd	?
rx_undersize		dd	?
rx_crc_errs		dd	?
rx_align_errs		dd	?
rx_symbol_errs		dd	?
rx_pause_pkts		dd	?
rx_nonpause_pkts	dd	?
bcmenetmib_t	ends

; --- Sonics Configuration Space registers ---
sbconfig_t	struc
		dd	2 dup(?)
sbipsflag	dd	?	; initiator port ocp slave flag
		dd	3 dup(?)
sbtpsflag	dd	?	; target port ocp slave flag
		dd	17 dup(?)
sbadmatch3	dd	?	; address match 3
		dd	?
sbadmatch2	dd	?	; address match 2
		dd	?
sbadmatch1	dd	?	; address match 1
		dd	7 dup(?)
sbimstate	dd	?	; initiator agent state
sbintvec	dd	?	; interrupt mask
sbtmstatelow	dd	?	; target state low
sbtmstatehigh	dd	?	; target state high
sbbwa0		dd	?	; bandwidth allocation table0
		dd	?
sbimconfiglow	dd	?	; initiator configuration low
sbimconfighigh	dd	?	; initiator configuration high
sbadmatch0	dd	?	; address match 0
		dd	?
sbtmconfiglow	dd	?	; target configuration low
sbtmconfighigh	dd	?	; target configuration high
sbbconfig	dd	?	; broadcast configuration
		dd	?
sbbstate	dd	?	; broadcast state
		dd	3 dup(?)
sbactcnfg	dd	?	; activate configuration
		dd	3 dup(?)
sbflagst	dd	?	; current sbflags
		dd	3 dup(?)
sbidlow		dd	?	; identification low
sbidhigh	dd	?	; identification high
sbconfig_t	ends

; --- initiator port ocp slave flag --
				; which sbflags get routed to mips 
SBIP_INT1_MASK	equ	     3fh	; interrupt 1
SBIP_INT2_MASK	equ	    3f00h	; interrupt 2
SBIP_INT3_MASK	equ	  3f0000h	; interrupt 3
SBIP_INT4_MASK	equ	3f000000h	; interrupt 4

; --- target port ocp slave flag ---
SBTPS_NUM0_MASK	equ	3fh	; interrupt sbFlag Num generated by this core
SBTPS_F0EN0	equ	40h	; interrupt is always sent on the backplane

; --- initiator agent state ---
SBIM_PC		equ	   0fh	; pipecount
SBIM_AP_MASK	equ	   30h	; arbitration policy
SBIM_IBE	equ	20000h	; inbanderror
SBIM_TO		equ	40000h	; timeout

SBIM_AP_BOTH	equ	   00h	; use both timeslices and token
SBIM_AP_TS	equ	   10h	; use timeslices only
SBIM_AP_TK	equ	   20h	; use token only

; --- interrupt mask ---
SBIV_PCI	equ	 1	; enable interrupts for pci
SBIV_ENET0	equ	 2	; enable interrupts for enet 0
SBIV_ILINE20	equ	 4	; enable interrupts for iline20
SBIV_CODEC	equ	 8	; enable interrupts for v90 codec
SBIV_USB	equ	10h	; enable interrupts for usb
SBIV_EXTIF	equ	20h	; enable interrupts for external if
SBIV_ENET1	equ	40h	; enable interrupts for enet 1

; --- target state low ---
SBTML_RESET	equ	       1	; reset
SBTML_REJ	equ	       2	; reject
SBTML_CLK	equ	   10000h	; clock enable
SBTML_FGC	equ	   20000h	; force gated clocks on
SBTML_PE	equ	40000000h	; pme enable
SBTML_BE	equ	80000000h	; bist enbale

; --- target state high ---
SBTMH_SERR	equ	       1	; serror
SBTMH_INT	equ	       2	; interrupt
SBTMH_BUSY	equ	       4	; busy
SBTMH_GCR	equ	20000000h	; gated clock request
SBTMH_BISTF	equ	40000000h	; bist failed
SBTMH_BISTD	equ	80000000h	; bist done

; --- bandwidth allocation 0 ---
SBBWA_TAB0_MASK	equ	    0ffffh	; lookup table 0
SBBWA_TAB1_MASK	equ	0ffff0000h	: lookup table 1

; --- initiator configuration low ---
SBIMCL_STO_MASK	equ	      3		; service timeout
SBIMCL_RTO_MASK	equ	     30h	; request timeout
SBIMCL_CID_MASK	equ	0ff0000h	; connection id

; --- initiator configuration high ---
SBIMCH_IEM_MASK	equ	 0ch	; inband error mode
SBIMCH_TEM_MASK	equ	 30h	; timeout error mode
SBIMCH_BEM_MASK	equ	0c0h	; bus error mode

; --- address match 0 ---
SBAM_TYPE_MASK	equ	  3	; address type
SBAM_AD64	equ	  4	; reserved
SBAM_ADINT0_MASK equ	0f8h	; type 0 size (mask)
SBAM_ADINT1_MASK equ	1f8h	; type 1 size (mask)
SBAM_ADINT2_MASK equ	1f8h	; type 2 size (mask) 3f8h?
SBAM_ADEN	equ	400h	; enable
SBAN_ADNEG	equ	800h	; negative decode
SBAN_BASE0_MASK	equ	0ffffff00h	; type0 base address
SBAN_BASE1_MASK	equ	0fffff000h	; type1 base address
SBAN_BASE2_MASK	equ	0ffff0000h	; type2 base address

; --- target configuration low ---
SBTMCL_CD_MASK	equ	    0ffh	; clock divide
SMTMCL_CO_MASK	equ	  0f800h	; clock offset
SBTMCL_IF_MASK	equ	0fc0000h	; interrupt flags
SBTMCL_IM_MASK	equ	3000000h	; interrupt mode

; --- target configuration high ---
SBTMCH_BM_MASK	equ	   3	; bus mode
SBTMCH_RM_MASK	equ	  0ch	; retry mode
SBTMCH_SM_MASK	equ	  30h	; stop mode
SBTMCH_EM_MASK	equ	 300h	; sb error mode
SBTMCH_IM_MASK	equ	0c00h	; int mode

; --- broadcast configuration ---
SBBC_LAT_MASK	equ	      3		; sb latency
SBBC_MAX0_MASK	equ	 0f0000h	; maxccntr0
SBBC_MAX1_MASK	equ	0f00000h	; maxccntr1

; --- broadcast state ---
SBBS_SRD	equ	1	; st reg disable
SBBS_HRD	equ	2	; hold reg disable

; --- identification low ---
SBIDL_CS_MASK	equ	       3	; config space
SBIDL_AR_MASK	equ	      38h	; # address ranges supported
SBIDL_SYNCH	equ	      40h	; sync
SBIDL_INIT	equ	      80h	; initiator
SBIDL_MINLAT_MASK equ	    0f00h	; minimum backplane latency
SBIDL_MAXLAT_MASK equ	   0f000h	; maximum backplane latency
SBIDL_FIRST	equ	   10000h	; this initiator is first
SBIDL_CW_MASK	equ	 0c0000h	; cycle counter width
SBIDL_TP_MASK	equ	 0f00000h	; target ports
SBIDL_IP_MASK	equ	0f000000h	; initiator ports

; --- identification high ---
SBIDH_RC_MASK	equ	       0fh	; revision code (mask)
SBIDH_CC_MASK	equ	    0fff0h	; core code
SBIDH_VC_MASK	equ	0ffff0000h	; vendor code

; +++ core code +++
SB_ILINE20	equ	801h	; iline20 core
SB_SDRAM	equ	803h	; sdram core
SB_PCI		equ	804h	; pci core
SB_MIPS		equ	805h	; mips core
SB_ENET		equ	806h	; enet mac core
SB_CODEC	equ	807h	; v90 codec core
SB_USB		equ	808h	; iline100 core
SB_ILINE100	equ	80ah	; iline100 core
SB_EXTIF	equ	811h	; external interface core

; --- host interface registers ---
bcmenetregs	struc
			; --- device and power control ---
devcontrol	dd	?	; 
		dd	2 dup(?)
biststatus	dd	?	; 
wakeuplength	dd	?	; 
		dd	3 dup(?)
			; --- interrupt control ---
intstatus	dd	?	; 
intmask		dd	?	; 
gptimer		dd	?	; 4402 has 62.5MHz(16ns)??
		dd	23 dup(?)
			; --- ethernet mac address filtering control ---
enetaddrlo	dd	?	; added in B0
enetaddrhi	dd	?	; added in B0
enetftaddr	dd	?	; 
enetftdata	dd	?	; 
		dd	2 dup(?)
			; --- ethernet mac control ---
emactxmaxburstlen dd	?	; 
emacrxmaxburstlen dd	?	; 
emaccontrol	dd	?	; 
emacflowcontrol	dd	?	; 
		dd	20 dup(?)
			; --- DMA lazy interrupt control ---
intrecvlazy	dd	?	; 
		dd	63 dup(?)
			; --- DMA engine ---
dmaregs		dmaregs_t <>
	dd	116 dup(?)
			; --- EMAC registers ---
rxconfig	dd	?	; 
rxmaxlength	dd	?	; max 7ffh
txmaxlength	dd	?	; max 7ffh
		dd	?
mdiocontrol	dd	?	; 
mdiodata	dd	?	; 
emacintmask	dd	?	; 
emacintstatus	dd	?	; 
camdatalo	dd	?	; 
camdatahi	dd	?	; 
camcontrol	dd	?	; 
enetcontrol	dd	?	; 
txcontrol	dd	?	; 
txwatermark	dd	?	; max 3fh
mibcontrol	dd	?	; 
		dd	49 dup(?)
			; --- EMAC MIB counters ---
mib		bcmenetmib_t <>
		dd	585 dup(?)
			; --- Sonics SilliconBackplane config registers
sbconfig	sbconfig_t <>
			; --- EEPROM contents ---
eeprom		dd	32 dup(?)
bcmenetregs	ends

; --- device control ---
DC_MPM		equ	40h	; Magic Packet PME enable (B0)
DC_PM		equ	80h	; pattern filtering enable
DC_IP		equ	400h	; internal ehpy present
DC_ER		equ	8000h	; ephy reset
DC_MP		equ	10000h	; mii phy mode enable
DC_C0		equ	20000h	; mii phy mode: enable clocks
DC_PA_MASK	equ	7c0000h	; mii phy mode: mdc/mdio phy address

; --- wakeup length ---
WL_P0_MASK	equ	      7fh	; pattern 0
WL_D0		equ	      80h	; 
WL_P1_MASK	equ	    7f00h	; pattern 2
WL_D1		equ	    8000h	; 
WL_P2_MASK	equ	  7f0000h	; pattern 2
WL_D2		equ	  800000h	; 
WL_P3_MASK	equ	7f000000h	; pattern 3
WL_D3		equ	80000000h	; 

; --- intstatus and intmask ---
I_LS		equ	      20h	; link change (B0)
I_PME		equ	      40h	; power management event
I_TO		equ	      80h	; general purpose timeout
I_PC		equ	     400h	; descriptor error
I_PD		equ	     800h	; descriptor protocol error
I_DE		equ	    1000h	; data error
I_RU		equ	    2000h	; receive descriptor underflow
I_RO		equ	    4000h	; receive fifo overflow
I_XU		equ	    8000h	; transmit fifo underflow
I_RI		equ	   10000h	; receive interrupt
I_XI		equ	 1000000h	; transmit interrupt
I_EM		equ	 4000000h	; emac interrupt
I_MW		equ	 8000000h	; mii write
I_MR		equ	10000000h	; mii read

I_ERRORS	equ	I_PC or I_PD or I_DE or I_RU or I_RO or I_XU
I_RXS		equ	I_RU or I_RO or I_RI
I_TXS		equ	I_XU or I_XI

; --- address filter ---
; --- multicat hash table ---
;BCMNET_MCHASHBASE	equ	200h	; multicast hash filter base address
;BCMBET_MCHASHSIZE	equ	100h	; multicast hash filter size in byte

; --- power management event wakeup pattern constant ---
BCMNET_NPMP	equ	  4	; chip supports 4 wakeup patterns
BCMNET_PMPBASE	equ	400h	; wakeup pattern base address
BCMNET_PMPSIZE	equ	 80h	; 128bytes each pattern
BCMNET_PMMBASE	equ	600h	; wakeup mask base address
BCMNET_PMMSIZE	equ	 10h	; 128bits each mask

; --- emaccontrol ---
EMC_CG		equ	  1	; crc32 generation enable
EMC_EP		equ	  4	; onchip ephy: powerdown (rev >= 1)
EMC_ED		equ	  8	; onchip ephy: energy detected (rev >= 1)
EMC_LC_MASK	equ	0e0h	; onchip ephy; led control (rev >= 1)

; --- emacflowcontrol ---
EMF_RMH_MASK	equ	 0ffh	; rx fifo hi water mark (mask)
EMF_PG		equ	8000h	; enable pause frame generation

; --- interrupt receive lazy ---
IRL_TO_MASK	equ	  0ffffffh	; timeout
IRL_FC_MASK	equ	0ff000000h	; frame count

; --- emac receive config ---
ERC_DB		equ	 1	; disable broadcast
ERC_AM		equ	 2	; accept all multicast
ERC_RDT		equ	 4	; receive disable while transmitting
ERC_PE		equ	 8	; promiscuous enable
ERC_LE		equ	10h	; loopback enable
ERC_EF		equ	20h	; enable flow control
ERC_UF		equ	40h	; accept unicast flow control frame
ERC_RF		equ	80h	; reject filter

; --- emac mdio control ---
MC_MR_MASK	equ	7fh	; mdc frequency (mask)
MC_PE		equ	80h	; mii preamble enable

; --- emac mdio data ---
MD_DATA_MASK	equ	    0ffffh	; r/w data (mask)
MD_TA_MASK	equ	    30000h	; turnaround value (mask)
MD_RA_MASK	equ	   7c0000h	; register address (mask)
MD_PMD_MASK	equ	  f800000h	; physical media device (mask)
MD_OP_MASK	equ	 30000000h	; opcode (mask)
MD_SB_MASK	equ	0c0000000h	; start (mask)

; --- emac intstatus and intmask ---
EI_MII		equ	1	; mii mdio interrupt
EI_MIB		equ	2	; mib interrupt
EI_FLOW		equ	4	; flow control interrupt

; --- emac cam data high ---
CD_V		equ	10000h	; valid bit

; --- emac cam control ---
CC_CE		equ	       1	; cam enable
CC_MS		equ	       2	; mask select
CC_RD		equ	       4	; read
CC_WR		equ	       8	; write
CC_INDEX_MASK	equ	  3f0000h	; index
CC_CB		equ	80000000h	; cam busy

; --- emac ethernet control ---
EC_EE		equ	1	; emac enable
EC_ED		equ	2	; emac disable (self clear?)
EC_ES		equ	4	; emac soft reset
EC_EP		equ	8	; external phy select

; --- emac transmit control ---
EXC_FD		equ	1	; full duplex
EXC_FM		equ	2	; flowmode
EXC_SB		equ	4	; single backoff enable
EXC_SS		equ	8	; small slottime

; --- emac mib control ---
EMC_RZ		equ	1	; autoclear on read


; --- Sonics side: PCI core and host control registers ---
sbpciregs_t	struc
control		dd	?	; PCI control
		dd	3 dup(?)
arbcontrol	dd	?	; PCI arbiter control
		dd	3 dup(?)
intstatus	dd	?	; interrupt status
intmask		dd	?	; interrupt mask
sbtopcimailbox	dd	?	; Sonics to PCI mailbox
		dd	9 dup(?)
bcastaddr	dd	?	; Sonics broadcast address
bcastdata	dd	?	; Sonics broadcast data
		dd	42 dup(?)
sbtopci0	dd	?	; Sonics to PCI translation 0
sbtopci1	dd	?	; Sonics to PCI translation 1
sbtopci2	dd	?	; Sonics to PCI translation 2
		dd	445 dup(?)
sprom		dw	36 dup(?) ; SPROM shadow area
		dd	46 dup(?)
		dd	384 dup(?)
sbconfig	sbconfig_t <>
sbpciregs_t	ends

; --- PCI control ---
PCI_RST_OE	equ	1	; when set, drives PCI_RESET out to pin
PCI_RST		equ	2	; value driven out to pin
PCI_CLK_OE	equ	4	; when set, drives clock as gated by PCI_CLK out to pin
PCI_CLK		equ	8	; gate for clock driven out to pin

; --- PCI arbiter control ---
PCI_INT_ARB	equ	1	; when set, use an internal arbiter
PCI_EXT_ARB	equ	2	; when set. use an external arbiter
PCI_PARKID_MASK	equ	6	; selects which agent is parked on an idle bus

PCI_PARKID_LAST	equ	0	; last requester
PCI_PARKID_4710	equ	2	; 4710
PCI_PARKID_EXTREQ0 equ	4	; external requester 0
PCI_PARKID_EXTREQ1 equ	6	; external requester 1

; --- PCI interrupt status and mask ---
PCI_INTA	equ	 1	; PCI INTA# is asserted
PCI_INTB	equ	 2	; PCI INTB# is asserted
PCI_SERR	equ	 4	; PCI SERR# has been asserted
PCI_PERR	equ	 8	; PCI PERR# has been asserted
PCI_PME		equ	10h	; PCI PME# is asserted

; --- (general) PCI/SB mailbox interrupts, two bits per pci function ---
MAILBOX_F0_0	equ	 100h	; function 0, int 0
MAILBOX_F0_1	equ	 200h	; function 0, int 1
MAILBOX_F1_0	equ	 400h	; function 1, int 0
MAILBOX_F1_1	equ	 800h	; function 1, int 1
MAILBOX_F2_0	equ	1000h	; function 2, int 0
MAILBOX_F2_1	equ	2000h	; function 2, int 1
MAILBOX_F3_0	equ	4000h	; function 3, int 0
MAILBOX_F3_1	equ	8000h	; function 3, int 1

; --- Sonics broadcast address ---
BCAST_ADDR_MASK	equ	0ffh	; broadcast register address (mask)

; --- Sonics to PCI translation types ---
SBTOPCI0_MASK	equ	0fc000000h	; ?
SBTOPCI1_MASK	equ	0fc000000h	; ?
SBTOPCI2_MASK	equ	0c0000000h	; ?
SBTOPCI_MEM	equ	0
SBTOPCI_IO	equ	1
SBTOPCI_CFG0	equ	2
SBTOPCI_CFG1	equ	3
SBTOPCI_PREF	equ	4	; prefetch enable
SBTOPCI_BURST	equ	8	; burst enable


; --- DMA Descriptor ---
; Descriptors are only read by the hardware, never written back.
; Each descriptor ring must be 4096bytes aligned 
; and fit within a single 4096bytes page.
dmadd_t		struc
ctrl		dd	?	; misc control bits and bufcount
paddr		dd	?	; data buffer address
dmadd_t		ends

; --- control flags ---
CTRL_BC_MASK	equ	    1fffh	; buffer byte count (mask)
CTRL_CORE_MASK	equ	 ff00000h	; core-specific (mask)
CTRL_EOT	equ	10000000h	; end of descriptor table
CTRL_IOC	equ	20000000h	; interrupt on completion
CTRL_EOF	equ	40000000h	; end of frame
CTRL_SOF	equ	80000000h	; start of frame

; --- receive buffer header ---
; The Ethernet MAC core returns an 8-byte Receive Frame Data Header 
; with every frame consiting of 16bits of frame length, 
; followed by 16bits of EMAC rx descriptor info, 
; followed by 32bits of undefined. 
bcmenetrxh_t	struc
len		dw	?	; length of frame (valid in the last desc?)
flags		dw	?	; EMAC flags
		dd	6 dup(?) ; undefined
bcmenetrxh_t	ends

; --- receive buffer header flags ---
RXF_L		equ	800h	; last buffer in a frame
RXF_MISS	equ	 80h	; received due to promiscuous mode
RXF_BRDCAST	equ	 40h	; destination is broadcast address
RXF_MULT	equ	 20h	; destination is multicast address
RXF_LG		equ	 10h	; frame length > rxmaxlength
RXF_NO		equ	  8	; odd number of nibbles
RXF_RXER	equ	  4	; receive symbol error
RXF_CRC		equ	  2	; crc error
RXF_OV		equ	  1	; fifo overflow

; --- virtual transmit descriptor (for driver) ---
vtxd		struc
head		dw	?	; head descriptor of the frame
tail		dw	?	; tail descriptor of the frame
cnt		dw	?	; count of descriptor
reqhandle	dw	?	; request handle
protid		dw	?	; protocol id
vlink		dw	?	; next vtxd pointer
ImmedPhys	dd	?	; physical address of ImmedBuf
ImmedBuf	db	64 dup(?)	; reserved area for immediate data
vtxd		ends

; --- virtual receive descriptor (for driver) ---
vrxd		struc
vaddr		dd	?	; virtual address of buffer
rxd		dw	?	; virtual address of receive descriptor
vlink		dw	?	; next busy vrxd pointer
vrxd		ends
