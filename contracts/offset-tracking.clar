;; Offset Tracking Contract
;; Tracks carbon offset activities and environmental impact

;; Constants
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_INVALID_AMOUNT (err u501))
(define-constant ERR_OFFSET_NOT_FOUND (err u502))
(define-constant ERR_PROJECT_NOT_FOUND (err u503))

;; Data Variables
(define-data-var next-project-id uint u1)
(define-data-var next-offset-id uint u1)
(define-data-var total-offsets-tracked uint u0)

;; Data Maps
(define-map offset-projects
  { project-id: uint }
  {
    owner: principal,
    name: (string-ascii 100),
    location: (string-ascii 100),
    project-type: (string-ascii 50),
    start-date: uint,
    end-date: uint,
    total-capacity: uint,
    status: (string-ascii 20)
  }
)

(define-map carbon-offsets
  { offset-id: uint }
  {
    project-id: uint,
    credit-id: uint,
    amount: uint,
    offset-date: uint,
    verification-status: (string-ascii 20),
    environmental-impact: (string-ascii 500)
  }
)

(define-map project-offsets
  { project-id: uint }
  { total-offsets: uint }
)

;; Public Functions

;; Register a new offset project
(define-public (register-project
  (name (string-ascii 100))
  (location (string-ascii 100))
  (project-type (string-ascii 50))
  (start-date uint)
  (end-date uint)
  (total-capacity uint)
)
  (let
    (
      (project-id (var-get next-project-id))
      (current-block block-height)
    )
    (asserts! (> total-capacity u0) ERR_INVALID_AMOUNT)
    (asserts! (> end-date start-date) ERR_INVALID_AMOUNT)

    (map-set offset-projects
      { project-id: project-id }
      {
        owner: tx-sender,
        name: name,
        location: location,
        project-type: project-type,
        start-date: start-date,
        end-date: end-date,
        total-capacity: total-capacity,
        status: "active"
      }
    )

    (map-set project-offsets
      { project-id: project-id }
      { total-offsets: u0 }
    )

    (var-set next-project-id (+ project-id u1))
    (ok project-id)
  )
)

;; Record a carbon offset
(define-public (record-offset
  (project-id uint)
  (credit-id uint)
  (amount uint)
  (environmental-impact (string-ascii 500))
)
  (let
    (
      (offset-id (var-get next-offset-id))
      (current-block block-height)
    )
    (match (map-get? offset-projects { project-id: project-id })
      project-data
      (begin
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (is-eq (get status project-data) "active") ERR_PROJECT_NOT_FOUND)

        (map-set carbon-offsets
          { offset-id: offset-id }
          {
            project-id: project-id,
            credit-id: credit-id,
            amount: amount,
            offset-date: current-block,
            verification-status: "pending",
            environmental-impact: environmental-impact
          }
        )

        ;; Update project total offsets
        (let
          (
            (current-offsets (default-to u0 (get total-offsets (map-get? project-offsets { project-id: project-id }))))
          )
          (map-set project-offsets
            { project-id: project-id }
            { total-offsets: (+ current-offsets amount) }
          )
        )

        (var-set next-offset-id (+ offset-id u1))
        (var-set total-offsets-tracked (+ (var-get total-offsets-tracked) amount))
        (ok offset-id)
      )
      ERR_PROJECT_NOT_FOUND
    )
  )
)

;; Verify an offset (only project owner)
(define-public (verify-offset (offset-id uint))
  (match (map-get? carbon-offsets { offset-id: offset-id })
    offset-data
    (match (map-get? offset-projects { project-id: (get project-id offset-data) })
      project-data
      (begin
        (asserts! (is-eq (get owner project-data) tx-sender) ERR_UNAUTHORIZED)

        (map-set carbon-offsets
          { offset-id: offset-id }
          (merge offset-data { verification-status: "verified" })
        )

        (ok true)
      )
      ERR_PROJECT_NOT_FOUND
    )
    ERR_OFFSET_NOT_FOUND
  )
)

;; Update project status (only project owner)
(define-public (update-project-status (project-id uint) (status (string-ascii 20)))
  (match (map-get? offset-projects { project-id: project-id })
    project-data
    (begin
      (asserts! (is-eq (get owner project-data) tx-sender) ERR_UNAUTHORIZED)

      (map-set offset-projects
        { project-id: project-id }
        (merge project-data { status: status })
      )

      (ok true)
    )
    ERR_PROJECT_NOT_FOUND
  )
)

;; Read-only Functions

;; Get project information
(define-read-only (get-project (project-id uint))
  (map-get? offset-projects { project-id: project-id })
)

;; Get offset information
(define-read-only (get-offset (offset-id uint))
  (map-get? carbon-offsets { offset-id: offset-id })
)

;; Get project total offsets
(define-read-only (get-project-offsets (project-id uint))
  (default-to u0 (get total-offsets (map-get? project-offsets { project-id: project-id })))
)

;; Get total offsets tracked
(define-read-only (get-total-offsets-tracked)
  (var-get total-offsets-tracked)
)

;; Get next project ID
(define-read-only (get-next-project-id)
  (var-get next-project-id)
)

;; Get next offset ID
(define-read-only (get-next-offset-id)
  (var-get next-offset-id)
)
