;; Credit Generation Contract
;; Handles creation and minting of carbon credits

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_INVALID_AMOUNT (err u201))
(define-constant ERR_CREDIT_NOT_FOUND (err u202))
(define-constant ERR_INSUFFICIENT_BALANCE (err u203))

;; Data Variables
(define-data-var next-credit-id uint u1)
(define-data-var total-credits-minted uint u0)

;; Data Maps
(define-map carbon-credits
  { credit-id: uint }
  {
    owner: principal,
    project-name: (string-ascii 100),
    amount: uint,
    creation-date: uint,
    expiry-date: uint,
    status: (string-ascii 20)
  }
)

(define-map user-balances
  { user: principal }
  { balance: uint }
)

;; Public Functions

;; Generate new carbon credits
(define-public (generate-credits
  (project-name (string-ascii 100))
  (amount uint)
  (expiry-date uint)
)
  (let
    (
      (credit-id (var-get next-credit-id))
      (current-block block-height)
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> expiry-date current-block) ERR_INVALID_AMOUNT)

    (map-set carbon-credits
      { credit-id: credit-id }
      {
        owner: tx-sender,
        project-name: project-name,
        amount: amount,
        creation-date: current-block,
        expiry-date: expiry-date,
        status: "active"
      }
    )

    ;; Update user balance
    (let
      (
        (current-balance (default-to u0 (get balance (map-get? user-balances { user: tx-sender }))))
      )
      (map-set user-balances
        { user: tx-sender }
        { balance: (+ current-balance amount) }
      )
    )

    (var-set next-credit-id (+ credit-id u1))
    (var-set total-credits-minted (+ (var-get total-credits-minted) amount))
    (ok credit-id)
  )
)

;; Transfer credits between users
(define-public (transfer-credits (credit-id uint) (recipient principal) (amount uint))
  (match (map-get? carbon-credits { credit-id: credit-id })
    credit-data
    (begin
      (asserts! (is-eq (get owner credit-data) tx-sender) ERR_UNAUTHORIZED)
      (asserts! (>= (get amount credit-data) amount) ERR_INSUFFICIENT_BALANCE)
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)

      ;; Update sender balance
      (let
        (
          (sender-balance (default-to u0 (get balance (map-get? user-balances { user: tx-sender }))))
        )
        (map-set user-balances
          { user: tx-sender }
          { balance: (- sender-balance amount) }
        )
      )

      ;; Update recipient balance
      (let
        (
          (recipient-balance (default-to u0 (get balance (map-get? user-balances { user: recipient }))))
        )
        (map-set user-balances
          { user: recipient }
          { balance: (+ recipient-balance amount) }
        )
      )

      ;; Update credit amount or transfer ownership
      (if (is-eq (get amount credit-data) amount)
        (map-set carbon-credits
          { credit-id: credit-id }
          (merge credit-data { owner: recipient })
        )
        (map-set carbon-credits
          { credit-id: credit-id }
          (merge credit-data { amount: (- (get amount credit-data) amount) })
        )
      )

      (ok true)
    )
    ERR_CREDIT_NOT_FOUND
  )
)

;; Retire credits (remove from circulation)
(define-public (retire-credits (credit-id uint) (amount uint))
  (match (map-get? carbon-credits { credit-id: credit-id })
    credit-data
    (begin
      (asserts! (is-eq (get owner credit-data) tx-sender) ERR_UNAUTHORIZED)
      (asserts! (>= (get amount credit-data) amount) ERR_INSUFFICIENT_BALANCE)
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)

      ;; Update user balance
      (let
        (
          (current-balance (default-to u0 (get balance (map-get? user-balances { user: tx-sender }))))
        )
        (map-set user-balances
          { user: tx-sender }
          { balance: (- current-balance amount) }
        )
      )

      ;; Update credit amount or mark as retired
      (if (is-eq (get amount credit-data) amount)
        (map-set carbon-credits
          { credit-id: credit-id }
          (merge credit-data { status: "retired" })
        )
        (map-set carbon-credits
          { credit-id: credit-id }
          (merge credit-data { amount: (- (get amount credit-data) amount) })
        )
      )

      (ok true)
    )
    ERR_CREDIT_NOT_FOUND
  )
)

;; Read-only Functions

;; Get credit information
(define-read-only (get-credit (credit-id uint))
  (map-get? carbon-credits { credit-id: credit-id })
)

;; Get user balance
(define-read-only (get-user-balance (user principal))
  (default-to u0 (get balance (map-get? user-balances { user: user })))
)

;; Get total credits minted
(define-read-only (get-total-credits-minted)
  (var-get total-credits-minted)
)

;; Get next credit ID
(define-read-only (get-next-credit-id)
  (var-get next-credit-id)
)
