;; Title: BTCRealm - Decentralized Adventure Protocol
;; Summary: Bitcoin-native gaming ecosystem on Stacks Layer 2 enabling 
;;          immersive realm exploration with time-locked challenges and 
;;          satoshi-backed reward distribution.
;;
;; Description: BTCRealm revolutionizes blockchain gaming by creating a 
;;              trustless adventure protocol where players traverse mystical 
;;              realms backed by Bitcoin's security. Features time-gated 
;;              exploration mechanics, automated reward systems, and 
;;              provably fair gameplay - all powered by Stacks L2.

;; TRAIT DEFINITIONS

(define-trait token-trait 
    (
        (get-balance (principal) (response uint uint))
        (transfer (principal principal uint) (response bool uint))
    )
)

;; ERROR CONSTANTS

(define-constant ERR-INSUFFICIENT-BALANCE (err u1))
(define-constant ERR-UNAUTHORIZED (err u2))
(define-constant ERR-INVALID-TOKEN (err u3))
(define-constant ERR-NOT-CONTRACT-OWNER (err u4))
(define-constant ERR-INVALID-PRINCIPAL (err u5))
(define-constant ERR-PENDING-OWNER-ONLY (err u6))
(define-constant ERR-DUNGEON-COOLDOWN (err u7))
(define-constant ERR-DUNGEON-NOT-ENTERED (err u8))
(define-constant ERR-ZERO-AMOUNT (err u9))

;; GAME CONFIGURATION CONSTANTS

(define-constant ENTRY-COST u100)
(define-constant REWARD-AMOUNT u200)
(define-constant DUNGEON-COOLDOWN-BLOCKS u100)
(define-constant MAX-DUNGEONS-PER-PLAYER u1000)

;; STATE VARIABLES

(define-data-var contract-owner principal tx-sender)
(define-data-var pending-owner (optional principal) none)
(define-data-var allowed-token principal 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.my-token)
(define-data-var game-active bool true)
(define-data-var total-dungeons-created uint u0)

;; Player tracking
(define-map player-dungeon-stats 
    { player: principal }
    {
        last-dungeon-block: uint,
        last-entry-block: uint,
        total-dungeons-completed: uint,
        total-rewards-earned: uint,
        is-in-dungeon: bool
    }
)

;; Global game statistics
(define-map game-stats
    { stat-type: (string-ascii 20) }
    { value: uint }
)

;; PRIVATE HELPER FUNCTIONS

(define-private (is-contract-owner)
    (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-valid-token (token <token-trait>))
    (is-eq (contract-of token) (var-get allowed-token))
)

(define-private (is-valid-principal (address principal))
    (and 
        (not (is-eq address (var-get contract-owner)))
        (not (is-eq address tx-sender))
        (not (is-eq address (as-contract tx-sender)))
    )
)

(define-private (get-current-block)
    stacks-block-height
)

(define-private (update-global-stats (stat-key (string-ascii 20)) (increment uint))
    (let
        (
            (current-value (default-to u0 
                (get value (map-get? game-stats { stat-type: stat-key }))
            ))
        )
        (map-set game-stats 
            { stat-type: stat-key }
            { value: (+ current-value increment) }
        )
    )
)

;; PUBLIC GAME FUNCTIONS

;; Enter the dungeon with comprehensive validation
(define-public (enter-dungeon (token <token-trait>) (player principal))
    (let 
        (
            (player-balance (unwrap! (contract-call? token get-balance player) ERR-INSUFFICIENT-BALANCE))
            (current-block (get-current-block))
            (player-stats (default-to 
                {
                    last-dungeon-block: u0,
                    last-entry-block: u0,
                    total-dungeons-completed: u0, 
                    total-rewards-earned: u0,
                    is-in-dungeon: false
                } 
                (map-get? player-dungeon-stats { player: player })
            ))
        )
        ;; Validation checks
        (asserts! (var-get game-active) ERR-UNAUTHORIZED)
        (asserts! (is-eq tx-sender player) ERR-UNAUTHORIZED)
        (asserts! (is-valid-token token) ERR-INVALID-TOKEN)
        (asserts! (>= player-balance ENTRY-COST) ERR-INSUFFICIENT-BALANCE)
        (asserts! (not (get is-in-dungeon player-stats)) ERR-UNAUTHORIZED)
        
        ;; Check cooldown period
        (asserts! 
            (>= current-block 
                (+ (get last-entry-block player-stats) DUNGEON-COOLDOWN-BLOCKS)
            ) 
            ERR-DUNGEON-COOLDOWN
        )

        ;; Update player stats - mark as entered dungeon
        (map-set player-dungeon-stats 
            { player: player }
            {
                last-dungeon-block: (get last-dungeon-block player-stats),
                last-entry-block: current-block,
                total-dungeons-completed: (get total-dungeons-completed player-stats),
                total-rewards-earned: (get total-rewards-earned player-stats),
                is-in-dungeon: true
            }
        )

        ;; Update global statistics
        (update-global-stats "total-entries" u1)
        
        (ok true)
    )
)

;; Complete dungeon challenge and claim reward
(define-public (complete-dungeon (token <token-trait>) (player principal))
    (let
        (
            (current-block (get-current-block))
            (player-stats (unwrap! 
                (map-get? player-dungeon-stats { player: player })
                ERR-DUNGEON-NOT-ENTERED
            ))
        )
        ;; Validation checks
        (asserts! (var-get game-active) ERR-UNAUTHORIZED)
        (asserts! (is-eq tx-sender player) ERR-UNAUTHORIZED)
        (asserts! (is-valid-token token) ERR-INVALID-TOKEN)
        (asserts! (get is-in-dungeon player-stats) ERR-DUNGEON-NOT-ENTERED)
        (asserts! (> REWARD-AMOUNT u0) ERR-ZERO-AMOUNT)

        ;; Transfer reward tokens to player
        (try! (as-contract 
            (contract-call? token transfer
                tx-sender
                player
                REWARD-AMOUNT)
        ))

        ;; Update player dungeon statistics
        (map-set player-dungeon-stats 
            { player: player }
            {
                last-dungeon-block: current-block,
                last-entry-block: (get last-entry-block player-stats),
                total-dungeons-completed: (+ (get total-dungeons-completed player-stats) u1),
                total-rewards-earned: (+ (get total-rewards-earned player-stats) REWARD-AMOUNT),
                is-in-dungeon: false
            }
        )

        ;; Update global statistics
        (update-global-stats "total-completions" u1)
        (update-global-stats "rewards-distributed" REWARD-AMOUNT)

        (ok true)
    )
)

;; READ-ONLY FUNCTIONS

;; Get comprehensive player statistics
(define-read-only (get-player-stats (player principal))
    (ok (default-to 
        {
            last-dungeon-block: u0,
            last-entry-block: u0,
            total-dungeons-completed: u0, 
            total-rewards-earned: u0,
            is-in-dungeon: false
        }
        (map-get? player-dungeon-stats { player: player })
    ))
)

;; Check if player can enter dungeon
(define-read-only (can-enter-dungeon (player principal))
    (let
        (
            (current-block (get-current-block))
            (player-stats (default-to 
                {
                    last-dungeon-block: u0,
                    last-entry-block: u0,
                    total-dungeons-completed: u0, 
                    total-rewards-earned: u0,
                    is-in-dungeon: false
                } 
                (map-get? player-dungeon-stats { player: player })
            ))
        )
        (ok (and
            (var-get game-active)
            (not (get is-in-dungeon player-stats))
            (>= current-block 
                (+ (get last-entry-block player-stats) DUNGEON-COOLDOWN-BLOCKS))
        ))
    )
)

;; Get global game statistics
(define-read-only (get-game-stats (stat-type (string-ascii 20)))
    (ok (default-to u0 
        (get value (map-get? game-stats { stat-type: stat-type }))
    ))
)

;; Get contract configuration
(define-read-only (get-game-config)
    (ok {
        entry-cost: ENTRY-COST,
        reward-amount: REWARD-AMOUNT,
        cooldown-blocks: DUNGEON-COOLDOWN-BLOCKS,
        allowed-token: (var-get allowed-token),
        game-active: (var-get game-active),
        contract-owner: (var-get contract-owner)
    })
)

;; ADMINISTRATIVE FUNCTIONS

;; Toggle game active state
(define-public (toggle-game-state)
    (begin
        (asserts! (is-contract-owner) ERR-NOT-CONTRACT-OWNER)
        (var-set game-active (not (var-get game-active)))
        (ok (var-get game-active))
    )
)

;; Update the allowed token for the dungeon
(define-public (set-allowed-token (new-token principal))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-CONTRACT-OWNER)
        (asserts! (not (is-eq new-token (var-get allowed-token))) ERR-INVALID-PRINCIPAL)
        (var-set allowed-token new-token)
        (ok true)
    )
)

;; Emergency function to reset player dungeon state
(define-public (emergency-reset-player (player principal))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-CONTRACT-OWNER)
        (asserts! (not (is-eq player (var-get contract-owner))) ERR-INVALID-PRINCIPAL)
        (asserts! (not (is-eq player (as-contract tx-sender))) ERR-INVALID-PRINCIPAL)
        (map-delete player-dungeon-stats { player: player })
        (ok true)
    )
)

;; OWNERSHIP MANAGEMENT

;; Initiate secure two-step ownership transfer
(define-public (initiate-ownership-transfer (new-owner principal))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-CONTRACT-OWNER)
        (asserts! (is-valid-principal new-owner) ERR-INVALID-PRINCIPAL)
        (var-set pending-owner (some new-owner))
        (ok true)
    )
)

;; Accept pending ownership transfer
(define-public (accept-ownership)
    (let 
        ((pending (unwrap! (var-get pending-owner) ERR-PENDING-OWNER-ONLY)))
        (asserts! (is-eq tx-sender pending) ERR-UNAUTHORIZED)
        (var-set contract-owner pending)
        (var-set pending-owner none)
        (ok true)
    )
)

;; Cancel pending ownership transfer
(define-public (cancel-ownership-transfer)
    (begin
        (asserts! (is-contract-owner) ERR-NOT-CONTRACT-OWNER)
        (var-set pending-owner none)
        (ok true)
    )
)

;; Get current and pending owner information
(define-read-only (get-ownership-info)
    (ok {
        current-owner: (var-get contract-owner),
        pending-owner: (var-get pending-owner)
    })
)