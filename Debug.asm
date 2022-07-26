;
; Debug stuff
; by elusive
; Warp to previous level with L and next level with R
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



; RAM
!RAM_CurrentLevelNum = $010B|!addr
!RAM_SoundEffect = $1DFC|!addr

; SCRATCH
!SCRATCH_ExitTable1 = $7FA260
!SCRATCH_ExitTable2 = $7FA261



main:


; check for button presses
    LDA.b $18                   ; axlr---- pressed on this frame
    BIT #$20                    ; 001000000 (L) pressed on this frame
    BNE .prev

    LDA.b $18                   ; axlr---- pressed on this frame
    BIT #$10                    ; 000100000 (R) pressed on this frame
    BNE .next

    JMP Return                  ; no press, return



.prev
    REP #$20                    ; 16 bit A
    LDA.w !RAM_CurrentLevelNum  ; current level
    DEC                         ; previous level
    BPL +

    SEP #$20                    ; 8 bit A
    LDA #$2A                    ; wrong sound
    STA !RAM_SoundEffect        ; play sound
    JMP Return
+
    ORA #$0400                  ; set level table flag w bit HHHHwush
    STA $00                     ; store in scratch $00-$01
    SEP #$20                    ; 8 bit A
    JMP Warp
    
.next
    REP #$20                    ; 16 bit A
    LDA.w !RAM_CurrentLevelNum  ; current level
    INC                         ; next level
    CMP #$200
    BCC +

    SEP #$20                    ; 8 bit A
    LDA #$2A                    ; wrong sound
    STA !RAM_SoundEffect        ; play sound
    JMP Return
+
    ORA #$0400                  ; set level table flag w bit HHHHwush
    STA $00                     ; store in scratch $00-$01
    SEP #$20                    ; 8 bit A
    JMP Warp


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
    LDA $00                     ;\ 
    STA $19B8|!addr,x           ;| restore level from scratch into current screen exit
    LDA $01                     ;|
    STA $19D8|!addr,x           ;/
    
    LDA #$06                    ;\
    STA $71                     ;| do teleport
    STZ $88                     ;|
    STZ $89                     ;/

Return:
    RTL

