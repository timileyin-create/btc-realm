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