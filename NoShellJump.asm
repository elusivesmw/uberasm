;
; No Shell Jump
; by elusive
;


; Settings
!EXLEVEL            = 1         ; 1 = for LM versions > 2.57, 0 for older LM versions
!Mode               = 2         ; 0 = warp, 1 = hurt, 2+ = kill
!WarpLevelFlag1     = $20       ; level exit flags 1
!WarpLevelFlag2     = $04       ; level exit flags 2
!TimeTilDoMode      = $08      ; time in frames til warp, hurt, or kill ($79 frames or less, $00-$10 recommended)
!UseBlacklist       = 1         ; 0 = no, 1 = yes (recommended)

; FreeRAM addresses
!FreeRAM                        = $7FA210
!RAM_LastHeldSpriteIndex        = !FreeRAM
!RAM_HasBeenKicked              = !FreeRAM+1
!RAM_DelayTimer                 = !FreeRAM+2


; RAM addresses
!RAM_PlayerHolding              = $148F
!RAM_SpriteStatus               = !14C8
!RAM_SpriteNum                  = !9E
!RAM_SpriteYSpeed               = !AA
!RAM_SpriteBlocked              = !1588

!RAM_ExitTable1                 = !19B8
!RAM_ExitTable2                 = !19D8


; Blacklist sprites
BlacklistTable:
db $2D, $0D
; baby yoshi, bobomb
; behave strangely if you up throw this sprite and it lands on mario's head
; add more as needed



init: 
    JSR Reset

main: 

    ; timer is set, jump;
    if !TimeTilDoMode > 0
        LDA !RAM_DelayTimer             ;\ if delay timer has time left, dec
        BMI .start                      ;| else jump to .start code
        DEC                             ;|
        STA !RAM_DelayTimer             ;|
        BEQ .do_mode                    ;| if timer == 0, warp
        BRA .return                     ;| else timer running, .return
        .do_mode                        ;|
        JMP DoMode                      ;/
    endif


    .start
    LDA !RAM_LastHeldSpriteIndex
    TAX                                 ; restore last held sprite to X

    LDA !RAM_PlayerHolding
    BEQ .cont                           ; holding, jump to cont; not holding, next line

    LDA #$FF
    STA !RAM_HasBeenKicked              ; clear kicked

    JSR FindHeldItem                    ; find held item
    if !UseBlacklist == 1
        JSR Blacklist                   ; clear held item if blacklisted
    endif


    ; holding
    .cont
    LDA !RAM_LastHeldSpriteIndex
    CMP #$FF
    BEQ .return

    LDA !RAM_SpriteStatus,x
    CMP #$0A                            ; kicked
    BNE .stunned

    LDA #$00
    STA !RAM_HasBeenKicked              ; set kicked

    .stunned
    LDA !RAM_HasBeenKicked
    BNE .despawn
    
    LDA !RAM_SpriteStatus,x
    CMP #$09                            ; stunned
    BNE .despawn

    LDA !RAM_SpriteYSpeed,x             ; if not moving Y, don't kill
    SEC : SBC #$20
    BMI .return


    ; activate warp, hurt, or kill
    if !TimeTilDoMode > 0
        ; with delay
        LDA #!TimeTilDoMode
        STA !RAM_DelayTimer
    else
        ; without delay
        JMP DoMode
    endif

    .despawn
    LDA !RAM_SpriteStatus,x             ; did kicked sprite despawn?
    BNE .return
    JSR Reset

    .return
    RTL

; OUTPUT: X = index of held sprite
FindHeldItem:
    LDX #$0B
-   LDA !RAM_SpriteStatus,x
    BEQ +                               ; doesn't exist, skip
    CMP #$0B                            ; carried
    BNE +     
    TXA                                 ; isn't kicked, skip
    STA !RAM_LastHeldSpriteIndex        ; last held sprite index

    RTS
+   DEX : BPL -
    RTS

; INPUT:  X as current held item index
; OUTPUT: X = index of held sprite, if valid, else $FF
Blacklist:
    LDA !RAM_SpriteNum,x
    STA $0D                             ; held sprite num in scratch

    PHX
    LDX #$01                            ; BlacklistTable size - 1
-   LDA BlacklistTable,x                ; check current item 
    CMP $0D
    BNE +                               ; current blacklist sprite is not held sprite num, skip

    PLX                                 ; sprite is blacklisted, restore X
    LDX #$FF                            ; clear X
    TXA
    STA !RAM_LastHeldSpriteIndex        ; might as well clear held sprite index here
    RTS                                 ; return

+   DEX : BPL -
    PLX                                 ; valid X, don't clear
    RTS                                 ; return

Reset:
    LDA #$FF
    STA !RAM_LastHeldSpriteIndex 
    STA !RAM_HasBeenKicked
    if !TimeTilDoMode > 0
        STA !RAM_DelayTimer
    endif
    RTS

DoMode:
    JSR Reset
    if !Mode == 0
        ; warp to level
        JSR Warp
    elseif !Mode == 1
        ; hurt mario
        JSL $00F5B7|!bank
    else
        ; kill mario
        JSL $00F606|!bank
    endif
    RTL

Warp:
    if !EXLEVEL                         ;\ find current screen index, put in X
        JSL $03BCDC|!bank               ;|
    else                                ;|
        LDA $5B                         ;|
        AND #$01                        ;|
        ASL                             ;|
        TAX                             ;|
        LDA $95,x                       ;|
        TAX                             ;|
    endif                               ;/
    
    .WarpToLevel:
    LDA #!WarpLevelFlag1                ;\
    STA $19B8|!addr,x                   ;| teleporting
    LDA #!WarpLevelFlag2                ;|
    STA $19D8|!addr,x                   ;/
    
    LDA #$06                            ;\ teleport the player
    STA $71                             ;|
    STZ $88                             ;|
    STZ $89                             ;/
    RTS
