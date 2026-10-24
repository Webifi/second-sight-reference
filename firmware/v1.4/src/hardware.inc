;; src/hardware.inc: names for the I/O ports. Included first.

;; ----------------------------------------------------------------------------------------
;; I/O ports. The Z180 reaches its own registers with IN0/OUT0 (I/O $00-$3F) and the
;; card's ports and the VGA chip with IN/OUT (C), where B holds the high address byte.
;; docs/reference/z180-io-ports.md has what each card port does.
;; ----------------------------------------------------------------------------------------
;; Z8S180 internal registers (Zilog UM0050)
CNTLA0          = 0x00              ; ASCI 0 control A
STAT0           = 0x04              ; ASCI 0 status
STAT1           = 0x05              ; ASCI 1 status
TDR0            = 0x06              ; ASCI 0 transmit data
CNTR            = 0x0A              ; CSI/O control
TCR             = 0x10              ; timer control
SAR0L           = 0x20              ; DMA 0 source address, low
SAR0H           = 0x21              ; DMA 0 source address, high
SAR0B           = 0x22              ; DMA 0 source address, bank (bits 19-16)
DAR0L           = 0x23              ; DMA 0 destination address, low
DAR0H           = 0x24              ; DMA 0 destination address, high
DAR0B           = 0x25              ; DMA 0 destination address, bank
BCR0L           = 0x26              ; DMA 0 byte count, low
BCR0H           = 0x27              ; DMA 0 byte count, high
MAR1L           = 0x28              ; DMA 1 memory address, low
MAR1H           = 0x29              ; DMA 1 memory address, high
MAR1B           = 0x2A              ; DMA 1 memory address, bank
IAR1L           = 0x2B              ; DMA 1 I/O address, low
IAR1H           = 0x2C              ; DMA 1 I/O address, high
BCR1L           = 0x2E              ; DMA 1 byte count, low
BCR1H           = 0x2F              ; DMA 1 byte count, high
DSTAT           = 0x30              ; DMA status (channel enables)
DMODE           = 0x31              ; DMA mode
DCNTL           = 0x32              ; DMA/WAIT control
ITC             = 0x34              ; INT/TRAP control (INT0-2 enables)
RCR             = 0x36              ; refresh control
CBR             = 0x38              ; MMU common base
BBR             = 0x39              ; MMU bank base
CBAR            = 0x3A              ; MMU common/bank area
;; The card's ports (decoded by U4 and the capture logic U7)
CARD_DATA       = 0xA0              ; read: the byte the IIgs wrote (latch U2); write: the byte the IIgs reads (latch U3); either acknowledges the event
CARD_CONFIG     = 0xA1              ; bit 2 COPY_INHIBIT, bit 3 MODE_D3 (IIgs mode)
BAND_FLAGS_LO   = 0xA4              ; read: which of $2000-$5FFF changed, one bit per 4 KB, then clear
BAND_FLAGS_HI   = 0xA5              ; read: which of $6000-$9FFF changed, one bit per 4 KB, then clear
EVENT_ADDR_LO   = 0xA6              ; read: bits 3-0 of the softswitch address of the event
EVENT_ADDR_HI   = 0xA7              ; read: bits 7-4 of the softswitch address ($B = a card register, $C0Bx)
CLOCK_VGA       = 0xA8              ; any access: pixel clock straight from the VGA chip (VGA monitor)
CLOCK_RGB       = 0xA9              ; any access: divided pixel clock (AppleColor RGB monitor)
LINEAR_OFF      = 0xAA              ; any access: clear the linear-window flag
LINEAR_ON       = 0xAB              ; any access: set the linear-window flag
APPLE_IRQ_OFF   = 0xAD              ; any access: release the Apple IRQ line
;; Oak OTI-087 VGA ports. A port with two names reads one register and writes another.
VGA_ENABLE          = 0x102         ; adapter enable (bit 0)
VGA_ATTR            = 0x3C0         ; attribute controller: index and data, written in turn
VGA_STATUS0         = 0x3C2         ; read: input status 0 (bit 4 = monitor sense)
VGA_MISC            = 0x3C2         ; write: miscellaneous output
VGA_SEQ_INDEX       = 0x3C4         ; sequencer index
VGA_SEQ_DATA        = 0x3C5         ; sequencer data
VGA_PEL_MASK        = 0x3C6         ; DAC pixel mask
VGA_DAC_STATE       = 0x3C7         ; read: DAC state
VGA_DAC_READ_INDEX  = 0x3C7         ; write: DAC read index
VGA_DAC_WRITE_INDEX = 0x3C8         ; DAC write index
VGA_DAC_DATA        = 0x3C9         ; DAC data: red, green, blue in turn
VGA_GC_INDEX        = 0x3CE         ; graphics controller index
VGA_GC_DATA         = 0x3CF         ; graphics controller data
VGA_CRTC_INDEX      = 0x3D4         ; CRT controller index
VGA_CRTC_DATA       = 0x3D5         ; CRT controller data
VGA_STATUS1         = 0x3DA         ; read: input status 1 (also resets the attribute index/data toggle)
VGA_FEATURE         = 0x3DA         ; write: feature control
OAK_INDEX           = 0x3DE         ; Oak extended register index
OAK_DATA            = 0x3DF         ; Oak extended register data
VGA_SETUP           = 0x46E8        ; adapter setup (enables port $102)
