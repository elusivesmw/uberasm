;
; Debug features
; by elusive
; Warp to previous level with L and next level with R.
; Press L or R multiple times to skip more levels. After input stops, the warp will happen.
; Statusbar features require Super Status Bar patch (https://www.smwcentral.net/?p=section&a=details&id=19247)
;


; COPIED FROM GPS DEFINES
; Checks the current LM version, if it is bigger or equal to <version> it will set <define> to 1, other 0
; Also sets !lm_version to the last used version number. e.g. 1.52 would return 152 (dec)
macro assert_lm_version(version, define)
	!lm_version #= ((read1($0FF0B4)-'0')*100)+((read1($0FF0B6)-'0')*10)+(read1($0FF0B7)-'0')
	if !lm_version >= <version>
		!<define> = 1
	else
		!<define> = 0
	endif
endmacro

%assert_lm_version(257, "EXLEVEL") ; Ex level support

; settings
!TimeTilWarp = $60

; RAM
!RAM_CurrentLevelNum = $010B|!addr
!RAM_SoundEffect = $1DFC|!addr

!FreeRAM                = $7FA200
!RAM_WarpLevelNum       = !FreeRAM
!RAM_WarpLevelTimer     = !FreeRAM+2

; Statusbar RAM
!ShowRoomInStatusbar    = 1
!RAM_RoomStart          = $7FA000
!RAM_RoomBit100         = !RAM_RoomStart
!RAM_RoomBit010         = !RAM_RoomStart+2
!RAM_RoomBit001         = !RAM_RoomStart+4


init:
    LDA #$00                    ; clear warp timer
    STA !RAM_WarpLevelTimer

    REP #$20                    ; init warp level with current level num
    LDA !RAM_CurrentLevelNum
    STA !RAM_WarpLevelNum
    SEP #$20

    JMP DrawHud                 ; draw hud


main:
    LDA !RAM_WarpLevelTimer     ; if timer != 0
    BNE .input                  ; else timer-- and check for input

    LDA !RAM_CurrentLevelNum    ; else compare level data
    CMP !RAM_WarpLevelNum       ;

    BEQ .input                  ; if levels are different,
    JMP Warp                    ; warp

.input
    DEC                         ; timer--
    STA !RAM_WarpLevelTimer

                                ; and check for button presses
    LDA $18                     ; axlr---- pressed on this frame
    BIT #$20                    ; 001000000 (L) pressed on this frame
    BNE .prev

    LDA $18                     ; axlr---- pressed on this frame
    BIT #$10                    ; 000100000 (R) pressed on this frame
    BNE .next

    JMP Return                  ; no press, return

.prev
    REP #$20                    ; 16 bit A
    LDA !RAM_WarpLevelNum       ; warp level
    DEC                         ; previous level
    BPL +                       ; dont go below level 000

    SEP #$20                    ; 8 bit A
    LDA #$2A                    ; wrong sound
    STA !RAM_SoundEffect        ; play sound
    JMP Return
+
    STA !RAM_WarpLevelNum       ; store in free RAM
    SEP #$20                    ; 8 bit A
    
    LDA.b #!TimeTilWarp         ; reset timer
    STA !RAM_WarpLevelTimer
    
    JMP DrawHud                 ; draw hud
    
.next
    REP #$20                    ; 16 bit A
    LDA !RAM_WarpLevelNum       ; warp level
    INC                         ; next level
    CMP #$200
    BCC +                       ; dont go above level 1FF

    SEP #$20                    ; 8 bit A
    LDA #$2A                    ; wrong sound
    STA !RAM_SoundEffect        ; play sound
    JMP Return
+

    STA !RAM_WarpLevelNum       ; store in free RAM
    SEP #$20                    ; 8 bit A
    
    LDA.b #!TimeTilWarp         ; reset timer
    STA !RAM_WarpLevelTimer
    
    JMP DrawHud                 ; draw hu

Warp:
if !EXLEVEL
    JSL $03BCDC|!bank           ;> get screen number from LM hijack, and put in X
else
    LDA $5B                     ;\
    AND #$01                    ;|
    ASL                         ;| manually get screen number
    TAX                         ;|
    LDA $95,x                   ;|
    TAX                         ;/
endif

    LDA !RAM_WarpLevelNum       ;\ 
    STA $19B8|!addr,x           ;| restore level from free RAM into current screen exit
    LDA !RAM_WarpLevelNum+1     ;|
    ORA #$04                    ;| set level table flag w bit HHHHwush
    STA $19D8|!addr,x           ;/
    
    LDA #$06                    ;\
    STA $71                     ;| do teleport
    STZ $88                     ;|
    STZ $89                     ;/
    JMP Return

DrawHud:
if !ShowRoomInStatusbar
    LDA !RAM_WarpLevelNum+1
    AND #$01
    STA !RAM_RoomBit100
    LDA #$38
    STA !RAM_RoomBit100+1

    LDA !RAM_WarpLevelNum
    AND #$F0
    LSR #4
    STA !RAM_RoomBit010
    LDA #$38
    STA !RAM_RoomBit010+1

    LDA !RAM_WarpLevelNum
    AND #$0F
    STA !RAM_RoomBit001
    LDA #$38
    STA !RAM_RoomBit001+1
endif

Return:
    RTL